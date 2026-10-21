# Synthetic-cohort check of the pipeline from the analysis export to the
# package.
#
# The script simulates 4 trials with a known data-generating model, then runs
# the analysis steps that produce the deployment export with the functions in
# the analysis code (261002_functions.R), unchanged: winsorization, multiple
# imputation, the pooled rms::cph fit, shrunken baseline hazards pooled across
# trials, per-trial spline interaction models pooled with mvmeta, and the
# export writer. The export is converted with data-raw/build_model_spec.R, and
# the golden cases are produced with data-raw/remote_golden_cases.R, as on the
# remote analysis PC. A shared mistake in the export, the specification
# builder, or the package therefore shows up as a difference between the
# package and rms::predict().
#
# Outputs, all synthetic, in tests/testthat/fixtures/synthetic/:
#   model_spec.json   specification built from the synthetic export
#   golden_cases.csv  40 profiles scored by remote_golden_cases.R
#   cohort_cases.csv  300 simulated patients scored with rms::predict()
# tests/testthat/test-synthetic.R compares the package with these files.
#
# Usage, from the package root, with the functions file of the analysis code
# (it is not part of this repository); takes about 1 to 2 minutes:
#   Rscript data-raw/synthetic_cohort_check.R path/to/261002_functions.R

suppressPackageStartupMessages({
  library(rms)
  library(survival)
})

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1L || !file.exists(args[[1L]])) {
  cli::cli_abort("Give the path to the analysis functions file (for example 261002_functions.R).")
}
functions_path <- args[[1L]]
output_dir <- file.path("tests", "testthat", "fixtures", "synthetic")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# Function definitions from the analysis code, without running anything else
# in that file.
analysis <- new.env()
is_function_definition <- function(expression) {
  is.call(expression) && identical(expression[[1L]], as.name("<-")) &&
    is.call(expression[[3L]]) && identical(expression[[3L]][[1L]], as.name("function"))
}
purrr::walk(
  purrr::keep(as.list(parse(functions_path, keep.source = FALSE)), is_function_definition),
  eval,
  envir = analysis
)

# --- Settings that mirror the analysis script ---------------------------------

horizon <- 4
horizon_t <- horizon * 12
nk <- 4L
num_imp <- 5L
shrinkage_factor <- 0.92
bone_cuts <- c(3, 6, 10)
bone_labels <- c("\u22643", "4-6", "7-10", "\u226511")
final_cont_rcs <- c("PSA", "HGB", "ALB", "ALP", "LDH")
final_categ <- "NUM_BONE_CAT"
final_bin <- c("ECOG", "GS", "VIS")
winsor_probs <- c(PSA = 0.999, ALP = 0.999, LDH = 0.999)
trial_levels <- 1:4
trial_list <- c("Trial A", "Trial B", "Trial C", "Trial D")

# --- Simulated cohort -----------------------------------------------------------

set.seed(20261005L)
n_per_trial <- 1200L
n_patients <- n_per_trial * length(trial_levels)

cohort <- tibble::tibble(
  USUBJID = sprintf("SYN%05d", seq_len(n_patients)),
  TRIAL = rep(trial_levels, each = n_per_trial),
  ARM = stats::rbinom(n_patients, 1L, 0.5),
  ECOG = stats::rbinom(n_patients, 1L, 0.35),
  GS = stats::rbinom(n_patients, 1L, 0.55),
  VIS = stats::rbinom(n_patients, 1L, 0.12),
  NUM_BONE = stats::rnbinom(n_patients, size = 1.2, mu = 9),
  PSA = round(stats::rlnorm(n_patients, log(25), 2), 2),
  HGB = round(pmin(pmax(stats::rnorm(n_patients, 130, 15), 60), 185)),
  ALB = round(pmin(pmax(stats::rnorm(n_patients, 41, 4), 22), 55), 1),
  ALP = round(stats::rlnorm(n_patients, log(130), 0.9)),
  LDH = round(stats::rlnorm(n_patients, log(210), 0.35))
) |>
  dplyr::mutate(
    NUM_BONE_CAT = factor(
      as.character(cut(NUM_BONE, breaks = c(-Inf, bone_cuts, Inf), labels = bone_labels)),
      levels = bone_labels
    )
  )

