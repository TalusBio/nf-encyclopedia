"""Test the MSstats script"""
import logging
import subprocess
from pathlib import Path

import pytest
import pandas as pd

OUTPUTS = [
    Path("msstats.input.txt"),
    Path("msstats.processed.rda"),
    Path("msstats.proteins.txt"),
    Path("msstats.stats.txt"),
    Path("QCPlot.pdf"),
]


def test_reports(msstats_input, script):
    """Test without reports"""
    peptide_file, annot_file, contrast_file = msstats_input
    args = [
        script,
        peptide_file,
        annot_file,
        contrast_file,
        "equalizeMedians",
        "true",
    ]

    subprocess.run(args, check=True)
    _file_created(*OUTPUTS, exists=True)


def test_no_reports(msstats_input, script):
    """Test without reports"""
    peptide_file, annot_file, contrast_file = msstats_input
    args = [
        script,
        peptide_file,
        annot_file,
        contrast_file,
        "equalizeMedians",
        "false",
    ]

    subprocess.run(args, check=True)
    _file_created(*OUTPUTS[:4], exists=True)
    _file_created(*OUTPUTS[4:], exists=False)


def test_bad_norm(msstats_input, script):
    """Test without reports"""
    peptide_file, annot_file, contrast_file = msstats_input
    args = [
        script,
        peptide_file,
        annot_file,
        "NO_FILE",
        "blah",
        "false",
    ]

    with pytest.raises(subprocess.CalledProcessError):
        subprocess.run(args, check=True)


def test_no_contrasts(msstats_input, script):
    """Test without reports"""
    peptide_file, annot_file, contrast_file = msstats_input
    args = [
        script,
        peptide_file,
        annot_file,
        "NO_FILE",
        "equalizeMedians",
        "true",
    ]

    subprocess.run(args, check=True)
    _file_created(*OUTPUTS[:3], OUTPUTS[4], exists=True)
    _file_created(OUTPUTS[3], exists=False)


def test_input(script, msstats_input):
    """Test that the script formats the input correctly."""
    peptide_file, annot_file, contrast_file = msstats_input
    args = [
        script,
        peptide_file,
        annot_file,
        "NO_FILE",
        "none",
        "false",
    ]
    subprocess.run(args, check=True)
    input_df = pd.read_table("msstats.input.txt")

    assert input_df.shape == (64, 11)
    assert input_df["Run"].tolist() == input_df["BioReplicate"].tolist()

    # Check group merging:
    in_group1 = input_df["Run"].isin(["W", "X"])
    assert (input_df.loc[in_group1, "Condition"] == "C").all()
    assert (input_df.loc[~in_group1, "Condition"] == "D").all()

    # Static fields:
    assert (input_df["PrecursorCharge"] == 2).all()
    assert (input_df["IsotopeLabelType"] == "L").all()
    assert (input_df["FragmentIon"] == "y0").all()
    assert (input_df["ProductCharge"] == 1).all()


def test_input_with_bioreplicate(script, msstats_input):
    """Test the optional specification of BioReplicate"""
    peptide_file, annot_file, contrast_file = msstats_input

    # Test annotations with BioReplicates:
    annot_df = pd.read_csv(annot_file)
    annot_df["bioreplicate"] = 1
    annot_df.to_csv(annot_file, index=False)

    args = [
        script,
        peptide_file,
        annot_file,
        "NO_FILE",
        "none",
        "false",
    ]

    subprocess.run(args, check=True)
    input_df = pd.read_table("msstats.input.txt")
    assert (input_df["BioReplicate"] == 1).all()


def _file_created(*args, exists=True):
    """Test whether one or more files exist."""
    for fname in args:
        if exists:
            assert fname.exists(), f"{fname.name} does not exist."
        else:
            assert not fname.exists(), f"{fname.name} exists."


@pytest.fixture
def script(monkeypatch, tmp_path):
    """Set the working directory"""
    script_path = Path("bin/msstats.R").resolve()
    monkeypatch.syspath_prepend(script_path)
    monkeypatch.chdir(tmp_path)
    return script_path
