# arpirisk

<!-- badges: start -->
[![R-CMD-check](https://github.com/wfukuokaya/arpirisk/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/wfukuokaya/arpirisk/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

Risk-based treatment effects of androgen receptor pathway inhibitors (ARPIs) in metastatic hormone-sensitive prostate cancer (mHSPC), from individual participant data of 4706 patients in LATITUDE, ARCHES, TITAN, and ARASENS.

- **Baseline risk**: 4-year risk of all-cause death with placebo plus androgen deprivation therapy (ADT), from a Cox model stratified by trial with 9 predictors (restricted cubic splines for 5 laboratory values) and uniform shrinkage of the linear predictor.
- **Treatment effects** of an ARPI plus ADT versus placebo plus ADT, modeled within each trial as smooth functions of the baseline-risk linear predictor and pooled by multivariate random-effects meta-analysis: the 4-year absolute risk difference (ARD), the restricted mean survival time difference through 4 years (ΔRMST), and the hazard ratio (HR), each with a 95% confidence interval.

For research and education; not a medical device. The web calculator is at <https://github.com/wfukuokaya/arpirisk-app>.

## Installation

```r
pak::pak("wfukuokaya/arpirisk")
```

## Usage

```r
library(arpirisk)

patient <- data.frame(
  ecog_ps = 0, gleason_score = 9, visceral_metastasis = 0, bone_metastases = 8,
  psa = 45, hemoglobin = 128, albumin = 41, alp = 180, ldh = 210
)

predict_baseline_risk(patient)      # linear predictor and 4-year risk
estimate_treatment_effect(patient)  # ARD, ΔRMST, and HR with 95% CI
check_inputs(patient)               # values outside the development data
model_inputs()                      # inputs, units, accepted values, scoring
```

See `vignette("arpirisk")`.

## Model

The model (version 261002-raw-rcs) is stored as aggregate parameters in `inst/extdata/model_spec.json`, built from the analysis export by `data-raw/build_model_spec.R`. Tests compare the package against reference profiles and a simulated cohort scored by the analysis code.

## Citation

`citation("arpirisk")`. The article will be added on publication.