# Known prognostic index (nonlinear in hemoglobin and on the log scale for the
# skewed laboratory values) and a treatment effect that grows with risk.
bone_effect <- c(0, 0.2, 0.35, 0.6)[as.integer(cohort$NUM_BONE_CAT)]
true_prognostic <- with(cohort, {
  0.45 * ECOG + 0.3 * GS + 0.35 * VIS + bone_effect + 0.12 * log(PSA + 1) -
    0.025 * (HGB - 130) + 0.0006 * pmax(115 - HGB, 0)^2 - 0.05 * (ALB - 41) +
    0.3 * log(ALP / 130) + 0.6 * log(LDH / 210)
})
true_prognostic <- true_prognostic - mean(true_prognostic)
true_log_hr <- -0.35 - 0.1 * true_prognostic
weibull_shape <- 1.3
trial_log_scale <- c(-5.55, -5.75, -5.45, -5.65)[cohort$TRIAL]

event_time <- (-log(stats::runif(n_patients)) /
  exp(trial_log_scale + true_prognostic + cohort$ARM * true_log_hr))^(1 / weibull_shape)
censor_time <- pmin(stats::runif(n_patients, 18, 66), stats::rexp(n_patients, 0.003))
cohort <- cohort |>
  dplyr::mutate(
    OS = pmin(event_time, censor_time),
    DEATH = as.integer(event_time <= censor_time)
  )

# Missing laboratory values, completely at random.
data_base <- cohort |>
  dplyr::mutate(
    HGB = replace(HGB, stats::runif(dplyr::n()) < 0.03, NA),
    ALB = replace(ALB, stats::runif(dplyr::n()) < 0.06, NA),
    ALP = replace(ALP, stats::runif(dplyr::n()) < 0.06, NA),
    LDH = replace(LDH, stats::runif(dplyr::n()) < 0.06, NA)
  )

# --- Winsorization and multiple imputation, as in the analysis ------------------

winsor_upper <- analysis$calculate_upper_winsor_limits(data = data_base, probs = winsor_probs)

imputation_columns <- c(
  "TRIAL", "ARM", "ECOG", "GS", "VIS", "NUM_BONE_CAT",
  "PSA", "HGB", "ALB", "ALP", "LDH", "OS", "DEATH"
)
mids_raw <- mice::mice(
  data_base[imputation_columns],
  m = num_imp,
  maxit = 5,
  seed = 20261005L,
  printFlag = FALSE
)
mids_base <- mice::complete(mids_raw, action = "long", include = TRUE) |>
  analysis$apply_upper_winsor_limits(upper_limits = winsor_upper) |>
  mice::as.mids()
data_model <- mice::complete(mids_base, action = 0)
base_completed <- purrr::map(seq_len(num_imp), function(m) {
  mice::complete(mids_base, action = m) |>
    dplyr::mutate(USUBJID = cohort$USUBJID)
})

# --- Pooled prognostic model ------------------------------------------------------

frm_onestage_cph <- analysis$build_survival_formula(
  cont_rcs = final_cont_rcs, categ = final_categ, binary = final_bin, nk = nk, strata_fun = "strat"
)
frm_onestage <- analysis$build_survival_formula(
  cont_rcs = final_cont_rcs, categ = final_categ, binary = final_bin, nk = nk, strata_fun = "strata"
)
fit_pooled <- Hmisc::fit.mult.impute(
  frm_onestage_cph,
  fitter = cph,
  xtrans = mids_base,
  data = data_model,
  pr = FALSE
)

# --- Shrunken linear predictor and baseline hazards, per imputation ---------------

