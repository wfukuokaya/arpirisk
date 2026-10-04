# Restricted cubic spline basis with the parameterization of rms::rcs(): the
# linear term followed by k - 2 nonlinear terms, each divided by the squared
# distance between the outer knots (Hmisc::rcspline.eval() with inclx = TRUE
# and its default norm = 2).
rcs_basis <- function(x, knots) {
  n_knots <- length(knots)
  first <- knots[[1L]]
  last <- knots[[n_knots]]
  penultimate <- knots[[n_knots - 1L]]
  positive_cube <- function(value) pmax(value, 0)^3

  nonlinear <- purrr::map(knots[seq_len(n_knots - 2L)], function(knot) {
    truncated <- positive_cube(x - knot) -
      positive_cube(x - penultimate) * (last - knot) / (last - penultimate) +
      positive_cube(x - last) * (penultimate - knot) / (last - penultimate)
    truncated / (last - first)^2
  })
  do.call(cbind, c(list(x), nonlinear))
}
