#' Describe the model inputs
#'
#' Lists the patient characteristics the model requires, with the column name
#' expected in `newdata`, the unit, the accepted values, the range observed
#' in the development data, and a definition of what to enter.
#'
#' @param model An `mhspc_model` object from [mhspc_model()].
#'
#' @return A data frame with one row per input and columns `name`, `label`,
#'   `unit`, `accepted`, `scoring`, and `definition`.
#' @examples
#' model_inputs()
#' @export
model_inputs <- function(model = mhspc_model()) {
  check_model(model)
  purrr::map(model$predictors, function(predictor) {
    data.frame(
      name = predictor$name,
      label = predictor$label,
      unit = input_unit(predictor),
      accepted = describe_accepted(predictor),
      scoring = describe_scoring(predictor),
      definition = predictor$help %||% NA_character_
    )
  }) |>
    purrr::list_rbind()
}

#' Check patient data before prediction
#'
#' Checks that `newdata` contains every model input with an accepted value.
#' Invalid or missing values stop with an error that names the row and input.
#' Values outside the range observed in the trials, and values above the upper
#' cap used in model development, are returned as warnings and notes.
#'
#' @param newdata A data frame with one row per patient and one column per
#'   input listed by [model_inputs()]: `ecog_ps` (0, 1, or 2),
#'   `gleason_score` (2 to 10), `visceral_metastasis` (0 or 1, or logical),
#'   `bone_metastases` (a count, or a category code `"0-3"`, `"4-6"`,
#'   `"7-10"`, or `"11+"`), `psa` (ng/mL), `hemoglobin` (g/L), `albumin`
#'   (g/L), `alp` (U/L), and `ldh` (U/L). Other columns are ignored.
#' @inheritParams model_inputs
#'
#' @return A data frame of warnings and notes with columns `row`, `input`,
#'   `severity`, and `message`; it has no rows when every value is within the
#'   development range.
#' @examples
#' patient <- data.frame(
#'   ecog_ps = 0, gleason_score = 9, visceral_metastasis = 0,
#'   bone_metastases = 8, psa = 45, hemoglobin = 128, albumin = 41,
#'   alp = 180, ldh = 210
#' )
#' check_inputs(patient)
#' @export
check_inputs <- function(newdata, model = mhspc_model()) {
  check_model(model)
  assessment <- assess_inputs(newdata, model)
  abort_on_input_errors(assessment$issues, model)
  issues <- assessment$issues[assessment$issues$severity != "error", , drop = FALSE]
  issues[c("row", "input", "severity", "message")]
}

prepare_inputs <- function(newdata, model, call = rlang::caller_env()) {
  assessment <- assess_inputs(newdata, model, call = call)
  abort_on_input_errors(assessment$issues, model, call = call)
  warnings <- assessment$issues[assessment$issues$severity == "warning", , drop = FALSE]
  if (nrow(warnings) > 0L) {
    cli::cli_warn(
      c(
        "{length(unique(warnings$row))} patient{?s} {?has/have} values outside the range in the trial data.",
        i = "Their estimates are extrapolations; see the {.field notes} column."
      ),
      class = "mhspcarpi_extrapolation_warning"
    )
  }
  assessment
}

