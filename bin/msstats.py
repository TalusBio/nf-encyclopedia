#!/usr/bin/env python3
"""Run MSstats"""
import re

import click
import pandas as pd
from rpy2.robjects.packages import importr
from rpy2.robjects import pandas2ri


def encyclopedia_to_msstats(peptides_txt):
    """Convert EncyclopeDIA peptides.txt to an MStats compatible format.

    Parameters
    ----------
    peptides : str of Path
        The path to the Encyclopedia peptides.txt

    Returns
    -------
    pandas.DataFrame
        The data to analyze with MSstats
    """
    peptides_df = (
        pd.read_table(peptides_txt)
        .reset_index(drop=True)
        .rename(
            columns={
                "run": "Run",
                "intensity": "Intensity",
                "Peptide": "PeptideModifiedSequence",
                "Protein": "ProteinName",
            }
        )
        .sort_values(by=["PeptideModifiedSequence", "Intensity"])
    )

    prev = len(peptide_df)
    peptide_df = peptide_df.drop_duplicates()
    if prev != len(peptide_df):
        raise RuntimeError(f"Prev: {prev}, Now: {len(peptide_df)}")

    peptide_df["BioReplicate"] = peptide_df["Run"]
    peptide_df["Condition"] = (
        peptide_df.loc[:, group_cols]
        .astype(str)
        .apply("|".join, axis=1)
    )

    peptide_df["PrecursorCharge"] = 2
    peptide_df["IsotopeLabelType"] = "L"
    peptide_df["FragmentIon"] = "y0"
    peptide_df["ProductCharge"] = 1
    peptide_df["PeptideSequence"] = (
        peptide_df["PeptideModifiedSequence"]
        .str.replace(r"[\[\(].*?[\]\)]", "", regex=True)
    )

    keep = [
        "PeptideSequence",
        "PeptideModifiedSequence",
        "ProteinName",
        "Run",
        "BioReplicate",
        "Condition",
        "Intensity",
        "PrecursorCharge",
        "IsotopeLabelType",
        "FragmentIon",
        "ProductCharge",
    ]



@click.command()
@click.argument("peptides_txt")
def main(peptides_txt):
    """The main function."""
    pandas2ri.activate()
    base = importr("base")
    MSstats = importr("MSstats")
    peptide_df = encyclopedia_to_msstats(peptides_txt)
    raw = MSstats.SkylinetoMSstatsFormat(
        peptide_df,
        filter_with_Qvalue=False,
        use_log_file=False,
    )
    processed = MSstats.dataProcess(
        raw,
        censoredInt="0",
        use_log_file=False
    )

    peptide_df.to_csv("msstats_input.csv")
    base.save(processed, file="msstats_processed.rda")


if __name__ == "__main__":
    main()
