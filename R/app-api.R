#' Building blocks for the web calculator
#'
#' Lower-level functions used by the web calculator, which is developed in a
#' separate repository (<https://github.com/wfukuokaya/mhspcarpi-app>) and
#' calls them step by step. They may change between minor versions; analyses
#' should use [predict_baseline_risk()], [estimate_treatment_effect()],
#' [check_inputs()], [plot_treatment_effect()], and
#' [treatment_effect_curve()].
#'
#' @section Functions:
#' - `check_model(model)` validates a model specification.
#' - `assess_inputs(newdata, model)` converts inputs to the model's scale and
#'   lists issues with them; `assess_categorical(x, predictor)` does this for
#'   one categorical predictor.
#' - `issue_message(code, predictor, value, unit, app)` and
#'   `unit_multiplier(predictor, unit)` describe issues and convert units.
#' - `linear_predictor(values, model)`, `absolute_risk(lp, model)`,
#'   `in_effect_range(lp, model)`, `effect_at_lp(lp, model, scale)`, and
#'   `effect_risk_range(model)` compute the baseline risk and the treatment
#'   effects from values on the model's scale.
#' - `effect_scales()`, `effect_curve(model, scale)`,
#'   `overall_effect(model, scale)`, `effect_plot_par()`, and
#'   `draw_effect_plot(curve, scale, ...)` draw the treatment-effect plot.
#'
#' @name app-api
#' @aliases check_model assess_inputs assess_categorical issue_message unit_multiplier
#' @aliases linear_predictor absolute_risk in_effect_range effect_at_lp effect_risk_range
#' @aliases effect_scales effect_curve overall_effect effect_plot_par draw_effect_plot
#' @keywords internal
#' @rawNamespace export(check_model, assess_inputs, assess_categorical, issue_message)
#' @rawNamespace export(unit_multiplier, linear_predictor, absolute_risk, in_effect_range)
#' @rawNamespace export(effect_at_lp, effect_risk_range, effect_scales, effect_curve)
#' @rawNamespace export(overall_effect, effect_plot_par, draw_effect_plot)
NULL
