# Inline the header artwork into R/app_gradients.R.
#
# The SVG files in inst/app/gradients/ are layered radial gradients, generated
# with the layered-radial-gradients skill's generator (an implementation of the
# method described by Justin Jay Wang, "Methods for random gradients", 2024):
#
#   python3 generate_layered_radial.py --output inst/app/gradients/header-<seed>.svg \
#     --seed <seed> --width 1600 --height 420 \
#     --palette '#374E55' '#00A1D5' '#B24745' '#6A6599'
#
# The palette is the darker half of the JAMA palette (Limed Spruce, Cerulean,
# Apple Blossom, Kimberly); the app's style sheet adds an ink scrim so that the
# white title stays legible. The app shows one of them, chosen at random,
# behind the title on every page load. Inlining the SVG text keeps the
# Shinylive app self-contained.
#
# Usage, from the package root:
#   Rscript tools/build_gradients.R

paths <- sort(list.files(file.path("inst", "app", "gradients"), pattern = "[.]svg$", full.names = TRUE))
if (length(paths) == 0L) {
  cli::cli_abort("No SVG files found in {.path inst/app/gradients}.")
}

inline_svg <- function(path) {
  svg <- paste(readLines(path, warn = FALSE), collapse = "")
  svg <- gsub("<metadata>.*?</metadata>", "", svg)
  svg <- gsub("<title>.*?</title>", "", svg)
  svg <- gsub(">\\s+<", "><", svg)
  svg <- sub(
    "<svg ",
    "<svg aria-hidden=\"true\" focusable=\"false\" preserveAspectRatio=\"xMidYMid slice\" ",
    svg
  )
  svg <- sub(" width=\"1600\" height=\"420\"", " width=\"100%\" height=\"100%\"", svg)
  if (!grepl("width=\"100%\"", svg)) {
    cli::cli_abort("Unexpected dimensions in {.file {path}}; expected 1600 by 420.")
  }
  svg
}

svgs <- purrr::map_chr(paths, inline_svg)
seeds <- sub("^header-([0-9]+)[.]svg$", "\\1", basename(paths))
quoted <- paste0("  \"", gsub("\"", "\\\\\"", svgs), "\"")

lines <- c(
  "# Generated from inst/app/gradients/ by tools/build_gradients.R. Do not edit by hand.",
  "# Header artwork: layered radial gradients after Justin Jay Wang's method.",
  paste0("# Seeds: ", paste(seeds, collapse = ", "), "."),
  "header_gradients <- c(",
  paste0(quoted, collapse = ",\n"),
  ")"
)
writeLines(lines, file.path("R", "app_gradients.R"))
cli::cli_inform(c(v = "Wrote {.file R/app_gradients.R} with {length(svgs)} gradients."))
