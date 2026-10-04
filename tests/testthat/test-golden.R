# Golden cases are produced with rms on the remote analysis PC by
# data-raw/remote_golden_cases.R and compared only with the specification from
# the same analysis run.
test_that("predictions match rms golden cases from the analysis run", {
  path <- test_path("fixtures", "golden_cases.csv")
  skip_if_not(file.exists(path), "Golden cases from the remote analysis are not available yet.")
  golden <- utils::read.csv(path)
  model <- mhspc_model()
  skip_if_not(
    identical(unique(golden$model_version), model$meta$model_version),
    "Golden cases come from a different model version."
  )

  inputs <- golden[c(
    "ecog_ps", "gleason_score", "visceral_metastasis", "bone_metastases",
    "psa", "hemoglobin", "albumin", "alp", "ldh"
  )]
  risk <- suppressWarnings(predict_baseline_risk(inputs, model))
  expect_equal(risk$linear_predictor, golden$linear_predictor, tolerance = 1e-8)
  expect_equal(risk$baseline_risk, golden$baseline_risk, tolerance = 1e-8)

  effects <- suppressWarnings(estimate_treatment_effect(inputs, model = model))
  purrr::walk(c("ard", "rmst", "hr"), function(scale) {
    estimate <- effects$estimate[effects$scale == scale]
    expect_equal(estimate, golden[[paste0(scale, "_estimate")]], tolerance = 1e-3, label = scale)
  })
})
