#' Predict baseline risk of death
#'
#' Calculates each patient's predicted risk of death within 4 years with
#' placebo plus androgen deprivation therapy (ADT). Treatment-effect estimates
#' are indexed on this baseline risk.
#'
#' The linear predictor is the shrunken, centered Cox linear predictor for
#' placebo plus ADT.
#'
#' @inheritParams check_inputs
#'
#' @return A data frame with one row per patient in `newdata`:
#'   \describe{
#'     \item{row}{Row number in `newdata`.}
#'     \item{linear_predictor}{Linear predictor for placebo plus ADT.}
#'     \item{baseline_risk}{Predicted 4-year risk of death, as a proportion.}
#'     \item{in_effect_range}{Whether the baseline risk lies within the range in
#'       which treatment effects were estimated.}
#'     \item{notes}{Warnings and notes about the inputs, or `NA`.}
#'   }
#' @examples
#' patient <- data.frame(
#'   ecog_ps = 0, gleason_score = 9, visceral_metastasis = 0,
#'   bone_metastases = 8, psa = 45, hemoglobin = 128, albumin = 41,
#'   alp = 180, ldh = 210
#' )
#' predict_baseline_risk(patient)
#' @export
predict_baseline_risk <- function(newdata, model = mhspc_model()) {
  check_model(model)
  assessment <- prepare_inputs(newdata, model)
  lp <- linear_predictor(assessment$values, model)
  data.frame(
    row = seq_along(lp),
    linear_predictor = lp,
    baseline_risk = absolute_risk(lp, model),
    in_effect_range = in_effect_range(lp, model),
    notes = combine_notes(row_notes(assessment$issues, length(lp)), lp, model)
  )
}

#' Estimate treatment effects at a patient's baseline risk
#'
#' Returns the pooled treatment effects of an androgen receptor pathway
#' inhibitor (ARPI) plus ADT versus placebo plus ADT at each patient's baseline
#' risk. The effects were estimated within each of 4 randomized clinical trials
#' as smooth functions of baseline risk and pooled with multivariate
#' random-effects meta-analysis.
#'
#' Positive absolute effects indicate gains with an ARPI. For baseline risks
#' outside the range in which effects were estimated, the effect at the nearest
#' edge of that range is returned and `in_effect_range` is `FALSE`.
#'
#' @inheritParams check_inputs
#' @param scale Effects to return: `"ard"`, the difference in the probability
#'   of being alive at 4 years; `"rmst"`, the difference in restricted mean
#'   survival time through 4 years, in months; `"hr"`, the hazard ratio for
#'   death.
#'
#' @return A data frame with one row per patient and scale: `row`,
#'   `baseline_risk`, `scale`, `estimate`, the 95% confidence interval
#'   (`conf_low`, `conf_high`), `pred_low`, `pred_high`, `in_effect_range`,
#'   and `notes`.
#' @examples
#' patient <- data.frame(
#'   ecog_ps = 0, gleason_score = 9, visceral_metastasis = 0,
#'   bone_metastases = 8, psa = 45, hemoglobin = 128, albumin = 41,
#'   alp = 180, ldh = 210
#' )
#' estimate_treatment_effect(patient)
#' @export
estimate_treatment_effect <- function(newdata,
                                      scale = c("ard", "rmst", "hr"),
                                      model = mhspc_model()) {
  check_model(model)
  scale <- match.arg(scale, several.ok = TRUE)
  risk <- predict_baseline_risk(newdata, model)
  effects <- purrr::map(scale, function(effect_scale) {
    data.frame(
      row = risk$row,
      baseline_risk = risk$baseline_risk,
      scale = effect_scale,
      effect_at_lp(risk$linear_predictor, model, effect_scale),
      in_effect_range = risk$in_effect_range,
      notes = risk$notes
    )
  }) |>
    purrr::list_rbind()
  effects <- effects[order(effects$row, match(effects$scale, scale)), , drop = FALSE]
  rownames(effects) <- NULL
  effects
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

combine_notes <- function(notes, lp, model) {
  outside <- !in_effect_range(lp, model)
  range_note <- paste0(
    "Baseline risk is outside the range in which treatment effects were estimated (",
    paste(format_percent(effect_risk_range(model), 0), collapse = " to "),
    "); effects are shown at the nearest edge of that range."
  )
  notes[outside] <- ifelse(
    is.na(notes[outside]),
    range_note,
    paste(notes[outside], range_note)
  )
  notes
}

effect_risk_range <- function(model) {
  absolute_risk(model$treatment_effects$lp_range, model)
}