risk_baseline_results <- purrr::map(seq_len(num_imp), function(m) {
  dat_m <- base_completed[[m]]
  model_bundle <- analysis$fit_shrunken_offset_cox(
    data = dat_m,
    formula = frm_onestage,
    shrinkage_factor = shrinkage_factor
  )
  dat_arm0 <- dat_m
  dat_arm0$ARM <- 0L
  lp_shrunk <- shrinkage_factor * stats::predict(
    model_bundle$prognostic_fit,
    newdata = dat_arm0,
    type = "lp",
    reference = "sample"
  )
  hazard_pooled <- analysis$pool_development_baseline_hazard_reml(
    baseline_hazard = model_bundle$baseline_hazard,
    trial_levels = trial_levels,
    horizon_t = horizon_t
  )$cumulative_hazard
  dat_m |>
    dplyr::mutate(
      imp = m,
      lp_shrunk = lp_shrunk,
      baseline_hazard_shrunk = hazard_pooled
    ) |>
    dplyr::select(USUBJID, TRIAL, imp, lp_shrunk, baseline_hazard_shrunk)
})
patient_risk <- purrr::list_rbind(risk_baseline_results)
baseline_shrunk_by_imp <- patient_risk |>
  dplyr::summarize(baseline_hazard_shrunk = dplyr::first(baseline_hazard_shrunk), .by = imp)
patient_risk_pooled <- patient_risk |>
  dplyr::summarize(lp_shrunk = mean(lp_shrunk), .by = c(USUBJID, TRIAL))

# --- Center of the exported linear predictor -----------------------------------------

# survival::coxph() uses 0, not the mean, as the reference value of 0/1 and
# factor columns, so predict(reference = "sample") above is not centered at the
# sample mean, whereas rms::cph() centers at fit_pooled$center. The baseline
# hazards and the effect curves are on the survival scale, so the exported center
# is shifted to put the package's linear predictor on that same scale. Exporting
# fit_pooled$center unchanged (the analysis scripts up to 261002) shifts every
# patient by lp_center_shift and makes the predicted risks too low.
lp_center_rms <- as.numeric(fit_pooled$center)
lp_center_shift <- mean(purrr::map_dbl(seq_len(num_imp), function(m) {
  dat_arm0 <- base_completed[[m]]
  dat_arm0$ARM <- 0L
  lp_rms <- as.numeric(stats::predict(fit_pooled, newdata = dat_arm0, type = "lp"))
  lp_survival <- patient_risk$lp_shrunk[patient_risk$imp == m] / shrinkage_factor
  mean(lp_rms - lp_survival)
}))
lp_center <- lp_center_rms + lp_center_shift

# --- Treatment effects across the linear predictor ---------------------------------

knots_pooled <- stats::quantile(patient_risk_pooled$lp_shrunk, probs = c(0.05, 0.35, 0.65, 0.95))
lp_grid <- seq(
  stats::quantile(patient_risk_pooled$lp_shrunk, 0.01),
  stats::quantile(patient_risk_pooled$lp_shrunk, 0.99),
  length.out = 100
)

stage1_fits <- function(dat) {
  list(
    cox = analysis$extract_arm_coefs(tryCatch(
      survival::coxph(Surv(OS, DEATH) ~ ARM * rcs(lp_shrunk, knots_pooled), data = dat, x = TRUE),
      error = function(error) NULL
    )),
    rmst = analysis$extract_arm_coefs(tryCatch(
      eventglm::rmeanglm(
        Surv(OS, DEATH) ~ ARM * rcs(lp_shrunk, knots_pooled),
        time = horizon_t, link = "identity", model.censoring = "stratified",
        formula.censoring = ~ARM, data = dat
      ),
      error = function(error) NULL
    )),
    ard = analysis$extract_arm_coefs(tryCatch(
      eventglm::cumincglm(
        Surv(OS, DEATH) ~ ARM * rcs(lp_shrunk, knots_pooled),
        time = horizon_t, link = "identity", survival = TRUE, model.censoring = "stratified",
        formula.censoring = ~ARM, data = dat
      ),
      error = function(error) NULL
    ))
  )
}
pooled_per_trial <- purrr::map(trial_levels, function(trial) {
  imputation_fits <- purrr::map(seq_len(num_imp), function(m) {
    analysis$join_patient_risk_scores(
      data = base_completed[[m]],
      risk_scores = patient_risk,
      imputation = m,
      trial = trial
    ) |>
      stage1_fits()
  })
  purrr::map(c("cox", "rmst", "ard"), function(scale) {
    pooled <- analysis$rubins_rules_vector(purrr::map(imputation_fits, scale))
    tibble::tibble(trial = trial, scale = scale, beta = list(pooled$beta), V = list(pooled$V))
  }) |>
    purrr::list_rbind()
}) |>
  purrr::list_rbind()

