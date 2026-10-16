# Treatment effects across the range of baseline risk

Returns the pooled treatment-effect curves on the grid of baseline risk
used in the analysis, for example to draw a custom figure or to tabulate
effects.
[`plot_treatment_effect()`](https://wfukuokaya.github.io/mhspcarpi/reference/plot_treatment_effect.md)
draws the same curves.

## Usage

``` r
treatment_effect_curve(scale = c("ard", "rmst", "hr"), model = mhspc_model())
```

## Arguments

- scale:

  Effects to return: `"ard"`, the difference in the probability of being
  alive at 4 years; `"rmst"`, the difference in restricted mean survival
  time through 4 years, in months; `"hr"`, the hazard ratio for death.

- model:

  An `mhspc_model` object from
  [`mhspc_model()`](https://wfukuokaya.github.io/mhspcarpi/reference/mhspc_model.md).

## Value

A data frame with one row per grid point and scale: `linear_predictor`,
`baseline_risk` (a proportion), `scale`, `estimate`, the 95% confidence
interval (`conf_low`, `conf_high`), and the 95% prediction interval for
a new trial population (`pred_low`, `pred_high`). Hazard ratios are on
the natural scale.

## Examples

``` r
curve <- treatment_effect_curve("ard")
head(curve)
#>   linear_predictor baseline_risk scale     estimate    conf_low  conf_high
#> 1       -0.7167630     0.1863059   ard -0.012105244 -0.11741399 0.09320350
#> 2       -0.6886720     0.1910711   ard -0.006184372 -0.10643886 0.09407012
#> 3       -0.6605811     0.1959429   ard -0.000263500 -0.09552845 0.09500145
#> 4       -0.6324902     0.2009229   ard  0.005657372 -0.08469347 0.09600821
#> 5       -0.6043992     0.2060126   ard  0.011578244 -0.07394692 0.09710341
#> 6       -0.5763083     0.2112134   ard  0.017499116 -0.06330466 0.09830290
#>     pred_low pred_high
#> 1 -0.2432823 0.2190718
#> 2 -0.2262661 0.2138974
#> 3 -0.2093921 0.2088651
#> 4 -0.1926836 0.2039983
#> 5 -0.1761693 0.1993257
#> 6 -0.1598838 0.1948821
```
