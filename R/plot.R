#' Plot treatment effects across baseline risk
#'
#' Draws the pooled treatment effect of an androgen receptor pathway inhibitor
#' (ARPI) plus androgen deprivation therapy (ADT) versus placebo plus ADT across
#' the range of baseline risk in which effects were estimated, with its 95%
#' confidence interval. Patients in `newdata` are marked at their baseline
#' risk.
#'
#' @param newdata Optional data frame of patients to mark; see
#'   [check_inputs()] for the required columns.
#' @param scale Effect to plot: `"ard"`, additional patients alive at 4 years
#'   per 100; `"rmst"`, additional months alive over 4 years; or `"hr"`, the
#'   hazard ratio for death on a log scale.
#' @param show_overall Whether to draw the overall effect across all trial
#'   patients as a reference line.
#' @param show_prediction_interval Whether to draw the 95% prediction interval
#'   for a new trial population.
#' @inheritParams model_inputs
#'
#' @return Invisibly, a data frame with the plotted curve in display units.
#' @examples
#' patient <- data.frame(
#'   ecog_ps = 0, gleason_score = 9, visceral_metastasis = 0,
#'   bone_metastases = 8, psa = 45, hemoglobin = 128, albumin = 41,
#'   alp = 180, ldh = 210
#' )
#' plot_treatment_effect(patient)
#' @export
plot_treatment_effect <- function(newdata = NULL,
                                  scale = c("ard", "rmst", "hr"),
                                  model = mhspc_model(),
                                  show_overall = TRUE,
                                  show_prediction_interval = FALSE) {
  check_model(model)
  scale <- match.arg(scale)
  curve <- effect_curve(model, scale)
  patients <- if (!is.null(newdata)) patient_points(newdata, model, scale)

  old_par <- graphics::par(effect_plot_par())
  on.exit(graphics::par(old_par), add = TRUE)
  draw_effect_plot(
    curve,
    scale,
    patients = patients,
    overall = if (isTRUE(show_overall)) overall_effect(model, scale),
    show_prediction_interval = isTRUE(show_prediction_interval)
  )
  invisible(curve)
}

effect_scales <- function() {
  list(
    ard = list(
      multiplier = 100,
      digits = 0,
      reference = 0,
      y_label = "Additional alive at 4 years, per 100",
      short_label = "Difference in patients alive at 4 years",
      unit = " per 100"
    ),
    rmst = list(
      multiplier = 1,
      digits = 1,
      reference = 0,
      y_label = "Additional months alive over 4 years",
      short_label = "Difference in time alive over 4 years",
      unit = " months"
    ),
    hr = list(
      multiplier = 1,
      digits = 2,
      reference = 1,
      y_label = "Hazard ratio for death (log scale)",
      short_label = "Hazard ratio for death",
      unit = ""
    )
  )
}

# Curve on the display scale, indexed by baseline risk in percent.
effect_curve <- function(model, scale) {
  display <- effect_scales()[[scale]]
  lp <- model$treatment_effects$curves$ard$lp
  effects <- effect_at_lp(lp, model, scale)
  data.frame(
    lp = lp,
    risk_percent = 100 * absolute_risk(lp, model),
    effects * display$multiplier
  )
}

overall_effect <- function(model, scale) {
  model$treatment_effects$overall[[scale]]$estimate * effect_scales()[[scale]]$multiplier
}

patient_points <- function(newdata, model, scale) {
  effects <- estimate_treatment_effect(newdata, scale, model)
  risk_range <- 100 * effect_risk_range(model)
  data.frame(
    risk_percent = pmin(pmax(100 * effects$baseline_risk, risk_range[[1L]]), risk_range[[2L]]),
    estimate = effects$estimate * effect_scales()[[scale]]$multiplier
  )
}

# Colors from the JAMA palette (as in ggsci::pal_jama()) on Bootstrap's neutral
# grays, matching the calculator theme in _brand.yml.
effect_plot_style <- function() {
  list(
    series = "#374E55", # Limed Spruce: the pooled curve and its confidence band
    highlight = "#DF8F44", # Anzac: the marked patients
    reference = "#80796B", # Makara: the overall effect
    ink = "#212529",
    secondary = "#495057",
    muted = "#6c757d",
    grid = "#e9ecef",
    axis = "#ced4da",
    surface = "#ffffff"
  )
}

effect_plot_par <- function() {
  list(
    mar = c(3.6, 4.4, 0.6, 0.8),
    mgp = c(2.3, 0.45, 0),
    tcl = -0.2,
    las = 1,
    cex = 0.9,
    family = "sans",
    xpd = FALSE
  )
}

hr_ticks <- function(limits) {
  candidates <- c(0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1, 1.25, 1.5, 2)
  inside <- candidates[candidates >= limits[[1L]] & candidates <= limits[[2L]]]
  if (length(inside) > 6L) inside[seq(1L, length(inside), by = 2L)] else inside
}