mv_fits <- purrr::map(rlang::set_names(c("cox", "rmst", "ard")), function(scale) {
  analysis$run_mvmeta(dplyr::filter(pooled_per_trial, .data$scale == .env$scale))
})
treatment_effect_curves <- purrr::map(mv_fits, function(fit) {
  analysis$reconstruct_curve(fit, lp_grid, knots_pooled) |>
    dplyr::select(lp, est, lcl, ucl, pi_lcl, pi_ucl)
})

# Overall effects, pooled across trials with the analysis meta-analysis helper.
overall_effect <- function(fit_trial) {
  per_trial <- purrr::map(trial_levels, function(trial) {
    fit <- fit_trial(dplyr::filter(cohort, .data$TRIAL == .env$trial))
    list(estimate = unname(stats::coef(fit)[["ARM"]]), se = sqrt(stats::vcov(fit)["ARM", "ARM"]))
  })
  analysis$fit_reml_hksj_meta(
    estimate = purrr::map_dbl(per_trial, "estimate"),
    standard_error = purrr::map_dbl(per_trial, "se"),
    study_labels = trial_list
  )
}
ma_hr <- overall_effect(function(dat) survival::coxph(Surv(OS, DEATH) ~ ARM, data = dat))
ma_rmst <- overall_effect(function(dat) {
  eventglm::rmeanglm(Surv(OS, DEATH) ~ ARM, time = horizon_t, link = "identity", data = dat)
})
ma_ard <- overall_effect(function(dat) {
  eventglm::cumincglm(Surv(OS, DEATH) ~ ARM, time = horizon_t, link = "identity", survival = TRUE, data = dat)
})
refs <- list(
  hr = list(est = exp(ma_hr$TE.random), lcl = exp(ma_hr$lower.random), ucl = exp(ma_hr$upper.random)),
  rmst = list(est = ma_rmst$TE.random, lcl = ma_rmst$lower.random, ucl = ma_rmst$upper.random),
  ard = list(est = ma_ard$TE.random, lcl = ma_ard$lower.random, ucl = ma_ard$upper.random)
)

# --- Export, as at the end of the analysis script -----------------------------------

predictor_catalog <- tibble::tribble(
  ~source_name, ~role, ~label, ~unit, ~input_min, ~input_max,
  "NUM_BONE", "categorical", "Number of bone metastases", "count", 0, 1000,
  "PSA", "continuous", "Prostate-specific antigen", "ng/mL", 0, 10000,
  "HGB", "continuous", "Hemoglobin", "g/L", 20, 250,
  "ALB", "continuous", "Albumin", "g/L", 10, 70,
  "ALP", "continuous", "Alkaline phosphatase", "U/L", 0, 10000,
  "LDH", "continuous", "Lactate dehydrogenase", "U/L", 0, 10000,
  "ECOG", "binary", "ECOG performance status", "", 0, 1,
  "GS", "binary", "Gleason score at least 9", "", 0, 1,
  "VIS", "binary", "Visceral metastasis", "", 0, 1
)
selected_model_names <- c(final_cont_rcs, final_categ, final_bin)
predictor_schema <- tibble::tibble(
  source_name = dplyr::if_else(selected_model_names == "NUM_BONE_CAT", "NUM_BONE", selected_model_names),
  model_name = selected_model_names
) |>
  dplyr::left_join(predictor_catalog, by = "source_name")
development_ranges <- purrr::map(predictor_schema$source_name, function(source_name) {
  values <- data_base[[source_name]]
  tibble::tibble(
    source_name = source_name,
    development_min = min(values, na.rm = TRUE),
    development_max = max(values, na.rm = TRUE)
  )
}) |>
  purrr::list_rbind()
