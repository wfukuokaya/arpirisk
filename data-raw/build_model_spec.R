# Build inst/extdata/model_spec.json from the analysis export.
#
# The analysis script writes the aggregate model with
# write_ascii_model_export() (an ASCII RDS file, e.g. model_export.txt). This
# script converts that export into the language-neutral specification read by
# the package. Every coefficient in the export must be assigned to exactly one
# term, so a renamed or missing term stops the build instead of silently
# contributing zero to the linear predictor.
#
# Usage, from the package root:
#   Rscript data-raw/build_model_spec.R ../260906_eu/model_export.txt
# An optional second argument writes the specification elsewhere; the
# synthetic-cohort check (data-raw/synthetic_cohort_check.R) uses it.

args <- commandArgs(trailingOnly = TRUE)
export_path <- if (length(args) >= 1L) args[[1L]] else "../260906_eu/model_export.txt"
spec_path <- if (length(args) >= 2L) args[[2L]] else file.path("inst", "extdata", "model_spec.json")

export <- readRDS(export_path)

# --- Export checks ----------------------------------------------------------

if (!identical(as.integer(export$webapp_schema_version), 3L)) {
  cli::cli_abort("Expected export schema version 3, not {.val {export$webapp_schema_version}}.")
}
if (!identical(export$biomarker_model_mode, "raw_rcs")) {
  cli::cli_abort("Only the raw-scale RCS model is supported, not {.val {export$biomarker_model_mode}}.")
}
if (any(export$predictor_schema$transform != "identity")) {
  cli::cli_abort("All predictors must be entered on the identity scale.")
}
if (!identical(export$final_categ, "NUM_BONE_CAT")) {
  cli::cli_abort("The only supported categorical predictor is {.field NUM_BONE_CAT}.")
}
if (!identical(export$hte_index_strategy, "placebo_adt")) {
  cli::cli_abort("Treatment effects must be indexed on the placebo plus ADT linear predictor.")
}

coefficients <- stats::setNames(export$prog_coefs, export$prog_coef_names)
coefficient_log <- new.env(parent = emptyenv())
coefficient_log$used <- character()
take_coefficients <- function(terms) {
  missing_terms <- setdiff(terms, names(coefficients))
  if (length(missing_terms) > 0L) {
    cli::cli_abort("The export has no coefficient for {.val {missing_terms}}.")
  }
  coefficient_log$used <- c(coefficient_log$used, terms)
  unname(coefficients[terms])
}

schema <- export$predictor_schema
schema_row <- function(source_name) {
  row <- schema[schema$source_name == source_name, , drop = FALSE]
  if (nrow(row) != 1L) {
    cli::cli_abort("The predictor schema has no unique row for {.field {source_name}}.")
  }
  row
}
optional_number <- function(x) if (is.finite(x)) x else NULL

# --- User-facing definitions -----------------------------------------------
# Names, labels, and accepted ranges for each model term. Dichotomization
# thresholds follow the analysis script (ECOG >= 1 and Gleason score >= 9).
# Accepted ranges never exclude a value observed in the development data. PSA
# accepts values up to 100,000 ng/mL because values above the development cap
# are scored at the cap.

# Notes shown behind the "i" button of each input. They address how the value
# is obtained in routine care and how that can differ from the trials.
timing_note <- paste(
  "Enter the most recent value at the time of the treatment decision; values from many",
  "months into androgen deprivation therapy fall outside the trial setting."
)

