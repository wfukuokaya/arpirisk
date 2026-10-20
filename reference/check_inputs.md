# Check patient data before prediction

Checks that `newdata` contains every model input with an accepted value.
Invalid or missing values stop with an error that names the row and
input. Values outside the range observed in the trials, and values above
the upper cap used in model development, are returned as warnings and
notes.

## Usage

``` r
check_inputs(newdata, model = mhspc_model())
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
  `ldh` (U/L). Other columns are ignored.

- model:

  An `mhspc_model` object from
  [`mhspc_model()`](https://wfukuokaya.github.io/arpirisk/reference/mhspc_model.md).

## Value

A data frame of warnings and notes with columns `row`, `input`,
`severity`, and `message`; it has no rows when every value is within the
development range.

## Examples

``` r
patient <- data.frame(
  ecog_ps = 0, gleason_score = 9, visceral_metastasis = 0,
  bone_metastases = 8, psa = 45, hemoglobin = 128, albumin = 41,
  alp = 180, ldh = 210
)
check_inputs(patient)
#> [1] row      input    severity message 
#> <0 rows> (or 0-length row.names)
```
