# Predict baseline risk of death

Calculates each patient's predicted risk of death within 4 years with
placebo plus androgen deprivation therapy (ADT). Treatment-effect
estimates are indexed on this baseline risk.

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
  `ldh` (U/L). Other columns are ignored.

- model:

  An `mhspc_model` object from
  [`mhspc_model()`](https://wfukuokaya.github.io/arpirisk/reference/mhspc_model.md).

## Value

A data frame with one row per patient in `newdata`:

- row:

  Row number in `newdata`.

- linear_predictor:

  Linear predictor for placebo plus ADT.

- baseline_risk:

  Predicted 4-year risk of death, as a proportion.

- in_effect_range:

  Whether the baseline risk lies within the range in which treatment
  effects were estimated.

- notes:

  Warnings and notes about the inputs, or `NA`.

## Details

The linear predictor is the shrunken, centered Cox linear predictor for
placebo plus ADT.

## Examples

``` r
patient <- data.frame(
  ecog_ps = 0, gleason_score = 9, visceral_metastasis = 0,
  bone_metastases = 8, psa = 45, hemoglobin = 128, albumin = 41,
  alp = 180, ldh = 210
)
predict_baseline_risk(patient)
#>   row linear_predictor baseline_risk in_effect_range notes
#> 1   1        0.8187273     0.6160547            TRUE  <NA>
```
