# mhspcarpi 0.1.0.9000

* First version: baseline risk, treatment effects across baseline risk, input
  checks, plotting, and a Shiny calculator exportable with Shinylive. Model
  version 260803-raw-rcs.
* `treatment_effect_curve()` returns the pooled effect curves for custom
  figures and tables.
* `example_patients` provides 6 synthetic patients spanning the range of
  baseline risk, and `model_inputs()` gains a `definition` column.
* Calculator: a note for every input on obtaining the value in routine care
  (timing relative to androgen deprivation therapy, conventional imaging versus
  PSMA PET, laboratory methods, and upper caps), notes that close on a click
  outside them, hemoglobin in mmol/L and alkaline phosphatase and lactate
  dehydrogenase in microkatal per liter, the risk of death with an ARPI plus
  ADT shown beside the baseline risk, inputs filled from the query string, and a
  model-specification panel with the coefficients.
* A "Get started" vignette.
* Calculator design: a brand file (`_brand.yml`) following Quarto's default
  HTML look (system sans-serif fonts on a white page) with the JAMA color
  palette, applied through generated CSS variables; the title in white on a
  layered radial gradient, chosen at random on each page load.
* The calculator and the treatment-effect plot describe the comparator as ADT
  alone, for use in practice without placebo; the About panel explains that it
  corresponds to the placebo plus ADT arms of the trials.
* The treatment-effect plot shows baseline risk from 0% to 100%, with the
  curve covering the range observed in the trials.
