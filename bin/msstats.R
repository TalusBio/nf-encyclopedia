#!/usr/bin/env Rscript
library(rlang)
library(dplyr, warn.conflicts = FALSE)
library(tidyr, warn.conflicts = FALSE)
library(stringr, warn.conflicts = FALSE)
library(magrittr, warn.conflicts = FALSE)
library(MSstats, warn.conflicts = FALSE)


# Convert EncyclopeDIA results to a format for MSstats
encyclopediaToMsstats <- function(peptides_txt) {
  id_vars <- c("Peptide", "Protein", "numFragments")

  df <- read.table(peptides_txt,
                   sep = '\t',
                   header = TRUE,
                   stringsAsFactors = FALSE,
                   check.names = FALSE) %>%
    pivot_longer(names(.)[!names(.) %in% id_vars],
                 names_to = "run",
                 values_to = "intensity") %>%
    mutate(run = str_replace(run, "\\.mzML$", "")) %>%
    rename(Run = run,
           Intensity = intensity,
           PeptideModifiedSequence = Peptide,
           ProteinName = Protein) %>%
    arrange(PeptideModifiedSequence, Intensity) %>%
    mutate(PrecursorCharge = 2,
           IsotopeLabelType = "L",
           FragmentIon = "y0",
           ProductCharge = 1,
           PeptideSequence =
             str_replace(PeptideModifiedSequence, "[\\[\\(].*?[\\]\\)]", "")) %>%
    select(PeptideSequence,
           PeptideModifiedSequence,
           ProteinName,
           Run,
           Intensity,
           PrecursorCharge,
           IsotopeLabelType,
           FragmentIon,
           ProductCharge)

  return(df)
}


# Parse the annotation file.
annotate <- function(peptide_df, annot_csv) {
  annot_df <- read.csv(annot_csv, header = TRUE, stringsAsFactors = FALSE) %>%
    mutate(file = str_replace(basename(file),"\\.[^\\.]*?[\\.gz]*$", "")) %>%
    fill_column(condition, "unknown") %>%
    fill_column(bioreplicate, file) %>%
    rename(Run = file,
           Condition = condition,
           BioReplicate = bioreplicate) %>%
    select(c("Run", "Condition", "BioReplicate"))

  return(left_join(peptide_df, annot_df, by="Run"))
}


# Test if a column exists and create it if it doesn't.
fill_column <- function(df, column, backup) {
  var_name <- englue("{{column}}")
  if (!(var_name %in% names(df))) {
    df <- mutate(df, "{{ column }}" := {{ backup }})
  }
  return(df)
}


# The main function
main <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  peptides_txt <- args[1]
  input_csv <- args[2]
  contrasts <- args[3] # 'NO_FILE' if missing.
  normalization <- args[4]
  reports <- as.logical(args[5])

  # Parse the normalization:
  if(tolower(normalization) == "none") normalization <- FALSE

  # Read the data and add annotations:
  peptide_df <- encyclopediaToMsstats(peptides_txt) %>%
    annotate(input_csv)

  write.table(peptide_df,
              file = "msstats/msstats.input.txt",
              sep = "\t",
              row.names = FALSE,
              quote = FALSE)

  # Read into an MSstats format:
  raw <- SkylinetoMSstatsFormat(peptide_df,
                                filter_with_Qvalue = FALSE,
                                censoredInt = "0",
                                use_log_file = FALSE)

  # Process and normalize:
  processed <- dataProcess(raw,
                           censoredInt = "0",
                           normalization = normalization,
                           use_log_file = FALSE)
  save(processed, file = "msstats/msstats.processed.rda")

  # Get quantified proteins:
  quants <- quantification(processed, use_log_file = FALSE)
  write.table(quants,
              "msstats.proteins.txt",
              row.names = TRUE,
              quote = FALSE,
              sep = "\t")

  # Perform hypothesis tests:
  if(contrasts != "NO_FILE") {
    contrast_mat <- read.csv(contrasts, row.names = 1)
    diffexp <- groupComparison(contrast_mat, processed, use_log_file=FALSE)
    write.table(diffexp$ComparisonResult,
                "msstats.stats.txt",
                quote = FALSE,
                sep = "\t")
  }

  if(reports) {
    dataProcessPlots(processed, "QCPlot")
    #if (contrasts != "NO_FILE") groupComparisonPlots(diffexp, "VolcanoPlot")
  }
}


main()
