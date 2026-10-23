# Estimate treatment effects at a patient's baseline risk

Adds each patient's baseline risk and the treatment effects of adding an
androgen receptor pathway inhibitor (ARPI) to androgen deprivation
therapy (ADT) at that risk.

## Usage

``` r
estimate_treatment_effect(
  newdata,
  scale = c("ard", "rmst", "hr"),
  model = mhspc_model()
)
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

- scale:

  Effects to add: `"ard"`, the difference in the probability of being
  alive at 4 years; `"rmst"`, the difference in restricted mean survival
  time through 4 years, in months; `"hr"`, the hazard ratio for death.

- model:

  An `mhspc_model` object from
  [`mhspc_model()`](https://wfukuokaya.github.io/arpirisk/reference/mhspc_model.md).

## Value

`newdata` with `baseline_risk` and, for each scale, the estimate in a
column named after the scale (for example, `ard`) and its 95% confidence
interval (`ard_conf_low`, `ard_conf_high`). Existing columns with these
names are replaced.

## Details

Positive absolute effects indicate gains with an ARPI. For baseline
risks outside the range in which effects were estimated, the effect at
the nearest edge of that range is returned, with a warning. Inputs are
checked as in
[`predict_risk()`](https://wfukuokaya.github.io/arpirisk/reference/predict_risk.md).

## Examples

``` r
patients <- example_patients[1:5, ]

# Difference in the proportion alive at 4 years with an ARPI: 0.16 means 16
# more patients alive per 100 treated
effects <- estimate_treatment_effect(patients, scale = "ard")
effects[c("patient_id", "baseline_risk", "ard", "ard_conf_low", "ard_conf_high")]
#>   patient_id baseline_risk          ard  ard_conf_low ard_conf_high
#> 1         P1     0.1963982 0.0002832789 -0.0945278628    0.09509442
#> 2         P2     0.2476209 0.0556955429  0.0009928562    0.11039823
#> 3         P3     0.6160547 0.1564764237  0.1044090043    0.20854384
#> 4         P4     0.8956950 0.1276327083  0.0643407300    0.19092469
#> 5         P5     0.8519254 0.1339398816  0.0803733946    0.18750637

# Additional months alive over 4 years, and the hazard ratio for death
effects <- estimate_treatment_effect(patients, scale = c("rmst", "hr"))
effects[c("patient_id", "rmst", "hr", "hr_conf_low", "hr_conf_high")]
#>   patient_id      rmst        hr hr_conf_low hr_conf_high
#> 1         P1 0.6177355 0.7546903   0.4189299    1.3595529
#> 2         P2 0.9992638 0.7079847   0.5042109    0.9941125
#> 3         P3 5.0448804 0.6037809   0.5201066    0.7009167
#> 4         P4 3.9459309 0.6854302   0.5295363    0.8872186
#> 5         P5 4.3633263 0.6642831   0.5388831    0.8188642
```
