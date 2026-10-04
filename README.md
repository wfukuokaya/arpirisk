# mhspcarpi

<!-- badges: start -->
[![R-CMD-check](https://github.com/wfukuokaya/mhspcarpi/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/wfukuokaya/mhspcarpi/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

mhspcarpi implements a risk model for patients with metastatic hormone-sensitive prostate cancer (mHSPC) and the treatment effects of androgen receptor pathway inhibitors (ARPIs) across baseline risk. The model was developed from individual participant data of 4706 patients in 4 placebo-controlled randomized clinical trials (LATITUDE, ARCHES, TITAN, and ARASENS).

For each patient, the package estimates:

- the risk of death within 4 years with placebo plus androgen deprivation therapy (ADT), called baseline risk; and
- the pooled effects of an ARPI plus ADT versus placebo plus ADT at that baseline risk: the difference in the probability of being alive at 4 years, the restricted mean survival time difference through 4 years, and the hazard ratio, each with a 95% confidence interval and a 95% prediction interval.

The package also contains the web calculator, which runs entirely in the browser as a static Shinylive site.

For research and education. The calculator is not a medical device.

> **Status: pre-publication.** The model in `inst/extdata/model_spec.json` (version 260803-raw-rcs) is provisional. Its linear-predictor center does not match the scale of its baseline hazards, so its predicted risks are too low; the corrected export from the next analysis run will replace it. Do not use the current estimates.

## Installation

```r
pak::pak("wfukuokaya/mhspcarpi")
```

## Usage

```r
library(mhspcarpi)

patient <- data.frame(
  ecog_ps = 0,              # 0, 1, or 2
  gleason_score = 9,        # 2 to 10
  visceral_metastasis = 0,  # 0 or 1
  bone_metastases = 8,      # count, or "0-3", "4-6", "7-10", "11+"
  psa = 45,                 # ng/mL
  hemoglobin = 128,         # g/L
  albumin = 41,             # g/L
  alp = 180,                # U/L
  ldh = 210                 # U/L
)

predict_baseline_risk(patient)
estimate_treatment_effect(patient)
plot_treatment_effect(patient)
treatment_effect_curve("ard")
run_app()
```

`model_inputs()` lists the inputs, units, accepted values, and definitions. `check_inputs()` reports values outside the range observed in the trials; their estimates are extrapolations. `example_patients` contains 6 synthetic patients spanning the range of baseline risk. See `vignette("mhspcarpi")` for a walkthrough.

## Web calculator

The calculator takes the 9 inputs, with unit switches for laboratory values and a definition behind each input, and shows the baseline risk, the expected outcomes for 100 patients, and the treatment effect across baseline risk. A query string fills the inputs (for example `?psa=45&hemoglobin=128`, in the units listed by `model_inputs()`). The coefficients are shown in the "Model specification" panel.

```sh
Rscript tools/build_shinylive.R _site
```

The command exports the calculator, with WebAssembly builds of its R dependencies, to `_site/` for static hosting. The GitHub Actions workflow in `.github/workflows/deploy-app.yaml` deploys the site to Cloudflare Pages when a release is published or when it is started by hand; it needs the repository secrets `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`.

### Design

The visual identity is defined in `_brand.yml` (brand.yml format: colors, fonts, and links). It follows Quarto's default HTML output, with the system sans-serif font stack on a white page, and uses the JAMA color palette (as in `ggsci::pal_jama()`) for controls, the plot, and the header. `tools/build_theme.R` converts the file into the CSS variables in `R/app_theme.R`, so the app uses bslib's precompiled theme and needs no Sass compilation in the browser. The header shows the title in white on one of four layered radial gradients in the darker JAMA colors (`inst/app/gradients/`), chosen at random on each page load; they were generated with the method described by Justin Jay Wang in "Methods for random gradients" (2024) and inlined by `tools/build_gradients.R`.

## Model specification

The model is stored as aggregate parameters in `inst/extdata/model_spec.json`: risk-model coefficients and spline knots, the 4-year baseline cumulative hazards from the multiply imputed datasets, and the pooled treatment-effect curves. No participant-level data are included.

The specification is generated from the analysis export with `data-raw/build_model_spec.R`. Tests check the package against reference profiles scored by the analysis code and, when available, against golden cases computed with `rms` on the analysis computer (`data-raw/remote_golden_cases.R`). `data-raw/synthetic_cohort_check.R` runs the analysis export code on a simulated cohort; the tests compare the package with `rms` predictions and with the true risks of that simulation.

## Updating the model

The analysis runs on a separate computer with the participant-level data; this repository receives only its aggregate export.

1. After the analysis script finishes, run `data-raw/remote_golden_cases.R` in the same R session. It writes `golden_cases.csv` and stops if the exported linear predictor is not aligned with the baseline hazards and effect curves.
2. Rebuild the specification: `Rscript data-raw/build_model_spec.R path/to/model_export.txt`.
3. Copy `golden_cases.csv` to `tests/testthat/fixtures/` and run the tests.
4. Update the version and `NEWS.md`, then rebuild the calculator.

## Repository layout

| Path | Contents |
|---|---|
| `R/` | Package functions and the Shiny calculator |
| `inst/extdata/model_spec.json` | Model specification (aggregate parameters) |
| `inst/app/gradients/` | Header artwork for the calculator |
| `data-raw/` | Scripts that build the specification, golden cases, the synthetic-cohort check, and `example_patients` |
| `tools/` | Scripts that build the calculator theme, header artwork, and Shinylive site |
| `tests/testthat/` | Tests, with synthetic fixtures in `fixtures/synthetic/` |
| `vignettes/` | "Get started" vignette |
| `_brand.yml` | Visual identity of the calculator |

## Development

```r
testthat::test_local()
lintr::lint_package()
rcmdcheck::rcmdcheck(args = c("--no-manual", "--as-cran"))
```

## Data

No participant-level data are included. The model specification contains aggregate parameters only, and all test fixtures are simulated.

## Citation

`citation("mhspcarpi")` gives the package citation. The article will be added on publication.
