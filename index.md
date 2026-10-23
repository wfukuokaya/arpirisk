# arpirisk

Risk-based treatment effects of androgen receptor pathway inhibitors
(ARPIs) in metastatic hormone-sensitive prostate cancer (mHSPC), from
individual participant data of 4706 patients in LATITUDE, ARCHES, TITAN,
and ARASENS.

- **Baseline risk**: the 4-year risk of all-cause death with androgen
  deprivation therapy (ADT) alone, from 9 routinely available patient
  characteristics.
- **Treatment effects** of adding an ARPI to ADT at that risk:
  additional patients alive at 4 years, additional months alive over 4
  years, and the hazard ratio for death, each with a 95% confidence
  interval.

For research and education; not a medical device. The web calculator is
at <https://github.com/wfukuokaya/arpirisk-app>.

## Installation

``` r

pak::pak("wfukuokaya/arpirisk")
```

## Usage

Give a data frame with one row per patient and one column per input (see
[`model_inputs()`](https://wfukuokaya.github.io/arpirisk/reference/model_inputs.md)).
Each function returns the same data frame with its results added as new
columns, so they stay next to each patient.

``` r

library(arpirisk)

patients <- data.frame(
  patient_id = c("A", "B"),
  ecog_ps = c(0, 1), gleason_score = c(9, 9), visceral_metastasis = c(0, 0),
  bone_metastases = c(8, 15), psa = c(45, 150), hemoglobin = c(128, 115),
  albumin = c(41, 38), alp = c(180, 420), ldh = c(210, 280)
)

# 4-year risk of death with ADT alone and with an ARPI plus ADT
risk <- predict_risk(patients)
risk[c("patient_id", "baseline_risk", "arpi_risk")]

# Difference in the proportion alive at 4 years with an ARPI, with 95% CI
effects <- estimate_treatment_effect(patients, scale = "ard")
effects[c("patient_id", "ard", "ard_conf_low", "ard_conf_high")]
```

Risks and absolute risk differences are proportions: an `ard` of 0.16
means 16 more patients alive at 4 years per 100 treated.

See
[`vignette("arpirisk")`](https://wfukuokaya.github.io/arpirisk/articles/arpirisk.md)
for a worked example.

## Citation

Methods and model performance are described in our article:
`citation("arpirisk")`. The article will be added on publication.
