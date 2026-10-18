#' Run the calculator
#'
#' `run_app()` launches the interactive calculator locally. `mhspc_app()`
#' returns the app object without running it, for deployment, for example as a
#' static Shinylive site.
#'
#' The calculator can be opened with the patient's values in the query string,
#' using the column names and units listed by [model_inputs()], for example
#' `?psa=45&hemoglobin=128`. The "Copy link" button creates such a link.
#'
#' @inheritParams model_inputs
#' @param ... Passed to [shiny::runApp()].
#'
#' @return `run_app()` is called for its side effect. `mhspc_app()` returns a
#'   Shiny app object.
#' @examplesIf interactive()
#' run_app()
#' @export
run_app <- function(model = mhspc_model(), ...) {
  shiny::runApp(mhspc_app(model), ...)
}

#' @rdname run_app
#' @export
mhspc_app <- function(model = mhspc_model()) {
  rlang::check_installed(c("shiny", "bslib"), reason = "to run the calculator.")
  check_model(model)
  # The UI is built per page load so that each visitor gets a random header.
  shiny::shinyApp(ui = function(request) app_ui(model), server = app_server(model))
}

# --- UI ----------------------------------------------------------------------

app_ui <- function(model) {
  predictors <- model$predictors
  groups <- purrr::map_chr(predictors, "group")
  bslib::page_sidebar(
    title = shiny::tagList(
      header_art(),
      shiny::tags$div(
        class = "app-title",
        shiny::tags$div(
          class = "app-title-text",
          shiny::tags$span(class = "app-title-main", "ARPI treatment effect calculator"),
          shiny::tags$span(class = "app-title-sub", "Metastatic hormone-sensitive prostate cancer")
        ),
        shiny::tags$span(
          class = "app-title-meta",
          "4-year risk of death with ADT, with or without an ARPI, from 4 randomized clinical trials"
        )
      )
    ),
    window_title = "ARPI treatment effect calculator for mHSPC",
    theme = bslib::bs_theme(version = 5, preset = "shiny"),
    fillable = FALSE,
    lang = "en",
    sidebar = bslib::sidebar(
      width = 340,
      open = list(desktop = "always", mobile = "always"),
      shiny::tags$div(
        class = "sidebar-heading",
        shiny::tags$h2("Patient characteristics"),
        shiny::tags$div(
          class = "sidebar-actions",
          shiny::actionLink("use_example", "Fill example patient"),
          shiny::actionLink("clear_inputs", "Clear all")
        )
      ),
      input_group_ui("Clinical", predictors[groups == "clinical"]),
      input_group_ui("Laboratory", predictors[groups == "laboratory"])
    ),
    shiny::tags$head(
      shiny::tags$style(shiny::HTML(app_theme_css())),
      shiny::tags$style(shiny::HTML(app_css())),
      shiny::tags$script(shiny::HTML(app_js()))
    ),
    results_ui(model),
    about_ui(model),
    shiny::tags$footer(
      class = "app-footer",
      shiny::tags$span(paste0("Model ", model$meta$model_version)),
      shiny::tags$span("For research and education; not for use as a medical device."),
      shiny::tags$span("Entered values are not stored. The web version runs entirely in your browser.")
    )
  )
}

# One of the layered radial gradients in R/app_gradients.R, chosen at random,
# drawn behind the title.
header_art <- function(gradients = header_gradients) {
  shiny::tags$div(class = "header-art", `aria-hidden` = "true", shiny::HTML(sample(gradients, 1L)))
}

input_group_ui <- function(title, predictors) {
  shiny::tags$fieldset(
    class = "input-block",
    shiny::tags$legend(title),
    purrr::map(unname(predictors), predictor_input_ui)
  )
}

predictor_input_ui <- function(predictor) {
  if (predictor$type %in% c("rcs", "linear")) {
    numeric_input_ui(predictor)
  } else {
    choice_input_ui(predictor)
  }
}

