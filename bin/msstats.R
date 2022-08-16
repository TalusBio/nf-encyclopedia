#!/usr/bin/env Rscript
library(dplyr)
library(tidyr)
library(magrittr)
library(MSstats)


# Convert EncyclopeDIA results to a format for MSstats
encyclopediaToMsstats <- function(peptides_txt) {
  id_vars <- c("Peptide", "Protein", "numFragments")
  
  df <- read.table(peptides_txt, sep = '\t', header = TRUE) %>% 
    pivot_longer(names(.)[!names(.) %in% id_vars], 
                 names_to = "run",
                 values_to = "intensity") %>%
    mutate(run = sub("\\.mzML$", "", run)) %>%
    rename(Run = run,
           Intensity = intensity,
           PeptideModifiedSequence = Peptide,
           ProteinName = Protein) %>%
    arrange(PeptideModifiedSequence, Intensity) %>%
    mutate(BioReplicate = Run,
           Condition = "unknown",
           PrecursorCharge = 2,
           IsotopeLabelType = "L",
           FragmentIon = "y0",
           ProductCharge = 1,
           PeptideSequence = sub("[\\[\\(].*?[\\]\\)]", "", PeptideModifiedSequence)) %>%
    select(PeptideSequence,
           PeptideModifiedSequence,
           ProteinName,
           Run,
           BioReplicate,
           Condition,
           Intensity,
           PrecursorCharge,
           IsotopeLabelType,
           FragmentIon,
           ProductCharge)

  df
}


# The main function:
main <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  peptides_txt <- args[1]
  
  if (length(args) > 1) { 
    annot <- args[2]
  } else {
    annot <- NULL
  }
  
  peptide_df <- encyclopediaToMsstats(peptides_txt)
  write.table(peptide_df, 
              file = "msstats_input.txt",
              sep = "\t",
              row.names = FALSE,
              quote = FALSE)
  
  raw <- SkylinetoMSstatsFormat(peptide_df,
                                annotation = annot,
                                filter_with_Qvalue = FALSE,
                                censoredInt = "0",
                                use_log_file = FALSE)

  processed <- dataProcess(raw,
                           censoredInt = "0",
                           use_log_file = FALSE)

  save(processed, file = "msstats_processed.rda")
}


main()
