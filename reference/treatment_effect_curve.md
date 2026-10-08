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
#> 1       -0.7083770     0.1874087   ard -0.009148616 -0.11314296 0.09484573
#> 2       -0.6804668     0.1921675   ard -0.003419776 -0.10245456 0.09561500
#> 3       -0.6525567     0.1970319   ard  0.002309064 -0.09183016 0.09644828
#> 4       -0.6246465     0.2020034   ard  0.008037904 -0.08128028 0.09735609
#> 5       -0.5967364     0.2070835   ard  0.013766744 -0.07081767 0.09835116
#> 6       -0.5688262     0.2122737   ard  0.019495585 -0.06045784 0.09944901
#>     pred_low pred_high
#> 1 -0.2374402 0.2191430
#> 2 -0.2208240 0.2139845
#> 3 -0.2043483 0.2089664
#> 4 -0.1880362 0.2041120
#> 5 -0.1719156 0.1994491
#> 6 -0.1560207 0.1950118
```
