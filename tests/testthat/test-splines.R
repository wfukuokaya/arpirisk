test_that("the spline basis matches Hmisc::rcspline.eval for every model term", {
  skip_if_not_installed("Hmisc")
  model <- mhspc_model()
  rcs_predictors <- Filter(function(predictor) predictor$type == "rcs", model$predictors)
  expect_length(rcs_predictors, 5L)
  purrr::walk(rcs_predictors, function(predictor) {
    x <- seq(predictor$allowed_range[[1L]], predictor$development_range[[2L]], length.out = 301)
    expected <- Hmisc::rcspline.eval(x, knots = predictor$knots, inclx = TRUE)
    expect_equal(rcs_basis(x, predictor$knots), unname(expected), tolerance = 1e-12,
                 ignore_attr = TRUE, label = predictor$name)
  })
})

test_that("the spline basis has k - 1 columns and is linear beyond the outer knots", {
  knots <- c(1, 3, 6, 10)
  basis <- rcs_basis(c(11, 12, 13, 14), knots)
  expect_equal(ncol(basis), 3L)
  expect_equal(diff(basis[, 2L], differences = 2L), c(0, 0), tolerance = 1e-10)
  expect_equal(rcs_basis(c(-2, 0, 1), knots)[, 2:3], matrix(0, 3, 2))
})
