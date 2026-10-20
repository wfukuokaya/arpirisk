# Get started with arpirisk

arpirisk predicts the 4-year risk of all-cause death with placebo plus
androgen deprivation therapy (ADT), called baseline risk, in metastatic
hormone-sensitive prostate cancer (mHSPC), and returns the pooled
treatment effects of an androgen receptor pathway inhibitor (ARPI) plus
ADT at that baseline risk.

``` r

library(arpirisk)
```

## Inputs

[`model_inputs()`](https://wfukuokaya.github.io/arpirisk/reference/model_inputs.md)
lists the 9 predictors with their column names, units, accepted values,
and scoring. `example_patients` contains 6 synthetic patients spanning
the range of baseline risk.

``` r

model_inputs()[c("name", "unit", "accepted", "scoring")]
#>                  name  unit                                            accepted
#> 1             ecog_ps  <NA>                                             0, 1, 2
#> 2       gleason_score  <NA>                          2, 3, 4, 5, 6, 7, 8, 9, 10
#> 3 visceral_metastasis  <NA>                                                0, 1
#> 4     bone_metastases count Count, or category code "0-3", "4-6", "7-10", "11+"
#> 5                 psa ng/mL                                        0 to 100,000
#> 6          hemoglobin   g/L                                           20 to 250
#> 7             albumin   g/L                                            10 to 70
#> 8                 alp   U/L                                         0 to 10,000
#> 9                 ldh   U/L                                         0 to 10,000
#>                                                                                 scoring
#> 1                                                                           0 vs 1 or 2
#> 2                                                                         ≤8 vs 9 or 10
#> 3                                                             Absent (0) or present (1)
#> 4                                                        Categories 0–3, 4–6, 7–10, ≥11
#> 5 Restricted cubic spline; trial data 0 to 19,000; values above 8,322 scored at the cap
#> 6                                         Restricted cubic spline; trial data 57 to 186
#> 7                                        Restricted cubic spline; trial data 24 to 61.5
#> 8 Restricted cubic spline; trial data 26 to 7,680; values above 4,824 scored at the cap
#> 9 Restricted cubic spline; trial data 67 to 4,124; values above 1,470 scored at the cap
example_patients
#>   patient_id ecog_ps gleason_score visceral_metastasis bone_metastases psa
#> 1         P1       0             7                   0               0   5
#> 2         P2       0             8                   0               2  12
#> 3         P3       0             9                   0               8  45
#> 4         P4       1             9                   0              15 150
#> 5         P5       1             8                   1               5  30
#> 6         P6       2            10                   1              30 800
#>   hemoglobin albumin alp ldh
#> 1        150      46  70 160
#> 2        142      44  80 170
#> 3        128      41 180 210
#> 4        115      38 420 280
#> 5        120      36 150 320
#> 6        105      34 500 350
```

## Baseline risk

[`predict_baseline_risk()`](https://wfukuokaya.github.io/arpirisk/reference/predict_baseline_risk.md)
returns the shrunken, centered linear predictor and the 4-year risk. The
`notes` column flags values outside the development data and baseline
risks outside the range in which treatment effects were estimated.

``` r

predict_baseline_risk(example_patients)
#>   row linear_predictor baseline_risk in_effect_range
#> 1   1       -0.6579870     0.1963982            TRUE
#> 2   2       -0.3946690     0.2476209            TRUE
#> 3   3        0.8187273     0.6160547            TRUE
#> 4   4        1.6781886     0.8956950            TRUE
#> 5   5        1.5096961     0.8519254            TRUE
#> 6   6        2.2931052     0.9846912           FALSE
#>                                                                                                                                             notes
#> 1                                                                                                                                            <NA>
#> 2                                                                                                                                            <NA>
#> 3                                                                                                                                            <NA>
#> 4                                                                                                                                            <NA>
#> 5                                                                                                                                            <NA>
#> 6 Baseline risk is outside the range in which treatment effects were estimated (19% to 96%); effects are shown at the nearest edge of that range.
```

## Treatment effects

[`estimate_treatment_effect()`](https://wfukuokaya.github.io/arpirisk/reference/estimate_treatment_effect.md)
returns, in long format, the absolute risk difference at 4 years
(`ard`), the restricted mean survival time difference through 4 years in
months (`rmst`), and the hazard ratio (`hr`), each with a 95% confidence
interval (`conf_low`, `conf_high`).

``` r

effects <- estimate_treatment_effect(example_patients)
effects[effects$row == 3, c("scale", "estimate", "conf_low", "conf_high")]
#>   scale  estimate  conf_low conf_high
#> 7   ard 0.1564764 0.1044090 0.2085438
#> 8  rmst 5.0448804 3.5714697 6.5182911
#> 9    hr 0.6037809 0.5201066 0.7009167
```

## Checking inputs

[`check_inputs()`](https://wfukuokaya.github.io/arpirisk/reference/check_inputs.md)
stops with an informative error for missing or impossible values and
returns warnings and notes for values outside the development data.

``` r

patient <- example_patients[1, ]
patient$hemoglobin <- -1
check_inputs(patient)
#> Error in `check_inputs()`:
#> ! `newdata` has invalid or missing values.
#> ✖ Row 1: Hemoglobin must be between 20 and 250 g/L.
```

``` r

patient$hemoglobin <- 150
patient$psa <- 20000
check_inputs(patient)
#>   row input severity
#> 1   1   psa     note
#>                                                                                                  message
#> 1 Prostate-specific antigen values above 8,322 ng/mL are scored as 8,322 ng/mL, as in model development.
```

## Model specification

``` r

mhspc_model()
#> mHSPC ARPI treatment-effect model (261002-raw-rcs)
#> • Baseline risk: All-cause death within 4 years with Placebo plus ADT.
#> • Inputs: ecog_ps, gleason_score, visceral_metastasis, bone_metastases, psa,
#>   hemoglobin, albumin, alp, and ldh.
#> • Treatment effects of ARPI plus ADT: survival difference, restricted mean
#>   survival time difference, and hazard ratio.
```

The specification is at
`system.file("extdata", "model_spec.json", package = "arpirisk")`.
