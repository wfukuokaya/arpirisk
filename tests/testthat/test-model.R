test_that("the installed model loads, validates, and is cached", {
  model <- mhspc_model()
  expect_s3_class(model, "mhspc_model")
  expect_identical(mhspc_model(), model)
  expect_named(
    model$predictors,
    c("ecog_ps", "gleason_score", "visceral_metastasis", "bone_metastases",
      "psa", "hemoglobin", "albumin", "alp", "ldh")
  )
  expect_true(all(model$baseline_cumulative_hazard > 0))
})

test_that("a specification path is read without touching the cache", {
  path <- system.file("extdata", "model_spec.json", package = "mhspcarpi")
  model <- mhspc_model(path)
  expect_s3_class(model, "mhspc_model")
  expect_equal(model$meta, mhspc_model()$meta)
})

test_that("the model prints a short summary", {
  expect_snapshot(print(mhspc_model()))
})

test_that("invalid specifications are rejected", {
  expect_spec_error <- function(modify) {
    expect_error(mhspc_model(modified_spec(modify)), class = "mhspcarpi_spec_error")
  }
  expect_error(mhspc_model("no-such-file.json"), class = "mhspcarpi_spec_error")
  expect_error(mhspc_model(1), class = "mhspcarpi_spec_error")

  expect_spec_error(function(spec) {
    spec$schema_version <- 3L
    spec
  })
  expect_spec_error(function(spec) {
    spec$baseline_cumulative_hazard[[1L]] <- -1
    spec
  })
  expect_spec_error(function(spec) {
    spec$linear_predictor$shrinkage_factor <- 0
    spec
  })
  expect_spec_error(function(spec) {
    spec$predictors[[5L]]$knots <- rev(spec$predictors[[5L]]$knots)
    spec
  })
  expect_spec_error(function(spec) {
    spec$predictors[[5L]]$coefficients <- spec$predictors[[5L]]$coefficients[1:2]
    spec
  })
  expect_spec_error(function(spec) {
    spec$predictors[[5L]]$cap_upper <- "high"
    spec
  })
  expect_spec_error(function(spec) {
    spec$predictors[[4L]]$levels[[1L]]$coefficient <- 0.1
    spec
  })
  expect_spec_error(function(spec) {
    spec$predictors[[4L]]$levels[[2L]]$code <- "0-3"
    spec
  })
  expect_spec_error(function(spec) {
    spec$predictors[[4L]]$levels[[4L]]$max_count <- 50
    spec
  })
  expect_spec_error(function(spec) {
    spec$predictors[[1L]]$coefficient <- "x"
    spec
  })
  expect_spec_error(function(spec) {
    spec$predictors[[1L]]$threshold <- NULL
    spec
  })
  expect_spec_error(function(spec) {
    spec$predictors[[3L]]$choices <- list()
    spec
  })
  expect_spec_error(function(spec) {
    spec$predictors[[3L]]$type <- "ordinal"
    spec
  })
  expect_spec_error(function(spec) {
    spec$predictors[[2L]]$name <- "ecog_ps"
    spec
  })
  expect_spec_error(function(spec) {
    spec$treatment_effects$curves$rmst <- NULL
    spec
  })
  expect_spec_error(function(spec) {
    spec$treatment_effects$curves$ard$lp <- rev(spec$treatment_effects$curves$ard$lp)
    spec
  })
  expect_spec_error(function(spec) {
    spec$treatment_effects$curves$rmst$lp[[2L]] <- spec$treatment_effects$curves$rmst$lp[[2L]] + 1e-3
    spec
  })
  expect_spec_error(function(spec) {
    curve <- spec$treatment_effects$curves$ard
    spec$treatment_effects$curves$ard$conf_low <- curve$conf_high
    spec$treatment_effects$curves$ard$conf_high <- curve$conf_low
    spec
  })
  expect_spec_error(function(spec) {
    spec$treatment_effects$lp_range <- c(-1, 1)
    spec
  })
  expect_spec_error(function(spec) {
    spec$treatment_effects$overall$hr <- NULL
    spec
  })
})

test_that("linear continuous terms are supported and validated", {
  make_linear <- function(coefficients) {
    function(spec) {
      alp <- spec$predictors[[8L]]
      alp$type <- "linear"
      alp$knots <- NULL
      alp$terms <- "ALP"
      alp$coefficients <- coefficients
      spec$predictors[[8L]] <- alp
      spec
    }
  }
  model <- mhspc_model(modified_spec(make_linear(0.001)))
  inputs <- model_inputs(model)
  expect_equal(inputs$scoring[inputs$name == "alp"], "Linear")
  lp <- function(alp) predict_baseline_risk(example_patient(alp = alp), model)$linear_predictor
  expect_equal(lp(280) - lp(180), 100 * 0.001 * model$linear_predictor$shrinkage_factor)

  expect_error(mhspc_model(modified_spec(make_linear(c(0.001, 0.002)))), class = "mhspcarpi_spec_error")
  expect_error(
    mhspc_model(modified_spec(function(spec) {
      spec$predictors[[8L]]$allowed_range <- c(10, 0)
      spec
    })),
    class = "mhspcarpi_spec_error"
  )
  expect_equal(unit_hint(model$predictors$hemoglobin, NA_real_, "g/L"), "")
})

test_that("functions require an mhspc_model object", {
  expect_error(model_inputs(list()), class = "mhspcarpi_spec_error")
  expect_error(predict_baseline_risk(example_patient(), model = "model"), class = "mhspcarpi_spec_error")
})