# Returns the inputs encoded for scoring and a data frame of issues. Structural
# problems (not a data frame, no rows, missing columns) stop immediately.
assess_inputs <- function(newdata, model, call = rlang::caller_env()) {
  if (!is.data.frame(newdata)) {
    cli::cli_abort(
      "{.arg newdata} must be a data frame, not {.obj_type_friendly {newdata}}.",
      class = "mhspcarpi_input_error",
      call = call
    )
  }
  if (nrow(newdata) == 0L) {
    cli::cli_abort(
      "{.arg newdata} must have at least one row.",
      class = "mhspcarpi_input_error",
      call = call
    )
  }
  missing_columns <- setdiff(names(model$predictors), names(newdata))
  if (length(missing_columns) > 0L) {
    cli::cli_abort(
      c(
        "{.arg newdata} is missing required column{?s} {.field {missing_columns}}.",
        i = "See {.fn model_inputs} for the required inputs."
      ),
      class = "mhspcarpi_input_error",
      call = call
    )
  }

  assessed <- purrr::map(model$predictors, function(predictor) {
    assess_predictor(newdata[[predictor$name]], predictor)
  })
  issues <- purrr::map(assessed, "issues") |>
    purrr::list_rbind()
  if (nrow(issues) == 0L) {
    issues <- empty_issues()
  }
  issues$message <- purrr::pmap_chr(
    list(issues$code, issues$input, issues$value),
    function(code, input, value) issue_message(code, model$predictors[[input]], value)
  )
  issues <- issues[order(issues$row, match(issues$input, names(model$predictors))), , drop = FALSE]
  rownames(issues) <- NULL
  list(values = purrr::map(assessed, "values"), issues = issues)
}

empty_issues <- function() {
  data.frame(
    row = integer(),
    input = character(),
    severity = character(),
    code = character(),
    value = numeric()
  )
}

new_issues <- function(rows, predictor, severity, code, value = NA_real_) {
  if (length(rows) == 0L) {
    return(empty_issues())
  }
  data.frame(
    row = rows,
    input = predictor$name,
    severity = severity,
    code = code,
    value = if (length(value) == 1L) rep(value, length(rows)) else value
  )
}

assess_predictor <- function(x, predictor) {
  switch(
    predictor$type,
    rcs = ,
    linear = assess_continuous(x, predictor),
    categorical = assess_categorical(x, predictor),
    threshold = ,
    binary = assess_binary(x, predictor)
  )
}

assess_continuous <- function(x, predictor) {
  n <- length(x)
  if (!is.numeric(x) && !all(is.na(x))) {
    return(list(
      values = rep(NA_real_, n),
      issues = new_issues(seq_len(n), predictor, "error", "not_numeric")
    ))
  }
  x <- as.numeric(x)
  allowed <- predictor$allowed_range
  development <- predictor$development_range
  cap <- predictor$cap_upper %||% Inf
  missing <- is.na(x)
  below <- !missing & x < allowed[[1L]]
  above <- !missing & x > allowed[[2L]]
  valid <- !missing & !below & !above
  capped <- valid & x > cap
  outside <- valid & !capped & (x < development[[1L]] | x > development[[2L]])

  list(
    values = ifelse(valid, pmin(x, cap), NA_real_),
    issues = purrr::list_rbind(list(
      new_issues(which(missing), predictor, "error", "missing"),
      new_issues(which(below), predictor, "error", "out_of_range", x[below]),
      new_issues(which(above), predictor, "error", "out_of_range", x[above]),
      new_issues(which(outside), predictor, "warning", "outside_development", x[outside]),
      new_issues(which(capped), predictor, "note", "capped", x[capped])
    ))
  )
}

assess_categorical <- function(x, predictor) {
  n <- length(x)
  levels <- predictor$levels
  codes <- purrr::map_chr(levels, "code")
  labels <- purrr::map_chr(levels, "label")
  bounds <- purrr::map_dbl(levels, function(level) level$max_count %||% Inf)

  if (is.factor(x)) {
    x <- as.character(x)
  }
  if (is.character(x)) {
    missing <- is.na(x)
    index <- match(x, codes)
    index[is.na(index)] <- match(x[is.na(index)], labels)
    invalid <- !missing & is.na(index)
    return(list(
      values = index,
      issues = purrr::list_rbind(list(
        new_issues(which(missing), predictor, "error", "missing"),
        new_issues(which(invalid), predictor, "error", "invalid_level")
      ))
    ))
  }
  if (!is.numeric(x) && !all(is.na(x))) {
    return(list(
      values = rep(NA_integer_, n),
      issues = new_issues(seq_len(n), predictor, "error", "invalid_level")
    ))
  }

  x <- as.numeric(x)
  allowed <- predictor$allowed_range
  missing <- is.na(x)
  invalid <- !missing &
    (x != round(x) | x < allowed[[1L]] | x > allowed[[2L]])
  valid <- !missing & !invalid
  outside <- valid & x > predictor$development_range[[2L]]
  index <- rep(NA_integer_, n)
  index[valid] <- findInterval(x[valid], bounds, left.open = TRUE) + 1L

  list(
    values = index,
    issues = purrr::list_rbind(list(
      new_issues(which(missing), predictor, "error", "missing"),
      new_issues(which(invalid), predictor, "error", "invalid_count", x[invalid]),
      new_issues(which(outside), predictor, "warning", "outside_development", x[outside])
    ))
  )
}

