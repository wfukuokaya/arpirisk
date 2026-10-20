#' Load the risk model and treatment-effect estimates
#'
#' `mhspc_model()` reads the model specification, checks that it is internally
#' consistent, and returns it as an `mhspc_model` object. The prediction
#' functions call it by default, so most users never need to call it directly.
#'
#' The specification contains only aggregate quantities: the risk-model
#' coefficients and spline knots, the 4-year baseline cumulative hazards, and
#' the pooled treatment-effect curves.
#'
#' @param path Path to a model specification file. The default, `NULL`, uses
#'   the specification installed with the package.
#'
#' @return An object of class `mhspc_model`.
#' @examples
#' mhspc_model()
#' @export
mhspc_model <- function(path = NULL) {
  if (!is.null(path)) {
    return(read_model_spec(path))
  }
  if (is.null(model_cache$default)) {
    model_cache$default <- read_model_spec(installed_spec_path())
  }
  model_cache$default
}

model_cache <- new.env(parent = emptyenv())

# Held in a variable so dependency scanners do not treat the package as a
# dependency of the Shinylive app, which sources these files directly.
package_name <- "arpirisk"

installed_spec_path <- function(call = rlang::caller_env()) {
  path <- system.file("extdata", "model_spec.json", package = package_name)
  if (!nzchar(path)) {
    cli::cli_abort(
      c(
        "The installed model specification was not found.",
        i = "Supply {.arg path} to {.fn mhspc_model}."
      ),
      class = "arpirisk_spec_error",
      call = call
    )
  }
  path
}

read_model_spec <- function(path, call = rlang::caller_env()) {
  if (!rlang::is_string(path) || !file.exists(path)) {
    cli::cli_abort(
      "{.arg path} must be the path to an existing model specification file.",
      class = "arpirisk_spec_error",
      call = call
    )
  }
  spec <- jsonlite::fromJSON(
    path,
    simplifyVector = TRUE,
    simplifyDataFrame = FALSE,
    simplifyMatrix = FALSE
  )
  validate_mhspc_model(new_mhspc_model(spec), call = call)
}

new_mhspc_model <- function(spec) {
  predictors <- spec$predictors %||% list()
  predictor_names <- purrr::map_chr(predictors, function(predictor) {
    predictor$name %||% NA_character_
  })
  effects <- spec$treatment_effects %||% list()
  structure(
    list(
      schema_version = spec$schema_version,
      meta = spec$meta,
      linear_predictor = spec$linear_predictor,
      baseline_cumulative_hazard = as.numeric(spec$baseline_cumulative_hazard),
      predictors = rlang::set_names(predictors, predictor_names),
      treatment_effects = list(
        lp_range = as.numeric(effects$lp_range),
        lp_range_definition = effects$lp_range_definition,
        curves = purrr::map(effects$curves, function(curve) {
          as.data.frame(purrr::map(curve, as.numeric))
        }),
        overall = effects$overall
      ),
      verification = spec$verification
    ),
    class = "mhspc_model"
  )
}

validate_mhspc_model <- function(model, call = rlang::caller_env()) {
  spec_abort <- function(message) {
    cli::cli_abort(
      c("The model specification is invalid.", x = message),
      class = "arpirisk_spec_error",
      call = call
    )
  }
  is_finite_number <- function(x) is.numeric(x) && length(x) == 1L && is.finite(x)

  if (!identical(as.integer(model$schema_version), 4L)) {
    spec_abort("Only schema version 4 is supported.")
  }
  hazards <- model$baseline_cumulative_hazard
  if (length(hazards) == 0L || any(!is.finite(hazards) | hazards < 0)) {
    spec_abort("Baseline cumulative hazards must be finite and nonnegative.")
  }
  lp <- model$linear_predictor
  valid_lp <- is_finite_number(lp$center) && is_finite_number(lp$shrinkage_factor)
  if (!valid_lp || lp$shrinkage_factor <= 0) {
    spec_abort("The linear predictor needs a finite center and a positive shrinkage factor.")
  }

  predictors <- model$predictors
  names_valid <- !anyNA(names(predictors)) && anyDuplicated(names(predictors)) == 0L
  if (length(predictors) == 0L || !names_valid) {
    spec_abort("Predictors must have unique names.")
  }
  purrr::iwalk(predictors, function(predictor, name) {
    problem <- predictor_spec_problem(predictor)
    if (!is.null(problem)) {
      spec_abort(paste0("Predictor ", name, ": ", problem))
    }
  })

  effects <- model$treatment_effects
  required_curves <- c("ard", "rmst", "log_hr")
  if (!all(required_curves %in% names(effects$curves))) {
    spec_abort("Treatment-effect curves must include ard, rmst, and log_hr.")
  }
  grid <- effects$curves$ard$lp
  if (length(grid) < 2L || any(!is.finite(grid)) || any(diff(grid) <= 0)) {
    spec_abort("The treatment-effect grid must be finite and strictly increasing.")
  }
  curve_columns <- c("lp", "estimate", "conf_low", "conf_high", "pred_low", "pred_high")
  purrr::iwalk(effects$curves[required_curves], function(curve, name) {
    if (!all(curve_columns %in% names(curve)) || !identical(curve$lp, grid)) {
      spec_abort(paste0("Curve ", name, " must share the grid and contain all interval columns."))
    }
    values <- unlist(curve[curve_columns], use.names = FALSE)
    ordered <- curve$conf_low <= curve$estimate & curve$estimate <= curve$conf_high &
      curve$pred_low <= curve$conf_low & curve$conf_high <= curve$pred_high
    if (any(!is.finite(values)) || !all(ordered)) {
      spec_abort(paste0("Curve ", name, " has missing values or misordered intervals."))
    }
  })
  range_matches <- length(effects$lp_range) == 2L &&
    isTRUE(all.equal(effects$lp_range, range(grid)))
  if (!range_matches) {
    spec_abort("The treatment-effect range must match the curve grid.")
  }
  if (!all(c("ard", "rmst", "hr") %in% names(effects$overall))) {
    spec_abort("Overall treatment effects must include ard, rmst, and hr.")
  }
  model
}

