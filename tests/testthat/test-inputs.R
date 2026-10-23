test_that("model_inputs lists every input with its unit and scoring", {
  inputs <- model_inputs()
  expect_s3_class(inputs, "data.frame")
  expect_equal(nrow(inputs), 9L)
  expect_named(inputs, c("name", "label", "unit", "accepted", "scoring", "definition"))
  expect_equal(inputs$unit[inputs$name == "hemoglobin"], "g/L")
  expect_match(inputs$scoring[inputs$name == "psa"], "scored at the cap")
  expect_equal(inputs$scoring[inputs$name == "ecog_ps"], "0 vs 1 or 2")
  expect_false(anyNA(inputs$definition))
  expect_match(inputs$definition[inputs$name == "visceral_metastasis"], "liver")
})

test_that("alternative units convert to the model's units", {
  predictors <- mhspc_model()$predictors
  expect_equal(unit_multiplier(predictors$hemoglobin, "g/dL"), 10)
  expect_equal(unit_multiplier(predictors$hemoglobin, "mmol/L"), 16.11)
  expect_equal(unit_multiplier(predictors$alp, "\u00b5kat/L"), 60)
  expect_equal(unit_multiplier(predictors$ldh, "\u00b5kat/L"), 60)
  expect_equal(unit_multiplier(predictors$psa, "ng/mL"), 1)
  expect_match(
    issue_message("out_of_range", predictors$alp, 10800, unit = "\u00b5kat/L", app = TRUE),
    "If the value is in U/L, select U/L."
  )
})

test_that("valid patients pass with no warnings or messages", {
  expect_no_warning(expect_no_message(predict_risk(example_patient())))
})

test_that("structural problems stop with informative errors", {
  expect_error(predict_risk(list(psa = 1)), class = "arpirisk_input_error")
  expect_error(predict_risk(example_patient()[0, ]), class = "arpirisk_input_error")
  expect_error(
    predict_risk(example_patient()[, -1]),
    "missing required column",
    class = "arpirisk_input_error"
  )
})

test_that("missing and invalid values stop with row-level errors", {
  expect_input_error <- function(..., pattern) {
    expect_error(predict_risk(example_patient(...)), pattern, class = "arpirisk_input_error")
  }
  expect_input_error(psa = NA, pattern = "Prostate-specific antigen is missing")
  expect_input_error(psa = "high", pattern = "must be a number")
  expect_input_error(hemoglobin = 12.8, pattern = "multiply by 10")
  expect_input_error(albumin = 80, pattern = "between 10 and 70 g/L")
  expect_input_error(ecog_ps = 3, pattern = "must be one of 0, 1, 2")
  expect_input_error(ecog_ps = TRUE, pattern = "ECOG performance status")
  expect_input_error(gleason_score = 9.5, pattern = "Gleason score must be one of")
  expect_input_error(visceral_metastasis = "yes", pattern = "Visceral metastasis")
  expect_input_error(visceral_metastasis = 2, pattern = "must be one of 0, 1")
  expect_input_error(bone_metastases = -1, pattern = "whole number")
  expect_input_error(bone_metastases = 2.5, pattern = "whole number")
  expect_input_error(bone_metastases = "12+", pattern = "one of the categories")
  expect_input_error(bone_metastases = NA_character_, pattern = "is missing")
  expect_input_error(bone_metastases = TRUE, pattern = "one of the categories")
})

test_that("only the first 8 errors are listed", {
  patients <- example_patient()[rep(1L, 10L), ]
  patients$psa <- NA
  expect_error(predict_risk(patients), "And 2 more", class = "arpirisk_input_error")
})

test_that("values outside the development range or above the cap are reported by row", {
  issues <- assess_inputs(example_patient(hemoglobin = 50, psa = 9000, bone_metastases = 60), mhspc_model())$issues
  expect_equal(issues$input, c("bone_metastases", "psa", "hemoglobin"))
  expect_equal(issues$severity, c("warning", "note", "warning"))
  expect_match(issues$message[[2L]], "scored as 8,322 ng/mL")
  expect_match(issues$message[[3L]], "outside the range in the trial data \\(57 to 186 g/L\\)")
})

test_that("equivalent encodings give the same linear predictor", {
  lp <- function(...) quietly(predict_risk(example_patient(...)))$linear_predictor
  expect_equal(lp(bone_metastases = "7-10"), lp(bone_metastases = 8))
  expect_equal(lp(bone_metastases = factor("7-10")), lp(bone_metastases = 10))
  expect_equal(lp(bone_metastases = "\u226511"), lp(bone_metastases = 11))
  expect_equal(lp(bone_metastases = 3), lp(bone_metastases = 0))
  expect_false(isTRUE(all.equal(lp(bone_metastases = 4), lp(bone_metastases = 3))))
  expect_equal(lp(visceral_metastasis = TRUE), lp(visceral_metastasis = 1))
  expect_equal(lp(gleason_score = 10), lp(gleason_score = 9))
  expect_equal(lp(gleason_score = 6), lp(gleason_score = 8))
  expect_equal(lp(ecog_ps = 2), lp(ecog_ps = 1))
  expect_equal(lp(psa = 20000), lp(psa = 9000))
})

test_that("issue messages convert to the display unit", {
  hemoglobin <- mhspc_model()$predictors$hemoglobin
  expect_equal(
    issue_message("out_of_range", hemoglobin, 1280, unit = "g/dL", app = TRUE),
    "Hemoglobin must be between 2 and 25 g/dL. If the value is in g/L, select g/L."
  )
  expect_equal(
    issue_message("out_of_range", hemoglobin, 12.8),
    "Hemoglobin must be between 20 and 250 g/L. If it was measured in g/dL, multiply by 10."
  )
  expect_match(issue_message("outside_development", hemoglobin, 50, unit = "g/dL"), "5.7 to 18.6 g/dL")
  expect_equal(unit_hint(hemoglobin, 1e4, "g/L"), "")
  expect_error(unit_multiplier(hemoglobin, "mg/dL"), "Unknown unit")
})