# The unit shown first is the default; the model's unit follows, then the
# other alternatives.
display_units <- function(predictor) {
  alternatives <- purrr::map_chr(predictor$alternative_units %||% list(), "unit")
  unique(c(predictor$default_unit %||% predictor$unit, predictor$unit, alternatives))
}

field_label <- function(predictor, text = predictor$label) {
  shiny::tags$span(class = "field-label", text, help_button(predictor))
}

# A small "i" button that opens the definition of the input.
help_button <- function(predictor) {
  if (is.null(predictor$help)) {
    return(NULL)
  }
  bslib::popover(
    shiny::tags$button(
      type = "button",
      class = "help-button",
      `aria-label` = paste("About", predictor$label),
      "i"
    ),
    predictor$help,
    title = predictor$label
  )
}

numeric_input_ui <- function(predictor) {
  units <- display_units(predictor)
  text <- if (length(units) > 1L) predictor$label else paste0(predictor$label, ", ", predictor$unit)
  shiny::tags$div(
    class = "field",
    shiny::tags$div(
      class = "field-row",
      shiny::numericInput(predictor$name, field_label(predictor, text), value = "", min = 0),
      if (length(units) > 1L) {
        shiny::tags$div(
          class = "segmented unit-switch",
          shiny::radioButtons(
            paste0(predictor$name, "_unit"),
            label = shiny::tags$span(class = "visually-hidden", paste(predictor$label, "unit")),
            choices = units,
            selected = units[[1L]],
            inline = TRUE
          )
        )
      }
    ),
    shiny::uiOutput(paste0(predictor$name, "_feedback"), class = "field-feedback")
  )
}

choice_input_ui <- function(predictor) {
  choices <- if (predictor$type == "categorical") {
    rlang::set_names(
      purrr::map_chr(predictor$levels, "code"),
      purrr::map_chr(predictor$levels, "label")
    )
  } else {
    rlang::set_names(
      purrr::map_chr(predictor$choices, function(choice) format_value(choice$value)),
      purrr::map_chr(predictor$choices, "label")
    )
  }
  shiny::tags$div(
    class = "field segmented",
    shiny::radioButtons(
      predictor$name,
      label = field_label(predictor),
      choices = choices,
      selected = character(0),
      inline = TRUE
    )
  )
}

results_ui <- function(model) {
  risk_range <- format_percent(effect_risk_range(model))
  scale_choices <- c("Alive at 4 years" = "ard", "Time alive" = "rmst", "Hazard ratio" = "hr")
  shiny::tagList(
    shiny::conditionalPanel(
      "!output.has_estimates",
      bslib::card(
        class = "empty-state",
        bslib::card_body(
          shiny::tags$h2("Enter the patient's characteristics"),
          shiny::tags$p(
            "Estimates appear here when all 9 characteristics are entered.",
            "All inputs are required; the model does not impute missing values.",
            "Select the \"i\" next to an input for its definition."
          ),
          shiny::uiOutput("input_progress"),
          shiny::actionButton("use_example_main", "Use an example patient", class = "btn-outline-primary")
        )
      )
    ),
    shiny::conditionalPanel(
      "output.has_estimates",
      shiny::tags$div(
        class = "results-header",
        shiny::tags$p(
          class = "comparison-note",
          "Estimates for an ARPI plus ADT compared with ADT alone"
        )
      ),
      shiny::uiOutput("result_notes"),
      bslib::layout_column_wrap(
        width = "150px",
        fill = FALSE,
        heights_equal = "row",
        class = "value-boxes",
        bslib::value_box(
          title = "Risk of death within 4 years with ADT alone",
          value = shiny::textOutput("risk_value", inline = TRUE)
        ),
        bslib::value_box(
          title = "Risk of death within 4 years with an ARPI plus ADT",
          value = shiny::textOutput("arpi_risk_value", inline = TRUE)
        ),
        bslib::value_box(
          title = "Additional patients alive at 4 years with an ARPI",
          value = shiny::uiOutput("ard_value", inline = TRUE),
          shiny::tags$p(class = "value-box-detail", shiny::textOutput("ard_detail", inline = TRUE))
        ),
        bslib::value_box(
          title = "Additional time alive over 4 years with an ARPI",
          value = shiny::uiOutput("rmst_value", inline = TRUE),
          shiny::tags$p(class = "value-box-detail", shiny::textOutput("rmst_detail", inline = TRUE))
        )
      ),
      bslib::layout_column_wrap(
        width = "360px",
        fill = FALSE,
        heights_equal = "row",
        bslib::card(
          bslib::card_header("Expected outcomes for 100 patients like this"),
          bslib::card_body(shiny::uiOutput("icon_array"))
        ),
        bslib::card(
          bslib::card_header(
            class = "chart-header",
            shiny::tags$span("Treatment effect across baseline risk"),
            shiny::tags$div(
              class = "segmented scale-switch",
              shiny::radioButtons(
                "effect_scale",
                label = shiny::tags$span(class = "visually-hidden", "Effect shown"),
                choices = scale_choices,
                selected = "ard",
                inline = TRUE
              )
            )
          ),
          bslib::card_body(
            shiny::plotOutput(
              "effect_plot",
              height = "auto",
              hover = shiny::hoverOpts("effect_hover", delay = 80, delayType = "throttle"),
              click = "effect_click"
            ),
            shiny::tags$div(class = "readout-frame", shiny::uiOutput("effect_readout")),
            shiny::tags$p(
              class = "chart-caption",
              "Line, pooled estimate across the 4 trials; shaded band, 95% CI;",
              "gray line, average effect in all trial patients. The curve covers",
              paste0("baseline risks from ", risk_range[[1L]], " to ", risk_range[[2L]], ","),
              "the range observed in the trials. Hover over or tap the chart to read values."
            )
          )
        )
      )
    )
  )
}

