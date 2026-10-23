#' Example patients
#'
#' Six synthetic patients that span the range of baseline risk, for examples
#' and tests. They are not trial participants. Values are in the model's units
#' (see [model_inputs()]).
#'
#' @format A data frame with 6 rows and 10 columns: `patient_id` and the 9
#'   model inputs `ecog_ps`, `gleason_score`, `visceral_metastasis`,
#'   `bone_metastases`, `psa`, `hemoglobin`, `albumin`, `alp`, and `ldh`.
#' @source Created in `data-raw/example_patients.R`.
#' @examples
#' predict_risk(example_patients)
"example_patients"
