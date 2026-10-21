test_that("reference profiles scored by the analysis code are reproduced", {
  model <- mhspc_model()
  reference <- model$verification$reference_profiles
  inputs <- as.data.frame(reference$inputs[names(reference$inputs) != "profile"])
  expected <- reference$expected

  risk <- quietly(predict_baseline_risk(inputs))
  expect_equal(risk$linear_predictor, expected$linear_predictor, tolerance = 1e-8)
  expect_equal(risk$baseline_risk, expected$baseline_risk, tolerance = 1e-8)

  effects <- quietly(estimate_treatment_effect(inputs))
  expect_equal(effects$ard, expected$ard, tolerance = 1e-8)
  expect_equal(effects$rmst, expected$rmst, tolerance = 1e-8)
  expect_equal(effects$hr, expected$hr, tolerance = 1e-8)
})

test_that("baseline risk is a proportion that increases with the linear predictor", {
  model <- mhspc_model()
  lp <- seq(-3, 3, by = 0.25)
  risk <- absolute_risk(lp, model)
  expect_true(all(risk > 0 & risk < 1))
  expect_true(all(diff(risk) > 0))
})

test_that("predict_baseline_risk adds its results to the patient data", {
  patients <- rbind(example_patient(), low_risk_patient(), example_patient(ecog_ps = 1))
  patients$patient_id <- c("a", "b", "c")
  risk <- predict_baseline_risk(patients)
  expect_named(risk, c(names(patients), "linear_predictor", "baseline_risk"))
  expect_equal(risk[names(patients)], patients)
  single <- predict_baseline_risk(low_risk_patient())
  expect_equal(risk$linear_predictor[[2L]], single$linear_predictor)
  expect_equal(risk$baseline_risk[[2L]], single$baseline_risk)
  expect_gt(risk$baseline_risk[[3L]], risk$baseline_risk[[1L]])
})

test_that("effects are exact at grid points and linearly interpolated between them", {
  model <- mhspc_model()
  curve <- model$treatment_effects$curves$ard
  at_grid <- effect_at_lp(curve$lp, model, "ard")
  expect_equal(at_grid$estimate, curve$estimate)
  expect_equal(at_grid$pred_high, curve$pred_high)
  midpoint <- mean(curve$lp[1:2])
  expect_equal(effect_at_lp(midpoint, model, "ard")$estimate, mean(curve$estimate[1:2]))
  expect_equal(
    effect_at_lp(curve$lp[[10L]], model, "hr")$estimate,
    exp(model$treatment_effects$curves$log_hr$estimate[[10L]])
  )
})

test_that("baseline risks outside the effect range use the nearest edge and are flagged", {
  model <- mhspc_model()
  range <- model$treatment_effects$lp_range
  expect_equal(effect_at_lp(range[[1L]] - 1, model, "rmst"), effect_at_lp(range[[1L]], model, "rmst"))
  expect_equal(effect_at_lp(range[[2L]] + 1, model, "rmst"), effect_at_lp(range[[2L]], model, "rmst"))

  expect_warning(
    effects <- estimate_treatment_effect(low_risk_patient(), scale = "ard"),
    "outside the range in which treatment effects were estimated",
    class = "arpirisk_effect_range_warning"
  )
  expect_equal(effects$ard, model$treatment_effects$curves$ard$estimate[[1L]])
  expect_no_warning(predict_baseline_risk(low_risk_patient()))
})

test_that("estimate_treatment_effect adds the requested scales in order", {
  patients <- rbind(example_patient(), example_patient(ecog_ps = 1))
  effects <- estimate_treatment_effect(patients, scale = c("hr", "ard"))
  expect_named(
    effects,
    c(names(patients), "baseline_risk", "hr", "hr_conf_low", "hr_conf_high", "ard", "ard_conf_low", "ard_conf_high")
  )
  expect_equal(effects$baseline_risk, predict_baseline_risk(patients)$baseline_risk)
  expect_true(all(effects$ard_conf_low <= effects$ard & effects$ard <= effects$ard_conf_high))
  expect_true(all(effects$hr_conf_low <= effects$hr & effects$hr <= effects$hr_conf_high))
  expect_named(
    estimate_treatment_effect(example_patient(), scale = c("ard", "ard")),
    c(names(patients), "baseline_risk", "ard", "ard_conf_low", "ard_conf_high")
  )
  expect_error(estimate_treatment_effect(example_patient(), scale = "or"), "should be one of")
})

test_that("results keep the class of the patient data and replace earlier results", {
  patients <- tibble::as_tibble(example_patient())
  risk <- predict_baseline_risk(patients)
  expect_s3_class(risk, "tbl_df")
  again <- predict_baseline_risk(risk)
  expect_equal(again, risk)
  expect_s3_class(estimate_treatment_effect(patients, scale = "hr"), "tbl_df")
})

test_that("values outside the development range give one warning naming the rows", {
  patients <- rbind(example_patient(), example_patient(hemoglobin = 50))
  expect_warning(
    predict_baseline_risk(patients),
    "Row 2: Hemoglobin of 50 g/L is outside the range in the trial data",
    class = "arpirisk_extrapolation_warning"
  )
  expect_warning(estimate_treatment_effect(patients, scale = "ard"), class = "arpirisk_extrapolation_warning")
  expect_no_warning(predict_baseline_risk(example_patient()))
})

test_that("values above the cap give a message without a warning", {
  expect_no_warning(
    expect_message(
      predict_baseline_risk(example_patient(psa = 9000)),
      "scored as 8,322 ng/mL",
      class = "arpirisk_cap_message"
    )
  )
})
