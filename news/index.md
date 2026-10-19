# Changelog

## mhspcarpi (development version)

- Web calculator: a loading message replaces Shinylive’s faint loading
  indicator, which looked like a blank page on phones during the first
  visit.
- Calculator: the treatment-effect plot keeps a 4:3 shape as the window
  resizes, between 320 and 560 pixels tall, instead of a fixed 300
  pixels.
- Calculator: the hazard ratio for death, with its 95% CI, is shown
  beside the absolute treatment effects; the 2 risks and the 3 treatment
  effects now take one row each.
- Plot labels have a thin white outline instead of a white box, and the
  “This patient” label is placed above or below the curve, whichever
  keeps it closer to the marker without crossing the curve.

## mhspcarpi 0.1.0

- Model version 261002-raw-rcs replaces 260803-raw-rcs. Its
  linear-predictor center matches the baseline hazards, which raises
  predicted risks; the example patient in the tests moves from 53% to
  62%.
- First version: baseline risk, treatment effects across baseline risk,
  input checks, plotting, and a Shiny calculator exportable with
  Shinylive. Model version 260803-raw-rcs.
- A synthetic-cohort check (`data-raw/synthetic_cohort_check.R`) runs
  the analysis export code on simulated trials; the package reproduces
  `rms` predictions to 1e-9. It showed that the exported
  linear-predictor center must match
  [`survival::coxph()`](https://rdrr.io/pkg/survival/man/coxph.html),
  which uses 0 as the reference for 0/1 and factor columns. With the
  `rms` center, predicted risks were too low (34% versus 45% observed in
  the simulation). The model specification built from the 260803 export
  has this problem; it is fixed in 261002_script.R and checked by
  `data-raw/remote_golden_cases.R`.
- [`treatment_effect_curve()`](https://wfukuokaya.github.io/mhspcarpi/reference/treatment_effect_curve.md)
  returns the pooled effect curves for custom figures and tables.
- `example_patients` provides 6 synthetic patients spanning the range of
  baseline risk, and
  [`model_inputs()`](https://wfukuokaya.github.io/mhspcarpi/reference/model_inputs.md)
  gains a `definition` column.
- Calculator: a note for every input on obtaining the value in routine
  care (timing relative to androgen deprivation therapy, conventional
  imaging versus PSMA PET, laboratory methods, and upper caps), notes
  that close on a click outside them, hemoglobin in mmol/L and alkaline
  phosphatase and lactate dehydrogenase in microkatal per liter, the
  risk of death with an ARPI plus ADT shown beside the baseline risk,
  inputs filled from the query string, and a model-specification panel
  with the coefficients.
- A “Get started” vignette.
- Calculator design: a brand file (`_brand.yml`) following Quarto’s
  default HTML look (system sans-serif fonts on a white page) with the
  JAMA color palette, applied through generated CSS variables; the title
  in white on a layered radial gradient, chosen at random on each page
  load.
- The calculator and the treatment-effect plot describe the comparator
  as ADT alone, for use in practice without placebo; the About panel
  explains that it corresponds to the placebo plus ADT arms of the
  trials.
- The treatment-effect plot shows baseline risk from 0% to 100%, with
  the curve covering the range observed in the trials.
