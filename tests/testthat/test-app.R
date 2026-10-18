skip_if_not_installed("shiny")
skip_if_not_installed("bslib")

test_that("mhspc_app builds a Shiny app with every input", {
  model <- mhspc_model()
  expect_s3_class(mhspc_app(model), "shiny.appobj")
  html <- as.character(app_ui(model))
  purrr::walk(names(model$predictors), function(name) {
    expect_match(html, paste0("id=\"", name, "\""), fixed = TRUE)
  })
  expect_match(html, "hemoglobin_unit", fixed = TRUE)
  expect_match(html, "Model 261002-raw-rcs", fixed = TRUE)
  expect_equal(lengths(regmatches(html, gregexpr("class=\"help-button\"", html))), 9L)
  expect_match(html, "mmol/L", fixed = TRUE)
  expect_match(html, "kat/L", fixed = TRUE)
  expect_false(grepl("window.print()", html, fixed = TRUE))
  expect_false(grepl("Copy link", html, fixed = TRUE))
  expect_false(grepl("Copy summary", html, fixed = TRUE))
  expect_match(html, "Model specification", fixed = TRUE)
  expect_match(html, "Shrinkage factor 0.9692", fixed = TRUE)
  expect_match(html, "class=\"header-art\"", fixed = TRUE)
  expect_match(app_theme_css(), "--font-display:", fixed = TRUE)
  expect_match(app_css(), "var(--font-display)", fixed = TRUE)
  expect_match(app_css(), ".app-title {", fixed = TRUE)
  expect_match(app_css(), "color: #ffffff;\n}", fixed = TRUE)
  expect_match(app_css(), ".header-art::after", fixed = TRUE)
  expect_false(grepl("Details for this patient", html, fixed = TRUE))
  expect_match(html, "Risk of death within 4 years with an ARPI plus ADT", fixed = TRUE)
  expect_match(html, "Hazard ratio for death with an ARPI", fixed = TRUE)
  expect_true(is.function(mhspc_app(model)$httpHandler))
  expect_equal(display_units(model$predictors$hemoglobin), c("g/dL", "g/L", "mmol/L"))
  expect_equal(display_units(model$predictors$alp), c("U/L", "\u00b5kat/L"))
})

test_that("the server shows the risk with an ARPI plus ADT below the baseline risk", {
  model <- mhspc_model()
  shiny::testServer(app_server(model), {
    session$setInputs(
      ecog_ps = "1", gleason_score = "9", visceral_metastasis = "1",
      bone_metastases = "11+", psa = 45, hemoglobin = 12.8, albumin = 4.1,
      alp = 180, ldh = 210
    )
    expect_match(output$arpi_risk_value, "^[0-9]+%$")
    expect_lt(as.numeric(sub("%", "", output$arpi_risk_value)), as.numeric(sub("%", "", output$risk_value)))
  })
})

test_that("query strings fill the inputs in the model's units", {
  predictors <- mhspc_model()$predictors
  query <- list(
    ecog_ps = "2", gleason_score = "7", visceral_metastasis = "1",
    bone_metastases = "12", psa = "45", hemoglobin = "128", albumin = "abc",
    alp = "", other = "1"
  )
  values <- query_values(query, predictors)
  expect_equal(
    values,
    list(
      ecog_ps = "1", gleason_score = "8", visceral_metastasis = "1",
      bone_metastases = "11+", psa = 45, hemoglobin = 128
    )
  )
  expect_equal(query_values(list(bone_metastases = "4-6"), predictors), list(bone_metastases = "4-6"))
  expect_length(query_values(list(bone_metastases = "2.5", ecog_ps = "3"), predictors), 0L)
  expect_length(query_values(list(), predictors), 0L)
})

test_that("the server matches the package functions for a complete patient", {
  model <- mhspc_model()
  expected_risk <- predict_baseline_risk(example_patient(), model)
  expected_effects <- estimate_treatment_effect(example_patient(), model = model)

  shiny::testServer(app_server(model), {
    session$setInputs(
      ecog_ps = "0", gleason_score = "9", visceral_metastasis = "0",
      bone_metastases = "7-10", psa = 45, hemoglobin = 12.8, albumin = 4.1,
      alp = 180, ldh = 210, effect_scale = "ard"
    )
    expect_equal(estimates()$risk, expected_risk$baseline_risk)
    expect_equal(estimates()$effects$ard$estimate, expected_effects$estimate[[1L]])
    expect_equal(output$risk_value, "62%")
    expect_match(output$ard_value$html, "^16\\s*<span class=\"value-unit\">per 100</span>")
    expect_match(output$ard_detail, "^95% CI, ")
    expect_match(output$rmst_value$html, "months</span>", fixed = TRUE)
    expect_equal(output$hr_value, format_number(expected_effects$estimate[[3L]], 2))
    expect_match(output$hr_detail, "^95% CI, 0\\.[0-9]{2} to 0\\.[0-9]{2}$")
    expect_match(output$icon_array$html, "icon additional", fixed = TRUE)
    expect_match(output$effect_readout$html, "This patient (baseline risk 62%)", fixed = TRUE)
    expect_null(output$result_notes)

    session$setInputs(effect_hover = list(x = 30))
    expect_match(output$effect_readout$html, "At a baseline risk of 30%", fixed = TRUE)
    session$setInputs(effect_hover = NULL, effect_click = list(x = 70), effect_scale = "hr")
    expect_match(output$effect_readout$html, "This patient", fixed = TRUE)
    session$setInputs(effect_click = list(x = 70))
    expect_match(output$effect_readout$html, "Hazard ratio for death", fixed = TRUE)
  })
})