assess_binary <- function(x, predictor) {
  n <- length(x)
  if (is.logical(x) && predictor$type == "binary") {
    x <- as.numeric(x)
  }
  if (!is.numeric(x) && !all(is.na(x))) {
    return(list(
      values = rep(NA_real_, n),
      issues = new_issues(seq_len(n), predictor, "error", "invalid_value")
    ))
  }
  x <- as.numeric(x)
  missing <- is.na(x)
  invalid <- !missing & !(x %in% predictor$allowed_values)
  valid <- !missing & !invalid
  encoded <- if (predictor$type == "threshold") {
    as.numeric(x >= predictor$threshold)
  } else {
    x
  }

  list(
    values = ifelse(valid, encoded, NA_real_),
    issues = purrr::list_rbind(list(
      new_issues(which(missing), predictor, "error", "missing"),
      new_issues(which(invalid), predictor, "error", "invalid_value", x[invalid])
    ))
  )
}

abort_on_input_errors <- function(issues, model, call = rlang::caller_env()) {
  errors <- issues[issues$severity == "error", , drop = FALSE]
  if (nrow(errors) == 0L) {
    return(invisible())
  }
  shown <- utils::head(errors, 8L)
  bullets <- rlang::set_names(
    paste0("Row ", shown$row, ": ", shown$message),
    rep("x", nrow(shown))
  )
  if (nrow(errors) > nrow(shown)) {
    bullets <- c(bullets, i = paste0("And ", nrow(errors) - nrow(shown), " more problem(s)."))
  }
  cli::cli_abort(
    c("{.arg newdata} has invalid or missing values.", bullets),
    class = "mhspcarpi_input_error",
    call = call
  )
}

row_notes <- function(issues, n_rows) {
  shown <- issues[issues$severity %in% c("warning", "note"), , drop = FALSE]
  purrr::map_chr(seq_len(n_rows), function(row) {
    messages <- shown$message[shown$row == row]
    if (length(messages) == 0L) NA_character_ else paste(messages, collapse = " ")
  })
}

# --- Messages ----------------------------------------------------------------

# `unit` selects the unit used in the message; values are stored in the
# model's base unit and converted for display.
issue_message <- function(code, predictor, value = NA_real_, unit = NULL, app = FALSE) {
  unit <- unit %||% predictor$unit
  multiplier <- unit_multiplier(predictor, unit)
  show <- function(x) format_value(signif(x / multiplier, 4))
  label <- predictor$label
  switch(
    code,
    missing = paste0(label, " is missing."),
    not_numeric = paste0(label, " must be a number."),
    out_of_range = paste0(
      label, " must be between ", show(predictor$allowed_range[[1L]]), " and ",
      show(predictor$allowed_range[[2L]]), " ", unit, ".",
      unit_hint(predictor, value, unit, app = app)
    ),
    outside_development = paste0(
      label, " of ", with_unit(show(value), unit),
      " is outside the range in the trial data (", show(predictor$development_range[[1L]]),
      " to ", with_unit(show(predictor$development_range[[2L]]), unit),
      "); the estimate is an extrapolation."
    ),
    capped = paste0(
      label, " values above ", show(predictor$cap_upper), " ", unit,
      " are scored as ", show(predictor$cap_upper), " ", unit,
      ", as in model development."
    ),
    invalid_count = paste0(
      label, " must be a whole number from ", show(predictor$allowed_range[[1L]]),
      " to ", show(predictor$allowed_range[[2L]]), "."
    ),
    invalid_level = paste0(
      label, " must be a count or one of the categories ",
      paste0("\"", purrr::map_chr(predictor$levels, "code"), "\"", collapse = ", "), "."
    ),
    invalid_value = paste0(
      label, " must be one of ", paste(predictor$allowed_values, collapse = ", "), "."
    )
  )
}

