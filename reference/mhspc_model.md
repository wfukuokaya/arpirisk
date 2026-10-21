# Load the risk model and treatment-effect estimates

`mhspc_model()` reads the model specification, checks that it is
internally consistent, and returns it as an `mhspc_model` object. The
prediction functions call it by default, so most users never need to
call it directly.

## Usage

``` r
mhspc_model(path = NULL)
```

## Arguments

- path:

  Path to a model specification file. The default, `NULL`, uses the
  specification installed with the package.

## Value

An object of class `mhspc_model`.

## Examples

``` r
mhspc_model()
#> mHSPC ARPI treatment-effect model (261002-raw-rcs)
#> • Baseline risk: All-cause death within 4 years with ADT alone.
#> • Inputs: ecog_ps, gleason_score, visceral_metastasis, bone_metastases, psa,
#>   hemoglobin, albumin, alp, and ldh.
#> • Treatment effects of ARPI plus ADT: survival difference, restricted mean
#>   survival time difference, and hazard ratio.
```
