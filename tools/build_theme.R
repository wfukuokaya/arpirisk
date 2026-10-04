# Generate R/app_theme.R from _brand.yml.
#
# The calculator runs in the browser as a Shinylive site, where compiling a
# branded Bootstrap theme with Sass would cost every visitor several seconds and
# pull in extra packages. Instead, the brand file is read here with the
# brand.yml package and written out as CSS custom properties that the app's
# style sheet (R/app_css.R) uses, on top of bslib's precompiled theme.
#
# Usage, from the package root:
#   Rscript tools/build_theme.R

brand <- brand.yml::read_brand_yml("_brand.yml")
palette <- brand$color$palette

# brand.yml normalizes names, so "ink-secondary" is read as "ink_secondary".
color <- function(name) {
  value <- palette[[gsub("-", "_", name)]]
  if (is.null(value)) {
    cli::cli_abort("The palette has no color named {.val {name}}.")
  }
  value
}
semantic <- function(name) {
  value <- brand$color[[name]]
  if (is.null(value)) {
    cli::cli_abort("The brand defines no {.field {name}} color.")
  }
  if (!is.null(palette[[gsub("-", "_", value)]])) palette[[gsub("-", "_", value)]] else value
}
rgb_triplet <- function(hex) paste(grDevices::col2rgb(hex)[, 1L], collapse = ", ")

# Platform fallbacks for the system fonts named in the brand file. The
# system-ui stack is the one Quarto's default HTML theme uses.
font_stacks <- list(
  "system-ui" = c(
    "system-ui", "-apple-system", "Segoe UI", "Roboto", "Helvetica Neue", "Noto Sans",
    "Liberation Sans", "Arial", "sans-serif"
  )
)
font_stack <- function(family) {
  stack <- font_stacks[[family]]
  if (is.null(stack)) {
    cli::cli_abort("No fallback stack is defined for the font {.val {family}}.")
  }
  paste(ifelse(grepl(" ", stack), paste0("'", stack, "'"), stack), collapse = ", ")
}

variables <- c(
  "--paper" = semantic("background"),
  "--surface" = color("white"),
  "--surface-muted" = color("surface-muted"),
  "--ink" = semantic("foreground"),
  "--ink-secondary" = color("ink-secondary"),
  "--ink-muted" = color("ink-muted"),
  "--hairline" = color("hairline"),
  "--primary" = semantic("primary"),
  "--primary-deep" = color("spruce-deep"),
  "--series-1" = color("cerulean"),
  "--series-2" = color("anzac"),
  "--neutral-mark" = color("neutral-mark"),
  "--warning-rule" = semantic("warning"),
  "--warning-ink" = color("anzac-ink"),
  "--warning-wash" = color("anzac-wash"),
  "--error-ink" = semantic("danger"),
  "--font-body" = font_stack(brand$typography$base$family),
  "--font-display" = font_stack(brand$typography$headings$family),
  "--font-size-base" = brand$typography$base$size,
  "--line-height-base" = as.character(brand$typography$base$line_height),
  "--headings-weight" = as.character(brand$typography$headings$weight),
  "--headings-line-height" = as.character(brand$typography$headings$line_height),
  # Bootstrap 5 variables read by bslib's precompiled theme.
  "--bs-body-bg" = semantic("background"),
  "--bs-body-color" = semantic("foreground"),
  "--bs-body-font-family" = font_stack(brand$typography$base$family),
  "--bs-body-font-size" = brand$typography$base$size,
  "--bs-body-line-height" = as.character(brand$typography$base$line_height),
  "--bs-heading-color" = semantic("foreground"),
  "--bs-emphasis-color" = semantic("foreground"),
  "--bs-secondary-color" = color("ink-secondary"),
  "--bs-tertiary-color" = color("ink-muted"),
  "--bs-border-color" = color("hairline"),
  "--bs-primary" = semantic("primary"),
  "--bs-primary-rgb" = rgb_triplet(semantic("primary")),
  "--bs-link-color" = semantic("primary"),
  "--bs-link-color-rgb" = rgb_triplet(semantic("primary")),
  "--bs-link-hover-color" = color("spruce-deep"),
  "--bs-link-hover-color-rgb" = rgb_triplet(color("spruce-deep")),
  "--bs-success" = semantic("success"),
  "--bs-info" = semantic("info"),
  "--bs-warning" = semantic("warning"),
  "--bs-danger" = semantic("danger")
)

lines <- c(
  "# Generated from _brand.yml by tools/build_theme.R. Do not edit by hand.",
  "app_theme_css <- function() {",
  "  \"",
  ":root {",
  paste0("  ", names(variables), ": ", unname(variables), ";"),
  "}",
  "\"",
  "}"
)
writeLines(lines, file.path("R", "app_theme.R"))
cli::cli_inform(c(v = "Wrote {.file R/app_theme.R} with {length(variables)} variables from {.file _brand.yml}."))