predictor_schema <- predictor_schema |>
  dplyr::left_join(development_ranges, by = "source_name") |>
  dplyr::mutate(
    transform = "identity",
    winsor_upper = unname(winsor_upper[.data$source_name]),
    age_floor_step = NA_real_
  ) |>
  dplyr::select(
    source_name, model_name, role, transform, label, unit,
    input_min, input_max, development_min, development_max,
    winsor_upper, age_floor_step
  )

model_export <- list(
  webapp_schema_version = 3L,
  model_version = "synthetic-check",
  analysis_version = "synthetic",
  outcome = "All-cause death",
  horizon = horizon,
  prediction_strategies = list(
    placebo_adt = list(label = "Placebo plus ADT", arm = 0L),
    arpi_adt = list(label = "ARPI plus ADT", arm = 1L)
  ),
  hte_index_strategy = "placebo_adt",
  biomarker_model_mode = "raw_rcs",
  shrinkage_factor = shrinkage_factor,
  baseline_hazards = as.numeric(baseline_shrunk_by_imp$baseline_hazard_shrunk),
  lp_center = lp_center,
  prog_coef_names = names(stats::coef(fit_pooled)),
  prog_coefs = as.numeric(stats::coef(fit_pooled)),
  rcs_knots = analysis$extract_rms_rcs_knots(fit = fit_pooled, variables = final_cont_rcs),
  final_cont_rcs = final_cont_rcs,
  final_cont_linear = character(),
  final_categ = final_categ,
  final_bin = final_bin,
  bone_cuts = bone_cuts,
  bone_labels = bone_labels,
  predictor_schema = predictor_schema,
  lp_grid_range = range(lp_grid),
  treatment_effect_curves = treatment_effect_curves,
  refs = refs,
  var_labels = stats::setNames(predictor_schema$label, predictor_schema$source_name),
  nk = nk
)
reference_profile_inputs <- analysis$build_synthetic_reference_profiles(model_export$predictor_schema)
model_export$reference_profiles <- list(
  inputs = reference_profile_inputs,
  expected = analysis$score_deployment_reference_profiles(reference_profile_inputs, model_export)
)

work_dir <- tempfile("synthetic_check_")
dir.create(work_dir)
export_path <- file.path(work_dir, "model_export.txt")
analysis$write_ascii_model_export(model_export, export_path)

# --- Specification and golden cases, with the same scripts as for the real model ----

spec_path <- file.path(output_dir, "model_spec.json")
status <- system2(
  file.path(R.home("bin"), "Rscript"),
  c(shQuote(file.path("data-raw", "build_model_spec.R")), shQuote(export_path), shQuote(spec_path))
)
if (!identical(status, 0L)) {
  cli::cli_abort("data-raw/build_model_spec.R failed on the synthetic export.")
}

golden_env <- new.env()
golden_env$fit_pooled <- fit_pooled
golden_env$model_export <- readRDS(export_path)
golden_env$mv_fits <- mv_fits
golden_env$knots_pooled <- knots_pooled
golden_env$data_model <- data_model
golden_env$calculate_absolute_mortality_risk <- analysis$calculate_absolute_mortality_risk
golden_env$reconstruct_curve <- analysis$reconstruct_curve
golden_script <- normalizePath(file.path("data-raw", "remote_golden_cases.R"))
withr::with_dir(work_dir, sys.source(golden_script, envir = golden_env))
file.copy(file.path(work_dir, "golden_cases.csv"), file.path(output_dir, "golden_cases.csv"), overwrite = TRUE)

# --- Simulated patients scored with rms -------------------------------------------

# Uncapped values from the first imputation, so that the package's own capping
# is exercised; rms scores the capped values that the model was fitted on.
cohort_sample <- sort(sample.int(n_patients, 300L))
uncapped <- mice::complete(mids_raw, action = 1L)[cohort_sample, ]
capped <- analysis$apply_upper_winsor_limits(uncapped, upper_limits = winsor_upper)
capped$ARM <- 0L
cohort_lp <- shrinkage_factor *
  (as.numeric(stats::predict(fit_pooled, newdata = capped, type = "lp")) + lp_center_rms - lp_center)
