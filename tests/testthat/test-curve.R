test_that("treatment_effect_curve returns the pooled curves on the analysis grid", {
  model <- mhspc_model()
  grid <- model$treatment_effects$curves$ard$lp
  curve <- treatment_effect_curve()
  expect_named(
    curve,
    c(
      "linear_predictor", "baseline_risk", "scale", "estimate", "conf_low", "conf_high",
      "pred_low", "pred_high"
    )
  )
  expect_equal(nrow(curve), 3L * length(grid))
  expect_equal(unique(curve$scale), c("ard", "rmst", "hr"))
  expect_true(all(diff(curve$baseline_risk[curve$scale == "ard"]) > 0))
  expect_equal(range(curve$baseline_risk), effect_risk_range(model))

  ard <- treatment_effect_curve("ard", model)
  expect_equal(ard$estimate, model$treatment_effects$curves$ard$estimate)
  hr <- treatment_effect_curve("hr", model)
  expect_equal(hr$estimate, exp(model$treatment_effects$curves$log_hr$estimate))
  expect_error(treatment_effect_curve("or"), "should be one of")
})

test_that("the curve agrees with patient-level estimates at a grid point", {
  model <- mhspc_model()
  curve <- treatment_effect_curve("rmst", model)
  patient <- estimate_treatment_effect(example_patient(), scale = "rmst", model = model)
  nearest <- which.min(abs(curve$baseline_risk - patient$baseline_risk))
  expect_equal(curve$estimate[[nearest]], patient$estimate, tolerance = 0.05)
})
