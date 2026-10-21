# Predict baseline risk of death

Adds each patient's linear predictor and predicted risk of death within
4 years with androgen deprivation therapy (ADT) alone, called baseline
risk.

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

`newdata` with two columns added: `linear_predictor`, the model's risk
score, and `baseline_risk`, the predicted 4-year risk of death as a
proportion. Existing columns with these names are replaced.

## Details

Inputs are checked first. Missing or invalid values stop with an error
that names the row and input. Values outside the range in the trial data
give a warning, because their estimates are extrapolations. Values above
the upper cap used in model development are scored at the cap, with a
message.

## Examples

``` r
# Your own patient data: one row per patient, one column per input, plus any
# other columns, which are kept.
patients <- data.frame(
  patient_id = c("A", "B"),
  ecog_ps = c(0, 1), gleason_score = c(9, 9), visceral_metastasis = c(0, 0),
  bone_metastases = c(8, 15), psa = c(45, 150), hemoglobin = c(128, 115),
  albumin = c(41, 38), alp = c(180, 420), ldh = c(210, 280)
)
risk <- predict_baseline_risk(patients)
risk[c("patient_id", "baseline_risk")]
#>   patient_id baseline_risk
#> 1          A     0.6160547
#> 2          B     0.8956950
```
