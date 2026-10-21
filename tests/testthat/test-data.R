test_that("example_patients are valid inputs that span the risk range", {
  expect_equal(nrow(example_patients), 6L)
  expect_named(example_patients, c("patient_id", model_inputs()$name))
  expect_no_warning(expect_no_message(risk <- predict_baseline_risk(example_patients)))
  expect_lt(min(risk$baseline_risk), 0.2)
  expect_gt(max(risk$baseline_risk), 0.9)
  expect_warning(estimate_treatment_effect(example_patients, scale = "ard"), class = "arpirisk_effect_range_warning")
})
