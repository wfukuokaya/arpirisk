# Estimate treatment effects at a patient's baseline risk

Returns the pooled treatment effects of an androgen receptor pathway
inhibitor (ARPI) plus ADT versus placebo plus ADT at each patient's
baseline risk. The effects were estimated within each of 4 randomized
clinical trials as smooth functions of baseline risk and pooled with
multivariate random-effects meta-analysis.

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
  [`model_inputs()`](https://wfukuokaya.github.io/mhspcarpi/reference/model_inputs.md):
  `ecog_ps` (0, 1, or 2), `gleason_score` (2 to 10),
  `visceral_metastasis` (0 or 1, or logical), `bone_metastases` (a
  count, or a category code `"0-3"`, `"4-6"`, `"7-10"`, or `"11+"`),
  `psa` (ng/mL), `hemoglobin` (g/L), `albumin` (g/L), `alp` (U/L), and
  `ldh` (U/L). Other columns are ignored.

- scale:

  Effects to return: `"ard"`, the difference in the probability of being
  alive at 4 years; `"rmst"`, the difference in restricted mean survival
  time through 4 years, in months; `"hr"`, the hazard ratio for death.

- model:

  An `mhspc_model` object from
  [`mhspc_model()`](https://wfukuokaya.github.io/mhspcarpi/reference/mhspc_model.md).

## Value

A data frame with one row per patient and scale: `row`, `baseline_risk`,
`scale`, `estimate`, the 95% confidence interval (`conf_low`,
`conf_high`), the 95% prediction interval for a new trial population
(`pred_low`, `pred_high`), `in_effect_range`, and `notes`.

## Details

Positive absolute effects indicate gains with an ARPI. For baseline
risks outside the range in which effects were estimated, the effect at
the nearest edge of that range is returned and `in_effect_range` is
`FALSE`.

## Examples

``` r
patient <- data.frame(
  ecog_ps = 0, gleason_score = 9, visceral_metastasis = 0,
  bone_metastases = 8, psa = 45, hemoglobin = 128, albumin = 41,
  alp = 180, ldh = 210
)
estimate_treatment_effect(patient)
#>   row baseline_risk scale  estimate  conf_low conf_high   pred_low pred_high
#> 1   1        0.5275   ard 0.1600444 0.1178061 0.2022826 0.06732166 0.2527671
#> 2   1        0.5275  rmst 4.3160264 3.1459691 5.4860837 1.59714817 7.0349046
#> 3   1        0.5275    hr 0.6043835 0.5308499 0.6881030 0.44904685 0.8134550
#>   in_effect_range notes
#> 1            TRUE  <NA>
#> 2            TRUE  <NA>
#> 3            TRUE  <NA>
```