# Alternative units are converted to the model's unit by multiplication:
# hemoglobin 1 g/dL = 10 g/L and 1 mmol/L = 16.11 g/L; albumin 1 g/dL = 10 g/L;
# enzymes 1 microkatal/L = 60 U/L. `default_unit` is shown first in the app.
# build_continuous() adds the upper cap and the timing note to `help`.
continuous_definitions <- list(
  PSA = list(
    name = "psa", label = "Prostate-specific antigen", short_label = "PSA",
    unit = "ng/mL", allowed_max = 1e5, alternative_units = list(),
    help = paste(
      "Serum PSA in ng/mL, which equals \u00b5g/L. PSA falls quickly once androgen deprivation",
      "therapy starts, so the timing of this test matters more than for the others."
    )
  ),
  HGB = list(
    name = "hemoglobin", label = "Hemoglobin", short_label = "Hemoglobin",
    unit = "g/L", allowed_max = NULL, default_unit = "g/dL",
    alternative_units = list(
      list(unit = "g/dL", multiplier = 10),
      list(unit = "mmol/L", multiplier = 16.11)
    ),
    help = paste(
      "Blood hemoglobin, in the unit your laboratory reports. Avoid a value obtained within a",
      "few weeks after a red cell transfusion, which overstates the patient's usual level."
    )
  ),
  ALB = list(
    name = "albumin", label = "Albumin", short_label = "Albumin",
    unit = "g/L", allowed_max = NULL, default_unit = "g/dL",
    alternative_units = list(list(unit = "g/dL", multiplier = 10)),
    help = paste(
      "Serum albumin, in the unit your laboratory reports. A value measured during an acute",
      "illness or hospital admission may understate the patient's usual level."
    )
  ),
  ALP = list(
    name = "alp", label = "Alkaline phosphatase", short_label = "ALP",
    unit = "U/L", allowed_max = NULL,
    alternative_units = list(list(unit = "\u00b5kat/L", multiplier = 60)),
    help = paste(
      "Total serum alkaline phosphatase in U/L, not bone-specific alkaline phosphatase and not",
      "a multiple of the upper limit of normal. Liver disease also raises the value."
    )
  ),
  LDH = list(
    name = "ldh", label = "Lactate dehydrogenase", short_label = "LDH",
    unit = "U/L", allowed_max = NULL,
    alternative_units = list(list(unit = "\u00b5kat/L", multiplier = 60)),
    help = paste(
      "Serum lactate dehydrogenase in U/L, not a multiple of the upper limit of normal.",
      "A hemolyzed sample gives a falsely high value."
    )
  )
)

# States the upper cap, in the model's unit, for terms winsorized in the analysis.
cap_note <- function(cap, unit) {
  if (is.null(cap)) {
    return(NULL)
  }
  cap_text <- paste(format(round(cap), big.mark = ","), unit)
  paste0("Values above ", cap_text, " are scored as ", cap_text, ".")
}

build_continuous <- function(term) {
  definition <- continuous_definitions[[term]]
  row <- schema_row(term)
  knots <- as.numeric(export$rcs_knots[[term]])
  allowed_max <- definition$allowed_max %||% max(row$input_max, row$development_max)
  if (term %in% export$final_cont_rcs) {
    spline_terms <- c(term, paste0(term, strrep("'", seq_len(length(knots) - 2L))))
    model_part <- list(
      type = "rcs",
      knots = I(knots),
      terms = I(spline_terms),
      coefficients = I(take_coefficients(spline_terms))
    )
  } else {
    model_part <- list(
      type = "linear",
      terms = I(term),
      coefficients = I(take_coefficients(term))
    )
  }
  c(
    list(
      name = definition$name,
      model_term = term,
      label = definition$label,
      short_label = definition$short_label,
      group = "laboratory",
      help = paste(c(definition$help, cap_note(optional_number(row$winsor_upper), definition$unit), timing_note), collapse = " "),
      unit = definition$unit,
      default_unit = definition$default_unit %||% definition$unit,
      alternative_units = definition$alternative_units,
      allowed_range = I(c(row$input_min, allowed_max)),
      development_range = I(c(row$development_min, row$development_max)),
      cap_upper = optional_number(row$winsor_upper)
    ),
    model_part
  )
}