test_that("switching units keeps the value used for scoring", {
  model <- mhspc_model()
  shiny::testServer(app_server(model), {
    session$setInputs(hemoglobin = 12.8)
    expect_equal(base_values$hemoglobin, 128)
    session$setInputs(hemoglobin_unit = "g/L")
    expect_equal(base_values$hemoglobin, 128)
    session$setInputs(hemoglobin = 130)
    expect_equal(base_values$hemoglobin, 130)
    session$setInputs(hemoglobin_unit = "mmol/L", hemoglobin = 8)
    expect_equal(base_values$hemoglobin, 128.88)
    session$setInputs(alp_unit = "\u00b5kat/L", alp = 3)
    expect_equal(base_values$alp, 180)
  })
})

test_that("incomplete or invalid inputs show progress and field feedback", {
  model <- mhspc_model()
  shiny::testServer(app_server(model), {
    session$setInputs(ecog_ps = "0", hemoglobin = 128)
    expect_null(estimates())
    expect_match(output$input_progress$html, "2 of 9 entered", fixed = TRUE)
    expect_match(output$input_progress$html, "Check the values marked in red", fixed = TRUE)
    expect_match(output$hemoglobin_feedback$html, "If the value is in g/L, select g/L.", fixed = TRUE)
  })
})

test_that("warnings and the effect-range note are shown with the results", {
  model <- mhspc_model()
  shiny::testServer(app_server(model), {
    session$setInputs(
      ecog_ps = "0", gleason_score = "8", visceral_metastasis = "0",
      bone_metastases = "0-3", psa = 9000, hemoglobin = 19, albumin = 4.6,
      alp = 70, ldh = 160
    )
    expect_false(estimates()$in_range)
    notes <- output$result_notes$html
    expect_match(notes, "scored as 8,322 ng/mL", fixed = TRUE)
    expect_match(notes, "18.6 g/dL", fixed = TRUE)
    expect_match(notes, "nearest edge", fixed = TRUE)
  })
})

test_that("the example, clear, and page-location actions run without errors", {
  model <- mhspc_model()
  shiny::testServer(app_server(model), {
    expect_no_error(session$setInputs(use_example = 1))
    expect_no_error(session$setInputs(use_example_main = 1))
    expect_no_error(session$setInputs(clear_inputs = 1))
    expect_no_error(
      session$setInputs(page_location = list(base = "https://example.org/", search = "?psa=45&alp=3"))
    )
  })
})

test_that("the icon array always shows 100 patients", {
  count_icons <- function(risk, estimate) {
    ard <- data.frame(estimate = estimate, conf_low = estimate - 0.05, conf_high = estimate + 0.05)
    html <- as.character(icon_array_ui(risk, ard))
    lengths(regmatches(html, gregexpr("class=\"icon (alive|additional|died)\"", html)))
  }
  expect_equal(count_icons(0.53, 0.16), 100L)
  expect_equal(count_icons(0.2, -0.01), 100L)
  expect_match(
    as.character(icon_array_ui(0.2, data.frame(estimate = -0.01, conf_low = -0.1, conf_high = 0.09))),
    "not expected to change"
  )
  expect_equal(count_icons(0.99, 0.2), 100L)
})

test_that("number formatting uses a minus sign and bounded percentages", {
  expect_equal(format_number(-1.24, 1), "\u22121.2")
  expect_equal(format_number(-0.04, 1), "0.0")
  expect_equal(format_number(12345), "12,345")
  expect_equal(format_percent(c(0.001, 0.5, 0.9999)), c("<1%", "50%", ">99%"))
  expect_equal(format_interval(1, 2), "95% CI, 1 to 2")
  expect_equal(
    describe_effect(data.frame(estimate = 0.6, conf_low = 0.5, conf_high = 0.7), "hr"),
    "Hazard ratio for death, 0.60 (95% CI, 0.50 to 0.70)"
  )
})

test_that("the header art is one of the bundled gradients", {
  expect_gte(length(header_gradients), 2L)
  expect_true(all(startsWith(header_gradients, "<svg ")))
  expect_true(all(grepl("preserveAspectRatio=\"xMidYMid slice\"", header_gradients, fixed = TRUE)))
  expect_false(any(grepl("<metadata>", header_gradients, fixed = TRUE)))
  html <- as.character(header_art(header_gradients))
  expect_match(html, "<div class=\"header-art\" aria-hidden=\"true\"><svg ", fixed = TRUE)
  expect_match(as.character(header_art("<svg one>")), "<svg one>", fixed = TRUE)
})

test_that("help notes close when the user clicks outside them", {
  js <- app_js()
  expect_match(js, "document.addEventListener('click'", fixed = TRUE)
  expect_match(js, "popover.bsPopover.hide()", fixed = TRUE)
})

test_that("help notes state the caps of winsorized laboratory values", {
  predictors <- mhspc_model()$predictors
  helps <- stats::setNames(purrr::map_chr(predictors, "help"), purrr::map_chr(predictors, "name"))
  expect_match(helps[["psa"]], "Values above 8,322 ng/mL are scored as 8,322 ng/mL.", fixed = TRUE)
  expect_false(grepl("Values above", helps[["hemoglobin"]], fixed = TRUE))
  expect_match(helps[["bone_metastases"]], "PSMA PET", fixed = TRUE)
})

test_that("the hover readout has a fixed height so the chart does not move", {
  html <- as.character(app_ui(mhspc_model()))
  expect_match(html, "<div class=\"readout-frame\">", fixed = TRUE)
  css <- app_css()
  expect_match(css, "#effect_readout { display: block; height: 5.3rem; overflow: hidden; }", fixed = TRUE)
  expect_match(css, "@container (min-width: 400px) { #effect_readout { height: 2.7rem; } }", fixed = TRUE)
})
