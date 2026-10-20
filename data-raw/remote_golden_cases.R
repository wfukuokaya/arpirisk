# Golden cases for arpirisk, generated with rms on the remote analysis PC.
#
# Run this in the same R session immediately after the analysis script (for
# example 261002_script.R) finishes, so that fit_pooled, model_export, mv_fits,
# knots_pooled, data_model, base_completed, patient_risk,
# calculate_absolute_mortality_risk(), and reconstruct_curve() are available. It scores fixed synthetic profiles defined
# below, so it uses no participant-level data, and it runs in seconds.
#
# The expected values come from rms::predict() on the fitted model and from the
# exact pooled spline curves, independently of the package code. Copy the
# output file, together with the model_export.txt from the same run, to the
# package: golden_cases.csv goes to tests/testthat/fixtures/.

golden_seed <- 20261004L
golden_n <- 40L

set.seed(golden_seed)
golden_inputs <- data.frame(
  ecog_ps = sample(c(0, 1, 2), golden_n, replace = TRUE),
  gleason_score = sample(c(7, 8, 9, 10), golden_n, replace = TRUE),
  visceral_metastasis = sample(c(0, 1), golden_n, replace = TRUE),
  bone_metastases = sample(c(0, 2, 5, 8, 15, 30), golden_n, replace = TRUE),
  psa = sample(c(0.5, 4, 25, 120, 900, 5000, 12000), golden_n, replace = TRUE),
  hemoglobin = sample(c(95, 115, 128, 140, 152), golden_n, replace = TRUE),
  albumin = sample(c(32, 37, 41, 44, 47), golden_n, replace = TRUE),
  alp = sample(c(60, 95, 180, 450, 1500, 6000), golden_n, replace = TRUE),
  ldh = sample(c(150, 185, 220, 300, 600, 2000), golden_n, replace = TRUE)
)

# Model-scale data, encoded exactly as in the analysis script.
schema <- model_export$predictor_schema
cap <- function(source_name, values) {
  limit <- schema$winsor_upper[schema$source_name == source_name]
  if (length(limit) == 1L && is.finite(limit)) pmin(values, limit) else values
}
bone_levels <- fit_pooled$Design$parms$NUM_BONE_CAT
model_scale <- data.frame(
  ARM = 0L,
  PSA = cap("PSA", golden_inputs$psa),
  HGB = cap("HGB", golden_inputs$hemoglobin),
  ALB = cap("ALB", golden_inputs$albumin),
  ALP = cap("ALP", golden_inputs$alp),
  LDH = cap("LDH", golden_inputs$ldh),
  NUM_BONE_CAT = factor(
    as.character(cut(
      golden_inputs$bone_metastases,
      breaks = c(-Inf, model_export$bone_cuts, Inf),
      labels = model_export$bone_labels
    )),
    levels = bone_levels
  ),
  ECOG = as.integer(golden_inputs$ecog_ps >= 1),
  GS = as.integer(golden_inputs$gleason_score >= 9),
  VIS = as.integer(golden_inputs$visceral_metastasis)
)
# The stratum does not change the linear predictor, but rms requires it.
model_scale$TRIAL <- data_model$TRIAL[rep(1L, golden_n)]
if (anyNA(model_scale$NUM_BONE_CAT)) {
  stop("Bone metastasis categories did not match the fitted factor levels.")
}

# predict(type = "lp") is centered at fit_pooled$center; it is re-centered at
# the exported lp_center, and the shrinkage factor is applied as in the export.
exported_lp <- function(newdata) {
  model_export$shrinkage_factor * (
    as.numeric(predict(fit_pooled, newdata = newdata, type = "lp")) +
      as.numeric(fit_pooled$center) - model_export$lp_center
  )
}
linear_predictor <- exported_lp(model_scale)

# The baseline hazards and the effect curves were estimated on the shrunken
# linear predictor of survival::coxph(), which uses 0 rather than the mean as the
# reference for 0/1 and factor columns. The exported linear predictor must be on
# that scale; a mean difference above 0.01 means the exported center is wrong.
alignment <- purrr::map_dbl(utils::head(sort(unique(patient_risk$imp)), 5L), function(m) {
  dat_arm0 <- base_completed[[m]]
  dat_arm0$ARM <- 0L
  mean(exported_lp(dat_arm0) - patient_risk$lp_shrunk[patient_risk$imp == m])
})
writeLines(sprintf(
  "Mean difference between the exported and the analysis linear predictor: %.4f.",
  mean(alignment)
))
if (abs(mean(alignment)) > 0.01) {
  stop("The exported lp_center is not aligned with the baseline hazards and effect curves.")
}
baseline_risk <- calculate_absolute_mortality_risk(
  lp = linear_predictor,
  baseline_hazards = model_export$baseline_hazards
)

# Exact pooled curves at each profile's linear predictor, bounded to the range
# in which effects were estimated.
lp_range <- model_export$lp_grid_range
bounded_lp <- pmin(pmax(linear_predictor, lp_range[[1L]]), lp_range[[2L]])
exact_effect <- function(scale) {
  curve <- reconstruct_curve(mv_fits[[scale]], bounded_lp, knots_pooled)
  if (scale == "cox") exp(curve$est) else curve$est
}

golden_cases <- cbind(
  model_version = model_export$model_version,
  golden_inputs,
  linear_predictor = linear_predictor,
  baseline_risk = baseline_risk,
  ard_estimate = exact_effect("ard"),
  rmst_estimate = exact_effect("rmst"),
  hr_estimate = exact_effect("cox")
)
utils::write.csv(golden_cases, "golden_cases.csv", row.names = FALSE)
writeLines(sprintf(
  "Wrote golden_cases.csv: %d profiles for model %s.",
  nrow(golden_cases), model_export$model_version
))
