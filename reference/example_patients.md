# Example patients

Six synthetic patients that span the range of baseline risk, for
examples and tests. They are not trial participants. Values are in the
model's units (see
[`model_inputs()`](https://wfukuokaya.github.io/mhspcarpi/reference/model_inputs.md)).

## Usage

``` r
example_patients
```

## Format

A data frame with 6 rows and 10 columns: `patient_id` and the 9 model
inputs `ecog_ps`, `gleason_score`, `visceral_metastasis`,
`bone_metastases`, `psa`, `hemoglobin`, `albumin`, `alp`, and `ldh`.

## Source

Created in `data-raw/example_patients.R`.

## Examples

``` r
predict_baseline_risk(example_patients)
#>   row linear_predictor baseline_risk in_effect_range
#> 1   1       -0.9130882     0.1555849           FALSE
#> 2   2       -0.6475616     0.1979137            TRUE
#> 3   3        0.5761384     0.5275000            TRUE
#> 4   4        1.4173830     0.8242210            TRUE
#> 5   5        1.2584077     0.7730558            TRUE
#> 6   6        2.0277171     0.9592382            TRUE
#>                                                                                                                                             notes
#> 1 Baseline risk is outside the range in which treatment effects were estimated (19% to 96%); effects are shown at the nearest edge of that range.
#> 2                                                                                                                                            <NA>
#> 3                                                                                                                                            <NA>
#> 4                                                                                                                                            <NA>
#> 5                                                                                                                                            <NA>
#> 6                                                                                                                                            <NA>
```
