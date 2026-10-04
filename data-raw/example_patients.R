# Synthetic example patients spanning the range of baseline risk. They are not
# trial participants. Run from the package root to regenerate
# data/example_patients.rda.

example_patients <- data.frame(
  patient_id = paste0("P", 1:6),
  ecog_ps = c(0, 0, 0, 1, 1, 2),
  gleason_score = c(7, 8, 9, 9, 8, 10),
  visceral_metastasis = c(0, 0, 0, 0, 1, 1),
  bone_metastases = c(0, 2, 8, 15, 5, 30),
  psa = c(5, 12, 45, 150, 30, 800),
  hemoglobin = c(150, 142, 128, 115, 120, 105),
  albumin = c(46, 44, 41, 38, 36, 34),
  alp = c(70, 80, 180, 420, 150, 500),
  ldh = c(160, 170, 210, 280, 320, 350)
)

save(
  example_patients,
  file = file.path("data", "example_patients.rda"),
  version = 2,
  compress = "bzip2"
)