about_ui <- function(model) {
  risk_range <- format_percent(effect_risk_range(model))
  bslib::accordion(
    class = "about",
    open = FALSE,
    multiple = TRUE,
    bslib::accordion_panel(
      "About this calculator",
      value = "about",
      shiny::tags$h3("What it estimates"),
      shiny::tags$p(
        "For a patient with metastatic hormone-sensitive prostate cancer (mHSPC), the",
        "calculator estimates the risk of death within 4 years with androgen deprivation",
        "therapy (ADT) alone, called baseline risk, and with an androgen receptor pathway",
        "inhibitor (ARPI) plus ADT. It also shows how the effect of adding an ARPI on",
        "overall survival changes with baseline risk."
      ),
      shiny::tags$h3("Data"),
      shiny::tags$p(
        "Individual participant data from 4706 patients in 4 randomized clinical trials",
        "(LATITUDE, ARCHES, TITAN, and ARASENS) that compared an ARPI with placebo, each",
        "added to ADT with or without docetaxel. ADT alone refers to the placebo plus ADT",
        "arms of these trials; in ARASENS, both arms also received docetaxel."
      ),
      shiny::tags$h3("Methods"),
      shiny::tags$p(
        "Baseline risk comes from a Cox model, stratified by trial, with 9 predictors.",
        "Treatment effects were estimated within each trial as smooth functions of",
        "baseline risk and pooled with multivariate random-effects meta-analysis.",
        paste0(
          "Effects are reported for baseline risks from ", risk_range[[1L]], " to ",
          risk_range[[2L]], ", the 1st to 99th percentiles in the trials."
        )
      )
    ),
    bslib::accordion_panel(
      "Model specification",
      value = "specification",
      model_spec_ui(model)
    )
  )
}