# Draws on the current device without changing graphical parameters, so the
# caller controls par() (the Shiny app relies on this for hover coordinates).
draw_effect_plot <- function(curve,
                             scale,
                             patients = NULL,
                             overall = NULL,
                             show_prediction_interval = FALSE) {
  style <- effect_plot_style()
  display <- effect_scales()[[scale]]
  x <- curve$risk_percent
  y_values <- c(curve$conf_low, curve$conf_high, display$reference, overall, patients$estimate)
  if (show_prediction_interval) {
    y_values <- c(y_values, curve$pred_low, curve$pred_high)
  }
  y_limits <- range(y_values)
  is_log <- scale == "hr"
  y_ticks <- if (is_log) hr_ticks(y_limits) else pretty(y_limits)
  if (!is_log) {
    y_limits <- range(c(y_limits, y_ticks))
  }
  # The x axis always spans 0% to 100%; the curve covers the range in which
  # effects were estimated.
  x_limits <- c(0, 100)
  x_ticks <- seq(0, 100, by = 20)

  graphics::plot.new()
  graphics::plot.window(xlim = x_limits, ylim = y_limits, log = if (is_log) "y" else "", xaxs = "i")
  graphics::abline(h = y_ticks, col = style$grid, lwd = 1)
  graphics::abline(h = display$reference, col = style$axis, lwd = 1.5)

  if (show_prediction_interval) {
    graphics::polygon(
      c(x, rev(x)), c(curve$pred_low, rev(curve$pred_high)),
      col = grDevices::adjustcolor(style$series, alpha.f = 0.06), border = NA
    )
  }
  graphics::polygon(
    c(x, rev(x)), c(curve$conf_low, rev(curve$conf_high)),
    col = grDevices::adjustcolor(style$series, alpha.f = 0.16), border = NA
  )
  if (!is.null(overall)) {
    graphics::abline(h = overall, col = style$reference, lwd = 1)
  }
  graphics::lines(x, curve$estimate, col = style$series, lwd = 2)
  if (!is.null(overall)) {
    draw_label(x_limits[[1L]], overall, "All trial patients", side = "right", style = style, color = style$secondary)
  }

  if (!is.null(patients) && nrow(patients) > 0L) {
    usr <- graphics::par("usr")
    bottom <- if (is_log) 10^usr[[3L]] else usr[[3L]]
    graphics::segments(
      patients$risk_percent, bottom, patients$risk_percent, patients$estimate,
      col = style$muted, lwd = 1
    )
    graphics::points(
      patients$risk_percent, patients$estimate,
      pch = 21, bg = style$highlight, col = style$surface, lwd = 2, cex = 1.7
    )
    if (nrow(patients) == 1L) {
      side <- if (patients$risk_percent < mean(x_limits)) "right" else "left"
      draw_label(
        patients$risk_percent, patients$estimate, "This patient",
        side = side, style = style, color = style$ink, font = 2, gap = 0.1
      )
    }
  }

  graphics::axis(
    1, at = x_ticks, labels = paste0(x_ticks, "%"),
    col = style$axis, col.ticks = style$axis, col.axis = style$secondary, lwd = 1
  )
  graphics::axis(
    2, at = y_ticks, labels = format_value(y_ticks),
    col = NA, col.ticks = NA, col.axis = style$secondary
  )
  plot_size <- graphics::par("pin")
  x_label <- "4-year risk of death with ADT alone"
  graphics::title(xlab = x_label, col.lab = style$secondary, cex.lab = label_cex(x_label, plot_size[[1L]]))
  graphics::title(
    ylab = display$y_label,
    col.lab = style$secondary,
    cex.lab = label_cex(display$y_label, plot_size[[2L]])
  )
  invisible()
}

# Character expansion that keeps an axis title within the plot region on one
# line, so narrow devices do not clip it.
label_cex <- function(label, width_inches, cex = 0.95, attempts = 4L) {
  needed <- graphics::strwidth(label, units = "inches", cex = cex)
  if (needed <= width_inches || attempts == 0L) {
    return(cex)
  }
  # Text width is not exactly proportional to cex, so shrink a little more
  # than the ratio and measure again.
  label_cex(label, width_inches, cex * width_inches / needed * 0.98, attempts - 1L)
}

# Text on a surface-colored box, offset above and to one side of (x, y). Sizes
# are computed in inches so the box also works on a log-scale axis.
draw_label <- function(x, y, label, side, style, color, font = 1, cex = 0.85, gap = 0.04) {
  width <- graphics::strwidth(label, units = "inches", cex = cex, font = font)
  height <- graphics::strheight(label, units = "inches", cex = cex, font = font)
  pad <- 0.03
  x_inches <- graphics::grconvertX(x, "user", "inches")
  y_inches <- graphics::grconvertY(y, "user", "inches")
  left <- if (side == "right") x_inches + gap else x_inches - gap - width
  bottom <- y_inches + 0.05
  to_x <- function(value) graphics::grconvertX(value, "inches", "user")
  to_y <- function(value) graphics::grconvertY(value, "inches", "user")
  graphics::rect(
    to_x(left - pad), to_y(bottom - pad), to_x(left + width + pad), to_y(bottom + height + pad),
    col = style$surface, border = NA
  )
  graphics::text(to_x(left), to_y(bottom), label, adj = c(0, 0), cex = cex, font = font, col = color)
}
