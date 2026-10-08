# Describe the model inputs

Lists the patient characteristics the model requires, with the column
name expected in `newdata`, the unit, the accepted values, the range
observed in the development data, and a definition of what to enter.

## Usage

``` r
model_inputs(model = mhspc_model())
```

## Arguments

- model:

  An `mhspc_model` object from
  [`mhspc_model()`](https://wfukuokaya.github.io/mhspcarpi/reference/mhspc_model.md).

## Value

A data frame with one row per input and columns `name`, `label`, `unit`,
`accepted`, `scoring`, and `definition`.

## Examples

``` r
model_inputs()
#>                  name                     label  unit
#> 1             ecog_ps   ECOG performance status  <NA>
#> 2       gleason_score             Gleason score  <NA>
#> 3 visceral_metastasis       Visceral metastasis  <NA>
#> 4     bone_metastases Number of bone metastases count
#> 5                 psa Prostate-specific antigen ng/mL
#> 6          hemoglobin                Hemoglobin   g/L
#> 7             albumin                   Albumin   g/L
#> 8                 alp      Alkaline phosphatase   U/L
#> 9                 ldh     Lactate dehydrogenase   U/L
#>                                              accepted
#> 1                                             0, 1, 2
#> 2                          2, 3, 4, 5, 6, 7, 8, 9, 10
#> 3                                                0, 1
#> 4 Count, or category code "0-3", "4-6", "7-10", "11+"
#> 5                                        0 to 100,000
#> 6                                           20 to 250
#> 7                                            10 to 70
#> 8                                         0 to 10,000
#> 9                                         0 to 10,000
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
#>                                                                                                                                                                                                                                                                                                                                                                           definition
#> 1                          Eastern Cooperative Oncology Group performance status at the time of the treatment decision: 0, fully active; 1, restricted in strenuous activity; 2, able to care for oneself but unable to work. Rate current function, including limits from bone pain. The model scores 1 and 2 together. The trials did not enroll patients with a status of 3 or 4.
#> 2                                                                                                                             Gleason score from the diagnostic biopsy, or from the prostatectomy specimen if the cancer recurred after surgery. ISUP grade group 5 equals a score of 9 or 10, and grade groups 1 to 4 equal 8 or lower. The model scores 9 or 10 versus 8 or lower.
#> 3                                                                                                                                                            Metastasis in the lung, liver, or another visceral organ on CT or MRI. Bone and lymph node metastases do not count, nor do lesions seen only on PSMA PET, because the trials staged patients with conventional imaging.
#> 4                                                              Number of lesions on the bone scan. The trials staged patients with bone scan and CT or MRI, so do not count lesions seen only on PSMA PET, which usually shows more. The model scores 4 groups, 0 to 3, 4 to 6, 7 to 10, and 11 or more, so an exact count above 10 is not needed; enter 11 or more for a superscan.
#> 5   Serum PSA in ng/mL, which equals µg/L. PSA falls quickly once androgen deprivation therapy starts, so the timing of this test matters more than for the others. Values above 8,322 ng/mL are scored as 8,322 ng/mL. Enter the most recent value at the time of the treatment decision; values from many months into androgen deprivation therapy fall outside the trial setting.
#> 6                                            Blood hemoglobin, in the unit your laboratory reports. Avoid a value obtained within a few weeks after a red cell transfusion, which overstates the patient's usual level. Enter the most recent value at the time of the treatment decision; values from many months into androgen deprivation therapy fall outside the trial setting.
#> 7                                                          Serum albumin, in the unit your laboratory reports. A value measured during an acute illness or hospital admission may understate the patient's usual level. Enter the most recent value at the time of the treatment decision; values from many months into androgen deprivation therapy fall outside the trial setting.
#> 8 Total serum alkaline phosphatase in U/L, not bone-specific alkaline phosphatase and not a multiple of the upper limit of normal. Liver disease also raises the value. Values above 4,824 U/L are scored as 4,824 U/L. Enter the most recent value at the time of the treatment decision; values from many months into androgen deprivation therapy fall outside the trial setting.
#> 9                                       Serum lactate dehydrogenase in U/L, not a multiple of the upper limit of normal. A hemolyzed sample gives a falsely high value. Values above 1,470 U/L are scored as 1,470 U/L. Enter the most recent value at the time of the treatment decision; values from many months into androgen deprivation therapy fall outside the trial setting.
```
