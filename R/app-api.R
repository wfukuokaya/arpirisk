#' Building blocks for the web calculator
#'
#' Lower-level functions used by the web calculator, which is developed in a
#' separate repository (<https://github.com/wfukuokaya/arpirisk-app>) and
#' calls them step by step. They may change between minor versions; analyses
#' should use [predict_risk()] and [estimate_treatment_effect()].
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
#'
#' @name app-api
#' @aliases check_model assess_inputs assess_categorical issue_message unit_multiplier
#' @aliases linear_predictor absolute_risk in_effect_range effect_at_lp effect_risk_range
#' @keywords internal
#' @rawNamespace export(check_model, assess_inputs, assess_categorical, issue_message)
#' @rawNamespace export(unit_multiplier, linear_predictor, absolute_risk, in_effect_range)
#' @rawNamespace export(effect_at_lp, effect_risk_range)
NULL
