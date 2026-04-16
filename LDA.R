# ================================
# 📦 Libraries
# ================================
library(readxl)
library(writexl)
library(MASS)
library(ggplot2)
library(dplyr)
library(missMDA)

# ================================
# 📂 1. Load data
# ================================
load_zscore_matrix <- function(file_path, sheet = "Zscores") {
  zs_raw <- read_excel(file_path, sheet = sheet)
  colnames(zs_raw)[1] <- "feature"
  
  mat <- as.data.frame(zs_raw[, -1])
  rownames(mat) <- zs_raw$feature
  
  mat[] <- lapply(mat, function(x) as.numeric(as.character(x)))
  return(mat)
}

# ================================
# 🔍 2. Impute missing values (PCA)
# ================================
impute_matrix <- function(mat, ncp = 5) {
  res_imp <- imputePCA(mat, ncp = ncp)
  return(as.data.frame(res_imp$completeObs))
}

# ================================
# 🧠 3. Functional classification
# ================================
classify_features <- function(mat, reference_strain, z_threshold = 1) {
  
  if (!(reference_strain %in% colnames(mat))) {
    stop("Reference strain not found in matrix")
  }
  
  zs <- mat[, reference_strain]
  
  group <- case_when(
    zs >=  z_threshold  ~ "Overrepresented",
    zs <= -z_threshold  ~ "Underrepresented",
    TRUE                ~ "Baseline"
  )
  
  return(factor(group))
}

# ================================
# 📊 4. Run LDA
# ================================
run_lda <- function(mat, group_labels) {
  lda_model <- lda(group_labels ~ ., data = cbind(group_labels, mat))
  lda_pred <- predict(lda_model)
  
  lda_df <- as.data.frame(lda_pred$x)
  lda_df$Group <- group_labels
  lda_df$Feature <- rownames(mat)
  
  return(lda_df)
}

# ================================
# 🎨 5. Plot LDA
# ================================
plot_lda <- function(lda_df) {
  ggplot(lda_df, aes(x = LD1, y = LD2, color = Group, fill = Group)) +
    geom_point(size = 3, shape = 21, stroke = 1) +
    stat_ellipse(geom = "polygon", alpha = 0.2, color = NA) +
    theme_minimal(base_size = 14) +
    labs(
      title = "Functional feature space (LDA)",
      subtitle = "Comparative genomics-based functional positioning",
      x = "LD1", y = "LD2"
    )
}

# ================================
# 📤 6. Export classification
# ================================
export_results <- function(mat, group_labels, reference_strain, output_file) {
  
  zs <- mat[, reference_strain]
  
  df <- data.frame(
    Feature = rownames(mat),
    Zscore = zs,
    Group = group_labels
  )
  
  write_xlsx(df, output_file)
}

# ================================
# ▶️ 7. Run pipeline
# ================================
file_path <- "data/zscores.xlsx"
reference_strain <- "Streptomyces_n2a_total"

mat <- load_zscore_matrix(file_path)
mat_imp <- impute_matrix(mat)

groups <- classify_features(mat_imp, reference_strain)

lda_df <- run_lda(mat_imp, groups)

plot <- plot_lda(lda_df)
print(plot)

export_results(mat_imp, groups, reference_strain, 
               "results/functional_classification.xlsx")