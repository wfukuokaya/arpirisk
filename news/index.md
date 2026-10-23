# Changelog

## arpirisk (development version)

- New
  [`predict_risk()`](https://wfukuokaya.github.io/arpirisk/reference/predict_risk.md)
  adds the predicted 4-year risk of death with ADT alone
  (`baseline_risk`), with an ARPI plus ADT (`arpi_risk`), or both,
  chosen with `treatment = c("adt", "arpi")`. The risk with an ARPI is
  the baseline risk minus the absolute risk difference at that risk;
  when it is requested, baseline risks outside the range in which
  treatment effects were estimated give the same warning as in
  [`estimate_treatment_effect()`](https://wfukuokaya.github.io/arpirisk/reference/estimate_treatment_effect.md).
- [`predict_baseline_risk()`](https://wfukuokaya.github.io/arpirisk/reference/predict_baseline_risk.md)
  is deprecated. Use `predict_risk(treatment = "adt")`, which returns
  the same columns.

## arpirisk 0.1.0

- Initial release.
- [`predict_baseline_risk()`](https://wfukuokaya.github.io/arpirisk/reference/predict_baseline_risk.md)
  adds to a data frame of patients each patient’s linear predictor and
  predicted 4-year risk of all-cause death with androgen deprivation
  therapy (ADT) alone, from a Cox model with 9 predictors (model version
  261002-raw-rcs).
- [`estimate_treatment_effect()`](https://wfukuokaya.github.io/arpirisk/reference/estimate_treatment_effect.md)
  adds the baseline risk and the treatment effects of adding an androgen
  receptor pathway inhibitor (ARPI) to ADT at that risk: the 4-year
  absolute risk difference, the restricted mean survival time difference
  through 4 years, and the hazard ratio, each with a 95% confidence
  interval.
- Both functions check the inputs: missing or impossible values stop
  with an error naming the row and input, and values outside the trial
  data give a warning.
  [`model_inputs()`](https://wfukuokaya.github.io/arpirisk/reference/model_inputs.md)
  lists the inputs with their units and accepted values;
  [`mhspc_model()`](https://wfukuokaya.github.io/arpirisk/reference/mhspc_model.md)
  loads the model specification.
- `example_patients` provides 6 synthetic patients spanning the range of
  baseline risk.
- The lower-level functions used by the web calculator
  (<https://github.com/wfukuokaya/arpirisk-app>) are documented in
  [`?"app-api"`](https://wfukuokaya.github.io/arpirisk/reference/app-api.md).