predictor_spec_problem <- function(predictor) {
  valid_number <- function(x) is.numeric(x) && length(x) == 1L && is.finite(x)
  valid_range <- function(x) {
    is.numeric(x) && length(x) == 2L && all(is.finite(x)) && x[[1L]] < x[[2L]]
  }
  type <- predictor$type %||% ""
  if (type %in% c("rcs", "linear")) {
    if (!valid_range(predictor$allowed_range) || !valid_range(predictor$development_range)) {
      return("accepted and development ranges must be increasing pairs.")
    }
    if (!is.null(predictor$cap_upper) && !valid_number(predictor$cap_upper)) {
      return("the upper cap must be a finite number.")
    }
  }
  switch(
    type,
    rcs = {
      knots <- predictor$knots
      knots_valid <- is.numeric(knots) && length(knots) >= 3L && all(is.finite(knots))
      if (!knots_valid || any(diff(knots) <= 0)) {
        return("knots must be finite and strictly increasing.")
      }
      coefficients_valid <- length(predictor$coefficients) == length(knots) - 1L &&
        all(is.finite(predictor$coefficients))
      if (!coefficients_valid) {
        return("an RCS term with k knots needs k - 1 finite coefficients.")
      }
      NULL
    },
    linear = if (length(predictor$coefficients) != 1L || !is.finite(predictor$coefficients)) {
      "a linear term needs one finite coefficient."
    },
    categorical = {
      levels <- predictor$levels
      codes <- purrr::map_chr(levels, function(level) level$code %||% NA_character_)
      coefficients <- purrr::map_dbl(levels, function(level) level$coefficient %||% NA_real_)
      bounds <- purrr::map_dbl(levels, function(level) level$max_count %||% Inf)
      if (length(levels) < 2L || anyNA(codes) || anyDuplicated(codes) > 0L) {
        "levels need unique codes."
      } else if (any(!is.finite(coefficients)) || coefficients[[1L]] != 0) {
        "level coefficients must be finite, with 0 for the reference level."
      } else if (any(diff(bounds) <= 0) || is.finite(bounds[[length(bounds)]])) {
        "level count bounds must increase and the last level must be open."
      }
    },
    threshold = ,
    binary = {
      if (!valid_number(predictor$coefficient)) {
        "the coefficient must be a finite number."
      } else if (type == "threshold" && !valid_number(predictor$threshold)) {
        "the threshold must be a finite number."
      } else if (!is.numeric(predictor$allowed_values) || length(predictor$choices) < 2L) {
        "allowed values and choices are required."
      }
    },
    paste0("unknown predictor type '", type, "'.")
  )
}

#' @export
print.mhspc_model <- function(x, ...) {
  meta <- x$meta # nolint: object_usage_linter. Used in the cli strings below.
  cli::cli_text("{.strong mHSPC ARPI treatment-effect model} ({meta$model_version})")
  cli::cli_bullets(c(
    "*" = "Baseline risk: {meta$outcome} within {meta$horizon_years} years with {meta$reference_strategy}.",
    "*" = "Inputs: {.field {names(x$predictors)}}.",
    "*" = paste(
      "Treatment effects of {meta$comparator_strategy}: survival difference,",
      "restricted mean survival time difference, and hazard ratio."
    )
  ))
  invisible(x)
}

check_model <- function(model, call = rlang::caller_env()) {
  if (!inherits(model, "mhspc_model")) {
    cli::cli_abort(
      "{.arg model} must be an {.cls mhspc_model} object from {.fn mhspc_model}.",
      class = "arpirisk_spec_error",
      call = call
    )
  }
  invisible(model)
}
