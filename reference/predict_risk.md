# Predict risk of death with ADT alone or with an ARPI plus ADT

Adds each patient's linear predictor and predicted risk of death within
4 years with androgen deprivation therapy (ADT) alone, called baseline
risk, with an androgen receptor pathway inhibitor (ARPI) plus ADT, or
both.

## Usage

``` r
predict_risk(newdata, treatment = c("adt", "arpi"), model = mhspc_model())
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

- treatment:

  Treatments to predict risk for: `"adt"`, ADT alone, and `"arpi"`, an
  ARPI plus ADT.

- model:

  An `mhspc_model` object from
  [`mhspc_model()`](https://wfukuokaya.github.io/arpirisk/reference/mhspc_model.md).

## Value

`newdata` with `linear_predictor`, the model's risk score, and, for each
treatment in the order requested, the predicted 4-year risk of death as
a proportion: `baseline_risk` for ADT alone and `arpi_risk` for an ARPI
plus ADT. Existing columns with these names are replaced.

## Details

The risk with an ARPI plus ADT is the baseline risk minus the absolute
risk difference at that baseline risk, the `ard` estimate of
[`estimate_treatment_effect()`](https://wfukuokaya.github.io/arpirisk/reference/estimate_treatment_effect.md).
It therefore reflects how the treatment effect varies with baseline
risk, not a constant hazard ratio. For baseline risks outside the range
in which effects were estimated, the effect at the nearest edge of that
range is used, with a warning.

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

# Risk with ADT alone and with an ARPI plus ADT
risk <- predict_risk(patients)
risk[c("patient_id", "baseline_risk", "arpi_risk")]
#>   patient_id baseline_risk arpi_risk
#> 1          A     0.6160547 0.4595782
#> 2          B     0.8956950 0.7680623

# Risk with ADT alone only
predict_risk(patients, treatment = "adt")
#>   patient_id ecog_ps gleason_score visceral_metastasis bone_metastases psa
#> 1          A       0             9                   0               8  45
#> 2          B       1             9                   0              15 150
#>   hemoglobin albumin alp ldh linear_predictor baseline_risk
#> 1        128      41 180 210        0.8187273     0.6160547
#> 2        115      38 420 280        1.6781886     0.8956950
```