# The coefficients behind the baseline risk, so the calculation can be checked
# or reproduced without the package.
model_spec_ui <- function(model) {
  lp <- model$linear_predictor
  hazards <- model$baseline_cumulative_hazard
  coefficient <- function(x) format_number(x, 5)
  rows <- purrr::map(unname(model$predictors), function(predictor) {
    switch(
      predictor$type,
      rcs = list(
        term = paste0(predictor$label, ", ", predictor$unit),
        form = paste0(
          "Restricted cubic spline with knots at ",
          paste(format_value(signif(predictor$knots, 5)), collapse = ", ")
        ),
        coefficients = paste(coefficient(predictor$coefficients), collapse = "; ")
      ),
      linear = list(
        term = paste0(predictor$label, ", ", predictor$unit),
        form = "Linear",
        coefficients = coefficient(predictor$coefficients)
      ),
      categorical = list(
        term = predictor$label,
        form = paste0("Categories; reference ", predictor$levels[[1L]]$label),
        coefficients = paste(
          purrr::map_chr(predictor$levels[-1L], function(level) {
            paste0(level$label, ", ", coefficient(level$coefficient))
          }),
          collapse = "; "
        )
      ),
      threshold = list(
        term = predictor$label,
        form = paste(predictor$choices[[2L]]$label, "vs", predictor$choices[[1L]]$label),
        coefficients = coefficient(predictor$coefficient)
      ),
      binary = list(
        term = predictor$label,
        form = "Present vs absent",
        coefficients = coefficient(predictor$coefficient)
      )
    )
  })
  shiny::tagList(
    shiny::tags$p(
      "The linear predictor is the shrinkage factor times the sum of the terms below",
      "minus the centering constant. Baseline risk is 1 minus the average, over the",
      "imputed datasets, of exp(\u2212H \u00d7 exp(linear predictor)), where H is the",
      "4-year baseline cumulative hazard for placebo plus ADT in each dataset. Spline",
      "terms use the restricted cubic spline parameterization of the rms package."
    ),
    shiny::tags$table(
      class = "table table-sm data-table",
      shiny::tags$thead(shiny::tags$tr(
        shiny::tags$th("Term"), shiny::tags$th("Form"), shiny::tags$th("Coefficients")
      )),
      shiny::tags$tbody(purrr::map(rows, function(row) {
        shiny::tags$tr(
          shiny::tags$td(row$term), shiny::tags$td(row$form), shiny::tags$td(row$coefficients)
        )
      }))
    ),
    shiny::tags$p(
      class = "table-note",
      paste0(
        "Shrinkage factor ", format_number(lp$shrinkage_factor, 4), "; centering constant ",
        format_number(lp$center, 4), "; 4-year baseline cumulative hazard ",
        format_number(min(hazards), 4), " to ", format_number(max(hazards), 4), " across ",
        length(hazards), " imputed datasets. The full specification, including the",
        " treatment-effect curves, is the file model_spec.json in the R package."
      )
    )
  )
}

# --- Server ------------------------------------------------------------------

