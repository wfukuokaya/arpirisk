
<!-- README.md is generated from README.Rmd, which knits the body of vignettes/arpirisk.qmd. Edit the vignette, then run rmarkdown::render("README.Rmd"). -->

# arpirisk

<!-- badges: start -->

[![R-CMD-check](https://github.com/wfukuokaya/arpirisk/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/wfukuokaya/arpirisk/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

arpirisk predicts the 4-year risk of all-cause death with androgen deprivation therapy (ADT) alone, called baseline risk, in metastatic hormone-sensitive prostate cancer (mHSPC), and estimates the treatment effects of adding an androgen receptor pathway inhibitor (ARPI) at that baseline risk. Both prediction functions take a data frame with one row per patient and return it with the results added as new columns.

## Installation

``` r
pak::pak("wfukuokaya/arpirisk")
```

## Usage

``` r
library(arpirisk)
library(dplyr)
```

## Inputs

`model_inputs()` lists the 9 inputs with their column names, units, and accepted values. `example_patients` contains 6 synthetic patients spanning the range of baseline risk.

``` r
model_inputs() |>
  select(name, unit, accepted)
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

patients <- as_tibble(example_patients)
patients
#> # A tibble: 6 × 10
#>   patient_id ecog_ps gleason_score visceral_metastasis bone_metastases   psa
#>   <chr>        <dbl>         <dbl>               <dbl>           <dbl> <dbl>
#> 1 P1               0             7                   0               0     5
#> 2 P2               0             8                   0               2    12
#> 3 P3               0             9                   0               8    45
#> 4 P4               1             9                   0              15   150
#> 5 P5               1             8                   1               5    30
#> 6 P6               2            10                   1              30   800
#> # ℹ 4 more variables: hemoglobin <dbl>, albumin <dbl>, alp <dbl>, ldh <dbl>
```

## Predicted risk

`predict_risk()` adds the linear predictor and the 4-year risk of death with ADT alone (`baseline_risk`) and with an ARPI plus ADT (`arpi_risk`) to the patient data. The risk with an ARPI is the baseline risk minus the absolute risk difference at that baseline risk, so it follows the treatment effects described below and gives the same warning for baseline risks outside the range in which effects were estimated. Use `treatment = "adt"` or `treatment = "arpi"` to add only one of the two risks.

``` r
patients |>
  predict_risk() |>
  select(patient_id, linear_predictor, baseline_risk, arpi_risk)
#> Warning: 1 patient has a baseline risk outside the range in which treatment effects were
#> estimated (19% to 96%).
#> ℹ Their effects are taken at the nearest edge of that range.
#> ℹ Row: 6.
#> # A tibble: 6 × 4
#>   patient_id linear_predictor baseline_risk arpi_risk
#>   <chr>                 <dbl>         <dbl>     <dbl>
#> 1 P1                   -0.658         0.196     0.196
#> 2 P2                   -0.395         0.248     0.192
#> 3 P3                    0.819         0.616     0.460
#> 4 P4                    1.68          0.896     0.768
#> 5 P5                    1.51          0.852     0.718
#> 6 P6                    2.29          0.985     0.872
```

## Treatment effects

`estimate_treatment_effect()` adds the baseline risk and, for each requested scale, the estimate with its 95% confidence interval: the difference in the proportion of patients alive at 4 years (`ard`), the difference in restricted mean survival time through 4 years in months (`rmst`), and the hazard ratio for death (`hr`). A warning names the patients whose baseline risk lies outside the range in which effects were estimated; their effects are taken at the nearest edge of that range.

``` r
effects <- patients |>
  estimate_treatment_effect()
#> Warning: 1 patient has a baseline risk outside the range in which treatment effects were
#> estimated (19% to 96%).
#> ℹ Their effects are taken at the nearest edge of that range.
#> ℹ Row: 6.
effects |>
  select(patient_id, baseline_risk, starts_with(c("ard", "rmst")))
#> # A tibble: 6 × 8
#>   patient_id baseline_risk      ard ard_conf_low ard_conf_high  rmst
#>   <chr>              <dbl>    <dbl>        <dbl>         <dbl> <dbl>
#> 1 P1                 0.196 0.000283    -0.0945          0.0951 0.618
#> 2 P2                 0.248 0.0557       0.000993        0.110  0.999
#> 3 P3                 0.616 0.156        0.104           0.209  5.04 
#> 4 P4                 0.896 0.128        0.0643          0.191  3.95 
#> 5 P5                 0.852 0.134        0.0804          0.188  4.36 
#> 6 P6                 0.985 0.113        0.0146          0.212  2.99 
#> # ℹ 2 more variables: rmst_conf_low <dbl>, rmst_conf_high <dbl>
```

For reporting, express the risk and the absolute risk difference per 100 patients.

``` r
effects |>
  mutate(across(c(baseline_risk, starts_with("ard")), \(x) round(100 * x))) |>
  select(patient_id, baseline_risk, ard, ard_conf_low, ard_conf_high, hr)
#> # A tibble: 6 × 6
#>   patient_id baseline_risk   ard ard_conf_low ard_conf_high    hr
#>   <chr>              <dbl> <dbl>        <dbl>         <dbl> <dbl>
#> 1 P1                    20     0           -9            10 0.755
#> 2 P2                    25     6            0            11 0.708
#> 3 P3                    62    16           10            21 0.604
#> 4 P4                    90    13            6            19 0.685
#> 5 P5                    85    13            8            19 0.664
#> 6 P6                    98    11            1            21 0.736
```

## Input checks

Both functions check the inputs before predicting. Missing or impossible values stop with an error that names the row and input.

``` r
patients |>
  mutate(hemoglobin = if_else(patient_id == "P1", -1, hemoglobin)) |>
  predict_risk()
#> Error in `predict_risk()`:
#> ! `newdata` has invalid or missing values.
#> ✖ Row 1: Hemoglobin must be between 20 and 250 g/L.
```

Values outside the range in the trial data give a warning, because their estimates are extrapolations.

``` r
patients |>
  mutate(hemoglobin = if_else(patient_id == "P2", 50, hemoglobin)) |>
  predict_risk(treatment = "adt") |>
  select(patient_id, hemoglobin, baseline_risk)
#> Warning: Some values are outside the range in the trial data; their estimates are
#> extrapolations.
#> ! Row 2: Hemoglobin of 50 g/L is outside the range in the trial data (57 to 186
#>   g/L); the estimate is an extrapolation.
#> # A tibble: 6 × 3
#>   patient_id hemoglobin baseline_risk
#>   <chr>           <dbl>         <dbl>
#> 1 P1                150         0.196
#> 2 P2                 50         0.651
#> 3 P3                128         0.616
#> 4 P4                115         0.896
#> 5 P5                120         0.852
#> 6 P6                105         0.985
```

## Model specification

``` r
mhspc_model()
#> mHSPC ARPI treatment-effect model (261002-raw-rcs)
#> • Baseline risk: All-cause death within 4 years with ADT alone.
#> • Inputs: ecog_ps, gleason_score, visceral_metastasis, bone_metastases, psa,
#>   hemoglobin, albumin, alp, and ldh.
#> • Treatment effects of ARPI plus ADT: survival difference, restricted mean
#>   survival time difference, and hazard ratio.
```

The specification is at `system.file("extdata", "model_spec.json", package = "arpirisk")`.

## Citation

Methods and model performance are described in our article: `citation("arpirisk")`. The article will be added on publication.