build_bone_metastases <- function() {
  row <- schema_row("NUM_BONE")
  cuts <- as.numeric(export$bone_cuts)
  export_labels <- export$bone_labels
  if (length(export_labels) != length(cuts) + 1L) {
    cli::cli_abort("Bone metastasis labels and cutoffs do not match.")
  }
  codes <- c("0-3", "4-6", "7-10", "11+")
  labels <- c("0\u20133", "4\u20136", "7\u201310", "\u226511")
  expected_cuts <- c(3, 6, 10)
  if (!identical(cuts, expected_cuts)) {
    cli::cli_abort("Expected bone metastasis cutoffs {expected_cuts}, not {cuts}.")
  }
  levels <- purrr::map(seq_along(codes), function(index) {
    term <- if (index == 1L) NULL else paste0("NUM_BONE_CAT=", export_labels[[index]])
    list(
      code = codes[[index]],
      label = labels[[index]],
      max_count = if (index <= length(cuts)) cuts[[index]] else NULL,
      term = term,
      coefficient = if (is.null(term)) 0 else take_coefficients(term)
    )
  })
  list(
    name = "bone_metastases",
    model_term = "NUM_BONE_CAT",
    label = "Number of bone metastases",
    short_label = "Bone metastases",
    group = "clinical",
    help = paste(
      "Number of lesions on the bone scan. The trials staged patients with bone scan and CT or",
      "MRI, so do not count lesions seen only on PSMA PET, which usually shows more. The model",
      "scores 4 groups, 0 to 3, 4 to 6, 7 to 10, and 11 or more, so an exact count above 10 is",
      "not needed; enter 11 or more for a superscan."
    ),
    unit = "count",
    allowed_range = I(c(row$input_min, max(row$input_max, row$development_max))),
    development_range = I(c(row$development_min, row$development_max)),
    type = "categorical",
    levels = levels
  )
}

binary_definitions <- list(
  ECOG = list(
    name = "ecog_ps", label = "ECOG performance status", short_label = "ECOG PS",
    type = "threshold", threshold = 1, allowed_values = I(c(0, 1, 2)),
    choices = list(list(label = "0", value = 0), list(label = "1 or 2", value = 1)),
    help = paste(
      "Eastern Cooperative Oncology Group performance status at the time of the treatment",
      "decision: 0, fully active; 1, restricted in strenuous activity; 2, able to care for",
      "oneself but unable to work. Rate current function, including limits from bone pain.",
      "The model scores 1 and 2 together. The trials did not enroll patients with a status",
      "of 3 or 4."
    )
  ),
  GS = list(
    name = "gleason_score", label = "Gleason score", short_label = "Gleason score",
    type = "threshold", threshold = 9, allowed_values = I(2:10),
    choices = list(list(label = "\u22648", value = 8), list(label = "9 or 10", value = 9)),
    help = paste(
      "Gleason score from the diagnostic biopsy, or from the prostatectomy specimen if the",
      "cancer recurred after surgery. ISUP grade group 5 equals a score of 9 or 10, and grade",
      "groups 1 to 4 equal 8 or lower. The model scores 9 or 10 versus 8 or lower."
    )
  ),
  VIS = list(
    name = "visceral_metastasis", label = "Visceral metastasis",
    short_label = "Visceral metastasis",
    type = "binary", allowed_values = I(c(0, 1)),
    choices = list(list(label = "Absent", value = 0), list(label = "Present", value = 1)),
    help = paste(
      "Metastasis in the lung, liver, or another visceral organ on CT or MRI. Bone and lymph",
      "node metastases do not count, nor do lesions seen only on PSMA PET, because the trials",
      "staged patients with conventional imaging."
    )
  )
)

build_binary <- function(term) {
  definition <- binary_definitions[[term]]
  c(
    list(
      name = definition$name,
      model_term = term,
      label = definition$label,
      short_label = definition$short_label,
      group = "clinical",
      help = definition$help,
      type = definition$type
    ),
    if (identical(definition$type, "threshold")) list(threshold = definition$threshold),
    list(
      allowed_values = definition$allowed_values,
      choices = definition$choices,
      coefficient = take_coefficients(term)
    )
  )
}

unsupported_binary <- setdiff(export$final_bin, names(binary_definitions))
unsupported_continuous <- setdiff(
  c(export$final_cont_rcs, export$final_cont_linear),
  names(continuous_definitions)
)
if (length(c(unsupported_binary, unsupported_continuous)) > 0L) {
  cli::cli_abort("No user-facing definition for {.val {c(unsupported_binary, unsupported_continuous)}}.")
}

# Clinical inputs first, then laboratory values, in the order shown in the app.
predictors <- c(
  purrr::map(intersect(c("ECOG", "GS", "VIS"), export$final_bin), build_binary),
  list(build_bone_metastases()),
  purrr::map(
    intersect(names(continuous_definitions), c(export$final_cont_rcs, export$final_cont_linear)),
    build_continuous
  )
)

