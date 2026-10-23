# Building blocks for the web calculator

Lower-level functions used by the web calculator, which is developed in
a separate repository (<https://github.com/wfukuokaya/arpirisk-app>) and
calls them step by step. They may change between minor versions;
analyses should use
[`predict_risk()`](https://wfukuokaya.github.io/arpirisk/reference/predict_risk.md)
and
[`estimate_treatment_effect()`](https://wfukuokaya.github.io/arpirisk/reference/estimate_treatment_effect.md).

## Functions

- `check_model(model)` validates a model specification.

- `assess_inputs(newdata, model)` converts inputs to the model's scale
  and lists issues with them; `assess_categorical(x, predictor)` does
  this for one categorical predictor.

- `issue_message(code, predictor, value, unit, app)` and
  `unit_multiplier(predictor, unit)` describe issues and convert units.

- `linear_predictor(values, model)`, `absolute_risk(lp, model)`,
  `in_effect_range(lp, model)`, `effect_at_lp(lp, model, scale)`, and
  `effect_risk_range(model)` compute the baseline risk and the treatment
  effects from values on the model's scale.
