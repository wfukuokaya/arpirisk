`%||%` <- function(x, y) if (is.null(x)) y else x

# Minus sign for negative numbers in displayed text.
minus_sign <- "\u2212"

format_number <- function(x, digits = 0) {
  text <- formatC(abs(x), format = "f", digits = digits, big.mark = ",")
  is_negative <- x < 0 & text != formatC(0, format = "f", digits = digits)
  paste0(ifelse(is_negative, minus_sign, ""), text)
}

format_percent <- function(proportion, digits = 0) {
  percent <- 100 * proportion
  lowest <- 10^-digits
  formatted <- paste0(format_number(percent, digits), "%")
  formatted[percent < lowest] <- paste0("<", format_number(lowest, digits), "%")
  formatted[percent > 100 - lowest] <- paste0(">", format_number(100 - lowest, digits), "%")
  formatted
}

format_interval <- function(low, high, digits = 0, prefix = "95% CI, ") {
  paste0(prefix, format_number(low, digits), " to ", format_number(high, digits))
}

format_value <- function(x) {
  format(x, big.mark = ",", scientific = FALSE, trim = TRUE, drop0trailing = TRUE)
}
