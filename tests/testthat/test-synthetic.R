# Fixtures from data-raw/synthetic_cohort_check.R: a specification built from a
# synthetic cohort with the analysis code, and patients scored with rms. All
# values are simulated.
synthetic_path <- function(file) test_path("fixtures", "synthetic", file)
synthetic_model <- function() mhspc_model(synthetic_path("model_spec.json"))

test_that("the synthetic specification reproduces rms golden cases", {
  model <- synthetic_model()
  golden <- utils::read.csv(synthetic_path("golden_cases.csv"))
  inputs <- golden[model_inputs(model)$name]

  risk <- suppressWarnings(predict_baseline_risk(inputs, model))
  expect_equal(risk$linear_predictor, golden$linear_predictor, tolerance = 1e-8)
  expect_equal(risk$baseline_risk, golden$baseline_risk, tolerance = 1e-8)

  # The package interpolates the exported 100-point curves; the golden cases use
  # the exact pooled splines.
  effects <- suppressWarnings(estimate_treatment_effect(inputs, model = model))
  purrr::walk(c("ard", "rmst", "hr"), function(scale) {
    estimate <- effects$estimate[effects$scale == scale]
    expect_lt(max(abs(estimate - golden[[paste0(scale, "_estimate")]])), 1e-3)
  })
})

test_that("the synthetic specification reproduces rms for simulated patients", {
  model <- synthetic_model()
  cohort <- utils::read.csv(synthetic_path("cohort_cases.csv"))
  risk <- suppressWarnings(predict_baseline_risk(cohort[model_inputs(model)$name], model))
  expect_equal(risk$linear_predictor, cohort$linear_predictor, tolerance = 1e-8)
  expect_equal(risk$baseline_risk, cohort$baseline_risk, tolerance = 1e-8)
})

test_that("synthetic predictions are calibrated to the data-generating model", {
  model <- synthetic_model()
  cohort <- utils::read.csv(synthetic_path("cohort_cases.csv"))
  risk <- suppressWarnings(predict_baseline_risk(cohort[model_inputs(model)$name], model))
  expect_gt(stats::cor(risk$baseline_risk, cohort$true_risk), 0.9)
  expect_lt(abs(mean(risk$baseline_risk - cohort$true_risk)), 0.03)
})

test_that("the synthetic reference profiles scored by the analysis code are reproduced", {
  model <- synthetic_model()
  reference <- model$verification$reference_profiles
  inputs <- as.data.frame(reference$inputs[names(reference$inputs) != "profile"])
  risk <- suppressWarnings(predict_baseline_risk(inputs, model))
  expect_equal(risk$linear_predictor, reference$expected$linear_predictor, tolerance = 1e-8)
  expect_equal(risk$baseline_risk, reference$expected$baseline_risk, tolerance = 1e-8)
})