with_unit <- function(text, unit) if (identical(unit, "count")) text else paste(text, unit)

unit_multiplier <- function(predictor, unit) {
  if (is.null(unit) || identical(unit, predictor$unit)) {
    return(1)
  }
  alternative <- purrr::detect(predictor$alternative_units %||% list(), function(candidate) {
    identical(candidate$unit, unit)
  })
  if (is.null(alternative)) {
    cli::cli_abort("Unknown unit {.val {unit}} for {.field {predictor$name}}.")
  }
  alternative$multiplier
}

# Suggests a unit when an out-of-range value would be accepted in another unit,
# for example hemoglobin entered in g/dL where g/L is expected. In the app the
# suggestion is to switch the unit; in the package it is to convert the value.
unit_hint <- function(predictor, value, unit, app = FALSE) {
  if (!is.finite(value)) {
    return("")
  }
  entered <- value / unit_multiplier(predictor, unit)
  units <- c(
    list(list(unit = predictor$unit, multiplier = 1)),
    predictor$alternative_units %||% list()
  )
  fits <- purrr::keep(units, function(candidate) {
    converted <- entered * candidate$multiplier
    !identical(candidate$unit, unit) &&
      converted >= predictor$allowed_range[[1L]] &&
      converted <= predictor$allowed_range[[2L]]
  })
  if (length(fits) == 0L) {
    return("")
  }
  candidate <- fits[[1L]]
  if (app) {
    paste0(" If the value is in ", candidate$unit, ", select ", candidate$unit, ".")
  } else {
    paste0(
      " If it was measured in ", candidate$unit, ", multiply by ",
      format_value(candidate$multiplier / unit_multiplier(predictor, unit)), "."
    )
  }
}

input_unit <- function(predictor) {
  switch(
    predictor$type,
    rcs = ,
    linear = predictor$unit,
    categorical = "count",
    NA_character_
  )
}

describe_accepted <- function(predictor) {
  switch(
    predictor$type,
    rcs = ,
    linear = paste(
      format_value(predictor$allowed_range[[1L]]), "to",
      format_value(predictor$allowed_range[[2L]])
    ),
    categorical = paste0(
      "Count, or category code ",
      paste0("\"", purrr::map_chr(predictor$levels, "code"), "\"", collapse = ", ")
    ),
    paste(predictor$allowed_values, collapse = ", ")
  )
}

describe_scoring <- function(predictor) {
  switch(
    predictor$type,
    rcs = paste0(
      "Restricted cubic spline; trial data ",
      format_value(predictor$development_range[[1L]]), " to ",
      format_value(predictor$development_range[[2L]]),
      if (!is.null(predictor$cap_upper)) {
        paste0("; values above ", format_value(signif(predictor$cap_upper, 4)), " scored at the cap")
      }
    ),
    linear = "Linear",
    categorical = paste(
      "Categories", paste(purrr::map_chr(predictor$levels, "label"), collapse = ", ")
    ),
    threshold = paste(purrr::map_chr(predictor$choices, "label"), collapse = " vs "),
    binary = "Absent (0) or present (1)"
  )
}