app_server <- function(model) {
  predictors <- model$predictors
  numeric_predictors <- purrr::keep(predictors, function(predictor) {
    predictor$type %in% c("rcs", "linear")
  })
  unit_predictors <- purrr::keep(numeric_predictors, function(predictor) {
    length(predictor$alternative_units %||% list()) > 0L
  })

  function(input, output, session) {
    # Numeric inputs are stored in the model's base units, so switching the
    # display unit never changes the value used for scoring.
    units <- shiny::reactiveValues()
    base_values <- shiny::reactiveValues()
    purrr::walk(numeric_predictors, function(predictor) {
      name <- predictor$name
      units[[name]] <- display_units(predictor)[[1L]]
      base_values[[name]] <- NA_real_
      shiny::observeEvent(input[[name]], {
        value <- input[[name]]
        base_values[[name]] <- if (is_entered(value)) {
          value * unit_multiplier(predictor, shiny::isolate(units[[name]]))
        } else {
          NA_real_
        }
      }, ignoreNULL = FALSE)
    })
    purrr::walk(unit_predictors, function(predictor) {
      name <- predictor$name
      shiny::observeEvent(input[[paste0(name, "_unit")]], {
        new_unit <- input[[paste0(name, "_unit")]]
        units[[name]] <- new_unit
        base <- shiny::isolate(base_values[[name]])
        if (is.finite(base)) {
          shiny::updateNumericInput(
            session, name,
            value = signif(base / unit_multiplier(predictor, new_unit), 6)
          )
        }
      }, ignoreInit = TRUE)
    })

    entered <- shiny::reactive({
      purrr::map(predictors, function(predictor) {
        if (predictor$type %in% c("rcs", "linear")) {
          return(base_values[[predictor$name]])
        }
        value <- input[[predictor$name]]
        if (!is_entered(value)) {
          return(if (predictor$type == "categorical") NA_character_ else NA_real_)
        }
        if (predictor$type == "categorical") value else as.numeric(value)
      })
    })
    assessment <- shiny::reactive({
      assess_inputs(as.data.frame(entered()), model)
    })
    estimates <- shiny::reactive({
      checked <- assessment()
      if (any(checked$issues$severity == "error")) {
        return(NULL)
      }
      lp <- linear_predictor(checked$values, model)
      list(
        lp = lp,
        risk = absolute_risk(lp, model),
        in_range = in_effect_range(lp, model),
        effects = purrr::map(
          rlang::set_names(c("ard", "rmst", "hr")),
          function(scale) effect_at_lp(lp, model, scale)
        ),
        issues = checked$issues
      )
    })
    output$has_estimates <- shiny::reactive(!is.null(estimates()))
    shiny::outputOptions(output, "has_estimates", suspendWhenHidden = FALSE)

    # Field-level feedback, in the unit currently shown for each input.
    purrr::walk(numeric_predictors, function(predictor) {
      name <- predictor$name
      output[[paste0(name, "_feedback")]] <- shiny::renderUI({
        issues <- assessment()$issues
        issues <- issues[issues$input == name & issues$code != "missing", , drop = FALSE]
        if (nrow(issues) == 0L) {
          return(NULL)
        }
        purrr::pmap(list(issues$code, issues$value, issues$severity), function(code, value, severity) {
          shiny::tags$div(
            class = paste("feedback", severity),
            issue_message(code, predictor, value, unit = units[[name]], app = TRUE)
          )
        })
      })
    })

    output$input_progress <- shiny::renderUI({
      issues <- assessment()$issues
      missing <- unique(issues$input[issues$code == "missing"])
      invalid <- unique(issues$input[issues$severity == "error" & issues$code != "missing"])
      complete <- length(predictors) - length(missing)
      labels <- purrr::map_chr(predictors[missing], "short_label")
      shiny::tags$div(
        class = "input-progress",
        shiny::tags$p(shiny::tags$strong(paste0(complete, " of ", length(predictors), " entered"))),
        if (length(labels) > 0L) shiny::tags$p(paste0("Still needed: ", paste(labels, collapse = ", "), ".")),
        if (length(invalid) > 0L) shiny::tags$p(class = "feedback error", "Check the values marked in red.")
      )
    })

    result_messages <- shiny::reactive({
      result <- estimates()
      shiny::req(result)
      issues <- result$issues[result$issues$severity %in% c("warning", "note"), , drop = FALSE]
      messages <- purrr::pmap_chr(
        list(issues$code, issues$input, issues$value),
        function(code, input, value) {
          issue_message(code, predictors[[input]], value, unit = units[[input]] %||% NULL)
        }
      )
      if (!result$in_range) {
        range <- format_percent(effect_risk_range(model))
        messages <- c(messages, paste0(
          "Baseline risk is outside the range in which treatment effects were estimated (",
          range[[1L]], " to ", range[[2L]], "); effects are shown at the nearest edge of that range."
        ))
      }
      messages
    })
    output$result_notes <- shiny::renderUI({
      messages <- result_messages()
      if (length(messages) == 0L) {
        return(NULL)
      }
      shiny::tags$div(
        class = "result-notes",
        role = "status",
        shiny::tags$strong("Check before use"),
        shiny::tags$ul(purrr::map(messages, shiny::tags$li))
      )
    })

    output$risk_value <- shiny::renderText({
      shiny::req(estimates())
      format_percent(estimates()$risk)
    })
    output$arpi_risk_value <- shiny::renderText({
      result <- estimates()
      shiny::req(result)
      format_percent(result$risk - result$effects$ard$estimate)
    })
    output$ard_value <- shiny::renderUI({
      shiny::req(estimates())
      value_with_unit(format_number(100 * estimates()$effects$ard$estimate), "per 100")
    })
    output$ard_detail <- shiny::renderText({
      shiny::req(estimates())
      effect <- estimates()$effects$ard
      format_interval(100 * effect$conf_low, 100 * effect$conf_high)
    })
    output$rmst_value <- shiny::renderUI({
      shiny::req(estimates())
      value_with_unit(format_number(estimates()$effects$rmst$estimate, 1), "months")
    })
    output$rmst_detail <- shiny::renderText({
      shiny::req(estimates())
      effect <- estimates()$effects$rmst
      format_interval(effect$conf_low, effect$conf_high, digits = 1)
    })

    output$icon_array <- shiny::renderUI({
      result <- estimates()
      shiny::req(result)
      icon_array_ui(result$risk, result$effects$ard)
    })

    effect_scale <- shiny::reactive(input$effect_scale %||% "ard")
    output$effect_plot <- shiny::renderPlot({
      result <- estimates()
      shiny::req(result)
      scale <- effect_scale()
      curve <- effect_curve(model, scale)
      risk_range <- range(curve$risk_percent)
      patient <- data.frame(
        risk_percent = min(max(100 * result$risk, risk_range[[1L]]), risk_range[[2L]]),
        estimate = result$effects[[scale]]$estimate * effect_scales()[[scale]]$multiplier
      )
      graphics::par(effect_plot_par())
      draw_effect_plot(curve, scale, patients = patient, overall = overall_effect(model, scale))
    }, height = function() effect_plot_height(session$clientData$output_effect_plot_width), res = 96)

    clicked <- shiny::reactiveVal(NULL)
    shiny::observeEvent(input$effect_click, clicked(input$effect_click))
    shiny::observeEvent(effect_scale(), clicked(NULL))
    output$effect_readout <- shiny::renderUI({
      result <- estimates()
      shiny::req(result)
      scale <- effect_scale()
      pointer <- input$effect_hover %||% clicked()
      curve <- effect_curve(model, scale)
      if (is.null(pointer$x)) {
        lead <- paste0("This patient (baseline risk ", format_percent(result$risk), "): ")
        values <- result$effects[[scale]] * effect_scales()[[scale]]$multiplier
      } else {
        nearest <- which.min(abs(curve$risk_percent - pointer$x))
        lead <- paste0("At a baseline risk of ", format_percent(curve$risk_percent[[nearest]] / 100), ": ")
        values <- curve[nearest, , drop = FALSE]
      }
      shiny::tags$p(class = "effect-readout", lead, shiny::tags$strong(describe_effect(values, scale)))
    })

    # Values are in base units and are shown in the unit currently selected.
    fill_values <- function(values) {
      purrr::iwalk(values, function(value, name) {
        predictor <- predictors[[name]]
        if (is.null(predictor)) {
          return()
        }
        if (predictor$type %in% c("rcs", "linear")) {
          unit <- shiny::isolate(units[[name]])
          shiny::updateNumericInput(
            session, name,
            value = signif(value / unit_multiplier(predictor, unit), 6)
          )
        } else {
          shiny::updateRadioButtons(session, name, selected = value)
        }
      })
    }
    example_values <- list(
      ecog_ps = "0", gleason_score = "9", visceral_metastasis = "0",
      bone_metastases = "7-10", psa = 45, hemoglobin = 128, albumin = 41,
      alp = 180, ldh = 210
    )
    shiny::observeEvent(input$use_example, fill_values(example_values))
    shiny::observeEvent(input$use_example_main, fill_values(example_values))
    shiny::observeEvent(input$clear_inputs, {
      purrr::walk(predictors, function(predictor) {
        if (predictor$type %in% c("rcs", "linear")) {
          shiny::updateNumericInput(session, predictor$name, value = "")
        } else {
          shiny::updateRadioButtons(session, predictor$name, selected = character(0))
        }
      })
    })
    shiny::observeEvent(input$page_location, {
      query <- shiny::parseQueryString(input$page_location$search %||% "")
      fill_values(query_values(query, predictors))
    }, once = TRUE)
  }
}