cohort_cases <- tibble::tibble(
  ecog_ps = uncapped$ECOG,
  gleason_score = ifelse(uncapped$GS == 1L, 9, 8),
  visceral_metastasis = uncapped$VIS,
  bone_metastases = cohort$NUM_BONE[cohort_sample],
  psa = uncapped$PSA,
  hemoglobin = uncapped$HGB,
  albumin = uncapped$ALB,
  alp = uncapped$ALP,
  ldh = uncapped$LDH,
  linear_predictor = cohort_lp,
  baseline_risk = analysis$calculate_absolute_mortality_risk(
    lp = cohort_lp,
    baseline_hazards = model_export$baseline_hazards
  ),
  true_risk = 1 - exp(-exp(mean(c(-5.55, -5.75, -5.45, -5.65)) + true_prognostic[cohort_sample]) *
    horizon_t^weibull_shape)
)
utils::write.csv(cohort_cases, file.path(output_dir, "cohort_cases.csv"), row.names = FALSE)

# --- Comparison with the package ---------------------------------------------------

pkgload::load_all(".", quiet = TRUE)
model <- mhspc_model(spec_path)
golden <- utils::read.csv(file.path(output_dir, "golden_cases.csv"))
input_names <- model_inputs(model)$name
golden_risk <- suppressWarnings(predict_baseline_risk(golden[input_names], model))
golden_effects <- suppressWarnings(estimate_treatment_effect(golden[input_names], model = model))
cohort_risk <- suppressWarnings(predict_baseline_risk(as.data.frame(cohort_cases[input_names]), model))
placebo_inputs <- mice::complete(mids_raw, action = 1L) |>
  dplyr::mutate(NUM_BONE = cohort$NUM_BONE) |>
  dplyr::filter(ARM == 0L) |>
  dplyr::transmute(
    ecog_ps = ECOG, gleason_score = ifelse(GS == 1L, 9, 8), visceral_metastasis = VIS,
    bone_metastases = NUM_BONE, psa = PSA, hemoglobin = HGB, albumin = ALB, alp = ALP, ldh = LDH
  )
placebo_risk <- suppressWarnings(predict_baseline_risk(as.data.frame(placebo_inputs), model))
effect_difference <- function(scale) {
  max(abs(golden_effects[[scale]] - golden[[paste0(scale, "_estimate")]]))
}

writeLines(c(
  "",
  sprintf("Synthetic cohort: %d patients, %d deaths, %d imputations.", n_patients, sum(cohort$DEATH), num_imp),
  sprintf("Mean 4-year risk with ADT alone in the package: %.3f.", mean(cohort_risk$baseline_risk)),
  "Largest absolute difference between the package and the analysis code:",
  sprintf("  golden profiles, linear predictor:  %.2e", max(abs(golden_risk$linear_predictor - golden$linear_predictor))),
  sprintf("  golden profiles, baseline risk:     %.2e", max(abs(golden_risk$baseline_risk - golden$baseline_risk))),
  sprintf("  golden profiles, ARD:               %.2e", effect_difference("ard")),
  sprintf("  golden profiles, RMST difference:   %.2e", effect_difference("rmst")),
  sprintf("  golden profiles, hazard ratio:      %.2e", effect_difference("hr")),
  sprintf("  cohort patients, linear predictor:  %.2e", max(abs(cohort_risk$linear_predictor - cohort_cases$linear_predictor))),
  sprintf("  cohort patients, baseline risk:     %.2e", max(abs(cohort_risk$baseline_risk - cohort_cases$baseline_risk))),
  sprintf("Center shift between rms and survival, raw scale: %.4f.", lp_center_shift),
  sprintf(
    "4-year risk in the placebo arm: Kaplan-Meier %.3f; mean predicted by the package %.3f.",
    1 - summary(survival::survfit(Surv(OS, DEATH) ~ 1, data = dplyr::filter(cohort, ARM == 0L)), times = horizon_t)$surv,
    mean(placebo_risk$baseline_risk)
  ),
  sprintf(
    "Agreement with the true risk of the data-generating model: correlation %.3f, mean difference %.3f.",
    stats::cor(cohort_risk$baseline_risk, cohort_cases$true_risk),
    mean(cohort_risk$baseline_risk - cohort_cases$true_risk)
  )
))