arm_coefficient <- take_coefficients("ARM")
unused_terms <- setdiff(names(coefficients), coefficient_log$used)
if (length(unused_terms) > 0L || anyDuplicated(coefficient_log$used) > 0L) {
  cli::cli_abort("Coefficients were not assigned exactly once: {.val {unused_terms}}.")
}

# --- Treatment-effect curves -----------------------------------------------

curve_points <- function(curve) {
  list(
    lp = I(curve$lp),
    estimate = I(curve$est),
    conf_low = I(curve$lcl),
    conf_high = I(curve$ucl),
    pred_low = I(curve$pi_lcl),
    pred_high = I(curve$pi_ucl)
  )
}
curves <- export$treatment_effect_curves
if (!identical(curves$ard$lp, curves$rmst$lp) || !identical(curves$ard$lp, curves$cox$lp)) {
  cli::cli_abort("Treatment-effect curves must share one linear-predictor grid.")
}
if (!isTRUE(all.equal(range(curves$ard$lp), as.numeric(export$lp_grid_range)))) {
  cli::cli_abort("The linear-predictor grid does not match {.field lp_grid_range}.")
}

overall_effect <- function(reference) {
  list(estimate = reference$est, conf_low = reference$lcl, conf_high = reference$ucl)
}

# --- Reference profiles (scored by the analysis code) -----------------------

reference_inputs <- export$reference_profiles$inputs
reference_expected <- export$reference_profiles$expected
reference_profiles <- list(
  inputs = list(
    profile = I(reference_inputs$profile),
    ecog_ps = I(reference_inputs$ECOG),
    gleason_score = I(ifelse(reference_inputs$GS == 1, 9, 8)),
    visceral_metastasis = I(reference_inputs$VIS),
    bone_metastases = I(reference_inputs$NUM_BONE),
    psa = I(reference_inputs$PSA),
    hemoglobin = I(reference_inputs$HGB),
    albumin = I(reference_inputs$ALB),
    alp = I(reference_inputs$ALP),
    ldh = I(reference_inputs$LDH)
  ),
  expected = list(
    linear_predictor = I(reference_expected$linear_predictor_placebo_adt),
    baseline_risk = I(reference_expected$mortality_risk_placebo_adt),
    ard = I(reference_expected$survival_difference),
    rmst = I(reference_expected$rmst_difference_months),
    hr = I(reference_expected$hazard_ratio)
  )
)

# --- Assemble and write -----------------------------------------------------

spec <- list(
  schema_version = 4L,
  meta = list(
    model_version = export$model_version,
    analysis_version = export$analysis_version,
    outcome = export$outcome,
    horizon_years = export$horizon,
    reference_strategy = export$prediction_strategies$placebo_adt$label,
    comparator_strategy = export$prediction_strategies$arpi_adt$label,
    source_file = basename(export_path),
    source_md5 = unname(tools::md5sum(export_path)),
    built = format(Sys.Date())
  ),
  linear_predictor = list(
    center = export$lp_center,
    shrinkage_factor = export$shrinkage_factor,
    arm_coefficient = arm_coefficient
  ),
  baseline_cumulative_hazard = I(as.numeric(export$baseline_hazards)),
  predictors = predictors,
  treatment_effects = list(
    index_strategy = export$hte_index_strategy,
    lp_range = I(as.numeric(export$lp_grid_range)),
    lp_range_definition = "1st to 99th percentile of the placebo plus ADT linear predictor in the development data",
    curves = list(
      ard = curve_points(curves$ard),
      rmst = curve_points(curves$rmst),
      log_hr = curve_points(curves$cox)
    ),
    overall = list(
      ard = overall_effect(export$refs$ard),
      rmst = overall_effect(export$refs$rmst),
      hr = overall_effect(export$refs$hr)
    )
  ),
  verification = list(reference_profiles = reference_profiles)
)

dir.create(dirname(spec_path), recursive = TRUE, showWarnings = FALSE)
jsonlite::write_json(
  spec,
  spec_path,
  auto_unbox = TRUE,
  digits = NA,
  pretty = TRUE,
  null = "null"
)
cli::cli_inform(c(
  v = "Wrote {.file {spec_path}} from {.file {basename(export_path)}}.",
  i = "Model version {.val {export$model_version}}; {length(predictors)} predictors."
))
