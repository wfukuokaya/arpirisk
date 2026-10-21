#' Predict baseline risk of death
#'
#' Adds each patient's linear predictor and predicted risk of death within 4
#' years with androgen deprivation therapy (ADT) alone, called baseline risk.
#'
#' Inputs are checked first. Missing or invalid values stop with an error that
#' names the row and input. Values outside the range in the trial data give a
#' warning, because their estimates are extrapolations. Values above the upper
#' cap used in model development are scored at the cap, with a message.
#'
#' @param newdata A data frame with one row per patient and one column per
#'   input listed by [model_inputs()]: `ecog_ps` (0, 1, or 2),
#'   `gleason_score` (2 to 10), `visceral_metastasis` (0 or 1, or logical),
#'   `bone_metastases` (a count, or a category code `"0-3"`, `"4-6"`,
#'   `"7-10"`, or `"11+"`), `psa` (ng/mL), `hemoglobin` (g/L), `albumin`
#'   (g/L), `alp` (U/L), and `ldh` (U/L). Other columns are kept unchanged.
#' @inheritParams model_inputs
#'
#' @return `newdata` with two columns added: `linear_predictor`, the model's
#'   risk score, and `baseline_risk`, the predicted 4-year risk of death as a
#'   proportion. Existing columns with these names are replaced.
#' @examples
#' # Your own patient data: one row per patient, one column per input, plus any
#' # other columns, which are kept.
#' patients <- data.frame(
#'   patient_id = c("A", "B"),
#'   ecog_ps = c(0, 1), gleason_score = c(9, 9), visceral_metastasis = c(0, 0),
#'   bone_metastases = c(8, 15), psa = c(45, 150), hemoglobin = c(128, 115),
#'   albumin = c(41, 38), alp = c(180, 420), ldh = c(210, 280)
#' )
#' risk <- predict_baseline_risk(patients)
#' risk[c("patient_id", "baseline_risk")]
#' @export
predict_baseline_risk <- function(newdata, model = mhspc_model()) {
  check_model(model)
  assessment <- prepare_inputs(newdata, model)
  lp <- linear_predictor(assessment$values, model)
  newdata$linear_predictor <- lp
  newdata$baseline_risk <- absolute_risk(lp, model)
  newdata
}

#' Estimate treatment effects at a patient's baseline risk
#'
#' Adds each patient's baseline risk and the treatment effects of adding an
#' androgen receptor pathway inhibitor (ARPI) to androgen deprivation therapy
#' (ADT) at that risk.
#'
#' Positive absolute effects indicate gains with an ARPI. For baseline risks
#' outside the range in which effects were estimated, the effect at the nearest
#' edge of that range is returned, with a warning. Inputs are checked as in
#' [predict_baseline_risk()].
#'
#' @inheritParams predict_baseline_risk
#' @param scale Effects to add: `"ard"`, the difference in the probability of
#'   being alive at 4 years; `"rmst"`, the difference in restricted mean
#'   survival time through 4 years, in months; `"hr"`, the hazard ratio for
#'   death.
#'
#' @return `newdata` with `baseline_risk` and, for each scale, the estimate
#'   in a column named after the scale (for example, `ard`) and its 95%
#'   confidence interval (`ard_conf_low`, `ard_conf_high`). Existing columns
#'   with these names are replaced.
#' @examples
#' patients <- example_patients[1:5, ]
#'
#' # Difference in the proportion alive at 4 years with an ARPI: 0.16 means 16
#' # more patients alive per 100 treated
#' effects <- estimate_treatment_effect(patients, scale = "ard")
#' effects[c("patient_id", "baseline_risk", "ard", "ard_conf_low", "ard_conf_high")]
#'
#' # Additional months alive over 4 years, and the hazard ratio for death
#' effects <- estimate_treatment_effect(patients, scale = c("rmst", "hr"))
#' effects[c("patient_id", "rmst", "hr", "hr_conf_low", "hr_conf_high")]
#' @export
estimate_treatment_effect <- function(newdata,
                                      scale = c("ard", "rmst", "hr"),
                                      model = mhspc_model()) {
  check_model(model)
  scale <- unique(match.arg(scale, several.ok = TRUE))
  assessment <- prepare_inputs(newdata, model)
  lp <- linear_predictor(assessment$values, model)
  warn_outside_effect_range(lp, model)
  newdata$baseline_risk <- absolute_risk(lp, model)
  purrr::reduce(scale, function(data, effect_scale) {
    effects <- effect_at_lp(lp, model, effect_scale)
    data[[effect_scale]] <- effects$estimate
    data[[paste0(effect_scale, "_conf_low")]] <- effects$conf_low
    data[[paste0(effect_scale, "_conf_high")]] <- effects$conf_high
    data
  }, .init = newdata)
}

linear_predictor <- function(values, model, arm = 0) {
  contributions <- purrr::map(model$predictors, function(predictor) {
    predictor_contribution(values[[predictor$name]], predictor)
  })
  raw <- purrr::reduce(contributions, `+`) + model$linear_predictor$arm_coefficient * arm
  model$linear_predictor$shrinkage_factor * (raw - model$linear_predictor$center)
}

predictor_contribution <- function(values, predictor) {
  switch(
    predictor$type,
    rcs = as.numeric(rcs_basis(values, predictor$knots) %*% predictor$coefficients),
    linear = values * predictor$coefficients,
    categorical = purrr::map_dbl(predictor$levels, "coefficient")[values],
    threshold = ,
    binary = values * predictor$coefficient
  )
}

# Risk of death by the horizon, averaged over the imputation-specific baseline
# cumulative hazards.
absolute_risk <- function(lp, model) {
  cumulative_hazard <- outer(exp(lp), model$baseline_cumulative_hazard)
  rowMeans(-expm1(-cumulative_hazard))
}

in_effect_range <- function(lp, model) {
  range <- model$treatment_effects$lp_range
  tolerance <- sqrt(.Machine$double.eps)
  lp >= range[[1L]] - tolerance & lp <= range[[2L]] + tolerance
}

effect_at_lp <- function(lp, model, scale) {
  curve <- model$treatment_effects$curves[[if (scale == "hr") "log_hr" else scale]]
  range <- model$treatment_effects$lp_range
  bounded_lp <- pmin(pmax(lp, range[[1L]]), range[[2L]])
  columns <- c("estimate", "conf_low", "conf_high", "pred_low", "pred_high")
  values <- purrr::map(rlang::set_names(columns), function(column) {
    stats::approx(curve$lp, curve[[column]], xout = bounded_lp, ties = "ordered")$y
  })
  if (scale == "hr") {
    values <- purrr::map(values, exp)
  }
  as.data.frame(values)
}

warn_outside_effect_range <- function(lp, model) {
  outside <- which(!in_effect_range(lp, model))
  if (length(outside) == 0L) {
    return(invisible())
  }
  # nolint start: object_usage_linter. Used in the cli strings below.
  n_outside <- length(outside)
  risk_range <- paste(format_percent(effect_risk_range(model), 0), collapse = " to ")
  rows <- paste(outside, collapse = ", ")
  # nolint end
  cli::cli_warn(
    c(
      paste(
        "{n_outside} patient{?s} {?has/have} a baseline risk outside the range in which",
        "treatment effects were estimated ({risk_range})."
      ),
      i = "Their effects are taken at the nearest edge of that range.",
      i = "{cli::qty(n_outside)}Row{?s}: {rows}."
    ),
    class = "arpirisk_effect_range_warning"
  )
}

effect_risk_range <- function(model) {
  absolute_risk(model$treatment_effects$lp_range, model)
}
