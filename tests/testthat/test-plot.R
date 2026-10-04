test_that("plot_treatment_effect draws every scale and returns the curve", {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  model <- mhspc_model()
  purrr::walk(c("ard", "rmst", "hr"), function(scale) {
    curve <- plot_treatment_effect(example_patient(), scale = scale, show_prediction_interval = TRUE)
    expect_s3_class(curve, "data.frame")
    expect_equal(nrow(curve), length(model$treatment_effects$curves$ard$lp))
  })
  expect_invisible(plot_treatment_effect())
  expect_invisible(plot_treatment_effect(rbind(example_patient(), low_risk_patient()), show_overall = FALSE))
  expect_error(plot_treatment_effect(scale = "or"), "should be one of")
})

test_that("plotting leaves graphical parameters unchanged", {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  before <- graphics::par("mar")
  plot_treatment_effect(example_patient())
  expect_equal(graphics::par("mar"), before)
})

test_that("the x axis spans 0% to 100% baseline risk", {
  grDevices::pdf(NULL, width = 6, height = 4)
  on.exit(grDevices::dev.off(), add = TRUE)
  purrr::walk(c("ard", "hr"), function(scale) {
    plot_treatment_effect(example_patient(), scale = scale)
    expect_equal(graphics::par("usr")[1:2], c(0, 100))
  })
})

test_that("the ARD curve is shown per 100 patients", {
  model <- mhspc_model()
  curve <- effect_curve(model, "ard")
  expect_equal(curve$estimate, 100 * model$treatment_effects$curves$ard$estimate)
  expect_equal(overall_effect(model, "ard"), 100 * model$treatment_effects$overall$ard$estimate)
  expect_equal(range(curve$risk_percent), 100 * effect_risk_range(model))
})

test_that("hazard ratio ticks stay within the limits", {
  expect_equal(hr_ticks(c(0.45, 0.95)), c(0.5, 0.6, 0.7, 0.8, 0.9))
  expect_equal(hr_ticks(c(0.2, 2)), c(0.2, 0.4, 0.6, 0.8, 1, 1.5))
})

test_that("axis titles shrink to fit narrow plots", {
  grDevices::pdf(NULL, width = 3, height = 3)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::plot.new()
  label <- "4-year risk of death with ADT alone"
  expect_equal(label_cex(label, width_inches = 10), 0.95)
  narrow <- label_cex(label, width_inches = 1.5)
  expect_lt(narrow, 0.95)
  expect_lte(graphics::strwidth(label, units = "inches", cex = narrow), 1.5 + 1e-8)
  expect_invisible(plot_treatment_effect(example_patient()))
})
