"""Test the MSstats script"""
import logging
import subprocess
from pathlib import Path

import pytest

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
