"""Test the MSstats script"""
import subprocess
from pathlib import Path

import pytest

MSSTATS = "bin/msstats.R"
OUTPUTS = [
    Path("msstats.input.txt"),
    Path("msstats.processed.rda"),
    Path("msstats.proteins.txt"),
    Path("msstats.stats.txt"),
    Path("QCPlot.pdf"),
    Path("VolcanoPlot.pdf")
]


def test_no_reports(msstats_input):
    """Test without reports"""
    peptide_file, annot_file, contrast_file = msstats_input
    args = [
        MSSTATS,
        peptide_file,
        annot_file,
        contrast_file,
        "equalizeMedians",
        "false",
    ]

    subprocess.run(args, check=True)
    for output in OUTPUTS[:-2]:
        assert output.exists
