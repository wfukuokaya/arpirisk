# Example patients

Six synthetic patients that span the range of baseline risk, for
examples and tests. They are not trial participants. Values are in the
model's units (see
[`model_inputs()`](https://wfukuokaya.github.io/arpirisk/reference/model_inputs.md)).

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
#>   patient_id ecog_ps gleason_score visceral_metastasis bone_metastases psa
#> 1         P1       0             7                   0               0   5
#> 2         P2       0             8                   0               2  12
#> 3         P3       0             9                   0               8  45
#> 4         P4       1             9                   0              15 150
#> 5         P5       1             8                   1               5  30
#> 6         P6       2            10                   1              30 800
#>   hemoglobin albumin alp ldh linear_predictor baseline_risk
#> 1        150      46  70 160       -0.6579870     0.1963982
#> 2        142      44  80 170       -0.3946690     0.2476209
#> 3        128      41 180 210        0.8187273     0.6160547
#> 4        115      38 420 280        1.6781886     0.8956950
#> 5        120      36 150 320        1.5096961     0.8519254
#> 6        105      34 500 350        2.2931052     0.9846912
```
