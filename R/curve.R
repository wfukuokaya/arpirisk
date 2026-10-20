#' Treatment effects across the range of baseline risk
#'
#' Returns the pooled treatment-effect curves on the grid of baseline risk used
#' in the analysis, for example to draw a figure or to tabulate effects.
#'
#' @inheritParams estimate_treatment_effect
#'
#' @return A data frame with one row per grid point and scale:
#'   `linear_predictor`, `baseline_risk` (a proportion), `scale`, `estimate`,
#'   the 95% confidence interval (`conf_low`, `conf_high`), and the 95%
#'   prediction interval for a new trial population (`pred_low`, `pred_high`).
#'   Hazard ratios are on the natural scale.
#' @examples
#' curve <- treatment_effect_curve("ard")
#' head(curve)
#' @export
treatment_effect_curve <- function(scale = c("ard", "rmst", "hr"), model = mhspc_model()) {
  check_model(model)
  scale <- match.arg(scale, several.ok = TRUE)
  lp <- model$treatment_effects$curves$ard$lp
  risk <- absolute_risk(lp, model)
  purrr::map(scale, function(effect_scale) {
    data.frame(
      linear_predictor = lp,
      baseline_risk = risk,
      scale = effect_scale,
      effect_at_lp(lp, model, effect_scale)
    )
  }) |>
    purrr::list_rbind()
}
