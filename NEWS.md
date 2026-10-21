# arpirisk 0.1.0

* Initial release.
* `predict_baseline_risk()` predicts the 4-year risk of all-cause death with
  placebo plus androgen deprivation therapy (ADT) for patients with metastatic
  hormone-sensitive prostate cancer, from a Cox model with 9 predictors (model
  version 261002-raw-rcs).
* `estimate_treatment_effect()` returns the pooled treatment effects of an
  androgen receptor pathway inhibitor (ARPI) plus ADT at a patient's baseline
  risk: the 4-year absolute risk difference, the restricted mean survival time
  difference through 4 years, and the hazard ratio, each with a 95% confidence
  interval.
* `check_inputs()` stops for missing or impossible values and flags values
  outside the development data; `model_inputs()` lists the predictors with
  their units, accepted values, and scoring; `mhspc_model()` loads the model
  specification.
* `example_patients` provides 6 synthetic patients spanning the range of
  baseline risk.
* The lower-level functions used by the web calculator
  (<https://github.com/wfukuokaya/arpirisk-app>) are documented in
  `?"app-api"`.