value_with_unit <- function(value, unit) {
  shiny::tagList(value, shiny::tags$span(class = "value-unit", unit))
}

is_entered <- function(value) {
  !is.null(value) && length(value) == 1L && !is.na(value) && !identical(value, "")
}

describe_effect <- function(values, scale) {
  display <- effect_scales()[[scale]]
  paste0(
    display$short_label, ", ",
    format_number(values$estimate, display$digits), display$unit,
    " (", format_interval(values$conf_low, values$conf_high, display$digits), ")"
  )
}

# Values from the query string, as the app's input values: numbers in the
# model's units, category codes, and choice values. Unusable values are dropped.
query_values <- function(query, predictors) {
  values <- purrr::map(predictors, function(predictor) {
    raw <- query[[predictor$name]]
    if (!rlang::is_string(raw) || !nzchar(raw)) {
      return(NULL)
    }
    query_value(raw, predictor)
  })
  purrr::compact(values)
}

query_value <- function(raw, predictor) {
  if (predictor$type == "categorical") {
    codes <- purrr::map_chr(predictor$levels, "code")
    if (raw %in% codes) {
      return(raw)
    }
  }
  number <- suppressWarnings(as.numeric(raw))
  if (!is.finite(number)) {
    return(NULL)
  }
  switch(
    predictor$type,
    rcs = ,
    linear = number,
    categorical = {
      index <- assess_categorical(number, predictor)$values
      if (is.na(index)) NULL else codes[[index]]
    },
    threshold = ,
    binary = {
      if (!number %in% predictor$allowed_values) {
        return(NULL)
      }
      choice <- if (predictor$type == "threshold") {
        predictor$choices[[(number >= predictor$threshold) + 1L]]
      } else {
        purrr::detect(predictor$choices, function(choice) choice$value == number)
      }
      format_value(choice$value)
    }
  )
}

