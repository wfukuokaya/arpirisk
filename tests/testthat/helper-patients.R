example_patient <- function(...) {
  values <- list(
    ecog_ps = 0, gleason_score = 9, visceral_metastasis = 0,
    bone_metastases = 8, psa = 45, hemoglobin = 128, albumin = 41,
    alp = 180, ldh = 210
  )
  overrides <- list(...)
  values[names(overrides)] <- overrides
  as.data.frame(values)
}

# Below the 1st percentile of baseline risk in the trials.
low_risk_patient <- function() {
  example_patient(
    gleason_score = 7, bone_metastases = 0, psa = 5, hemoglobin = 150,
    albumin = 46, alp = 70, ldh = 160
  )
}

# Writes a modified copy of the installed specification and returns its path.
modified_spec <- function(modify) {
  spec <- jsonlite::fromJSON(
    system.file("extdata", "model_spec.json", package = "mhspcarpi"),
    simplifyVector = TRUE,
    simplifyDataFrame = FALSE,
    simplifyMatrix = FALSE
  )
  path <- tempfile(fileext = ".json")
  jsonlite::write_json(modify(spec), path, auto_unbox = TRUE, digits = NA, null = "null")
  path
}
