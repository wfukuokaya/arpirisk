# Run the calculator

`run_app()` launches the interactive calculator locally. `mhspc_app()`
returns the app object without running it, for deployment, for example
as a static Shinylive site.

## Usage

``` r
run_app(model = mhspc_model(), ...)

mhspc_app(model = mhspc_model())
```

## Arguments

- model:

  An `mhspc_model` object from
  [`mhspc_model()`](https://wfukuokaya.github.io/mhspcarpi/reference/mhspc_model.md).

- ...:

  Passed to
  [`shiny::runApp()`](https://rdrr.io/pkg/shiny/man/runApp.html).

## Value

`run_app()` is called for its side effect. `mhspc_app()` returns a Shiny
app object.

## Details

The calculator can be opened with the patient's values in the query
string, using the column names and units listed by
[`model_inputs()`](https://wfukuokaya.github.io/mhspcarpi/reference/model_inputs.md),
for example `?psa=45&hemoglobin=128`. The "Copy link" button creates
such a link.

## Examples

``` r
if (FALSE) { # interactive()
run_app()
}
```
