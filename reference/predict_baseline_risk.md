# Predict baseline risk of death

Deprecated: use
[`predict_risk()`](https://wfukuokaya.github.io/arpirisk/reference/predict_risk.md)
with `treatment = "adt"`, which returns the same columns.

## Usage

``` r
predict_baseline_risk(newdata, model = mhspc_model())
```

## Arguments

- newdata:

  A data frame with one row per patient and one column per input listed
  by
  [`model_inputs()`](https://wfukuokaya.github.io/arpirisk/reference/model_inputs.md):
  `ecog_ps` (0, 1, or 2), `gleason_score` (2 to 10),
  `visceral_metastasis` (0 or 1, or logical), `bone_metastases` (a
  count, or a category code `"0-3"`, `"4-6"`, `"7-10"`, or `"11+"`),
  `psa` (ng/mL), `hemoglobin` (g/L), `albumin` (g/L), `alp` (U/L), and
  `ldh` (U/L). Other columns are kept unchanged.

- model:

  An `mhspc_model` object from
  [`mhspc_model()`](https://wfukuokaya.github.io/arpirisk/reference/mhspc_model.md).

## Value

`newdata` with `linear_predictor` and `baseline_risk` added.