icon_array_ui <- function(risk, ard) {
  alive <- round(100 * (1 - risk))
  additional <- min(max(round(100 * ard$estimate), 0), 100 - alive)
  died <- 100 - alive - additional
  states <- rep(c("alive", "additional", "died"), c(alive, additional, died))
  interval <- format_interval(100 * ard$conf_low, 100 * ard$conf_high)
  summary <- paste0(
    "With ADT alone, about ", alive, " of 100 patients like this would be alive at 4 years. ",
    if (additional > 0L) {
      paste0("With an ARPI plus ADT, about ", alive + additional, " would be alive.")
    } else {
      "Adding an ARPI is not expected to change this number at this baseline risk."
    }
  )
  legend_item <- function(state, count, text, extra = NULL) {
    shiny::tags$li(
      shiny::tags$span(class = paste("swatch", state), `aria-hidden` = "true"),
      shiny::tags$span(
        shiny::tags$span(class = "count", count), " ", text,
        if (!is.null(extra)) shiny::tags$span(class = "legend-extra", extra)
      )
    )
  }
  shiny::tagList(
    shiny::tags$p(class = "icon-summary", summary),
    shiny::tags$div(
      class = "icon-array",
      role = "img",
      `aria-label` = paste0(
        alive, " alive with ADT alone, ", additional,
        " more alive with an ARPI, ", died, " died with either treatment, out of 100."
      ),
      purrr::map(states, function(state) shiny::tags$span(class = paste("icon", state)))
    ),
    shiny::tags$ul(
      class = "icon-legend",
      legend_item("alive", alive, "alive at 4 years with ADT alone"),
      legend_item(
        "additional", additional, "more alive with an ARPI plus ADT",
        if (additional == round(100 * ard$estimate)) {
          paste0(" (", interval, ")")
        } else {
          paste0(" (estimate ", format_number(100 * ard$estimate), "; ", interval, ")")
        }
      ),
      legend_item("died", died, "died within 4 years with either treatment")
    )
  )
}
