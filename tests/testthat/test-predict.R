test_that("reference profiles scored by the analysis code are reproduced", {
  model <- mhspc_model()
  reference <- model$verification$reference_profiles
  inputs <- as.data.frame(reference$inputs[names(reference$inputs) != "profile"])
  expected <- reference$expected

  risk <- predict_baseline_risk(inputs)
  expect_equal(risk$linear_predictor, expected$linear_predictor, tolerance = 1e-8)
  expect_equal(risk$baseline_risk, expected$baseline_risk, tolerance = 1e-8)

  effects <- estimate_treatment_effect(inputs)
  estimate <- function(scale) effects$estimate[effects$scale == scale]
  expect_equal(estimate("ard"), expected$ard, tolerance = 1e-8)
  expect_equal(estimate("rmst"), expected$rmst, tolerance = 1e-8)
  expect_equal(estimate("hr"), expected$hr, tolerance = 1e-8)
})

test_that("baseline risk is a proportion that increases with the linear predictor", {
  model <- mhspc_model()
  lp <- seq(-3, 3, by = 0.25)
  risk <- absolute_risk(lp, model)
  expect_true(all(risk > 0 & risk < 1))
  expect_true(all(diff(risk) > 0))
})

test_that("predict_baseline_risk returns one row per patient in input order", {
  patients <- rbind(example_patient(), low_risk_patient(), example_patient(ecog_ps = 1))
  risk <- predict_baseline_risk(patients)
  expect_named(risk, c("row", "linear_predictor", "baseline_risk", "in_effect_range", "notes"))
  expect_equal(risk$row, 1:3)
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

  effects <- estimate_treatment_effect(low_risk_patient(), scale = "ard")
  expect_false(effects$in_effect_range)
  expect_match(effects$notes, "outside the range in which treatment effects were estimated")
  expect_equal(effects$estimate, model$treatment_effects$curves$ard$estimate[[1L]])
})

test_that("estimate_treatment_effect returns the requested scales in order", {
  effects <- estimate_treatment_effect(rbind(example_patient(), example_patient()), scale = c("hr", "ard"))
  expect_equal(nrow(effects), 4L)
  expect_equal(effects$scale, c("hr", "ard", "hr", "ard"))
  expect_equal(effects$row, c(1L, 1L, 2L, 2L))
  expect_true(all(effects$conf_low <= effects$estimate & effects$estimate <= effects$conf_high))
  expect_true(all(effects$pred_low <= effects$conf_low & effects$conf_high <= effects$pred_high))
  expect_error(estimate_treatment_effect(example_patient(), scale = "or"), "should be one of")
})

test_that("values outside the development range trigger one warning and a note", {
  expect_warning(
    risk <- predict_baseline_risk(example_patient(hemoglobin = 50)),
    class = "mhspcarpi_extrapolation_warning"
  )
  expect_match(risk$notes, "extrapolation")
  expect_true(is.na(predict_baseline_risk(example_patient())$notes))
})

test_that("notes for values above the cap are kept without a warning", {
  expect_no_warning(risk <- predict_baseline_risk(example_patient(psa = 9000)))
  expect_match(risk$notes, "scored as")
})
