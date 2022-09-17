"""Fixtures for test"""
import random
from pathlib import Path

import pytest
import numpy as np
import pandas as pd


@pytest.fixture
def base_project(tmp_path):
    """A base project to use for testing"""
    # Create raw files
    raw_dir = tmp_path / "subdir"
    raw_dir.mkdir()
    raw_files = [raw_dir / f"{f}.raw" for f in "abcdefghijklm"]
    for raw_file in raw_files:
        raw_file.touch()

    mzml_file = raw_dir / "n.mzML.gz"
    mzml_file.touch()
    raw_files.append(mzml_file)

    chrlibs = ["true"] * 6 + ["false"] * 8
    groups = "xy" * 6 + "z" * 2

    # create an input csv
    ms_files = ["file,chrlib,group"]
    for row in zip(raw_files, chrlibs, groups):
        row = list(row)
        row[0] = str(row[0])
        ms_files.append(",".join(row))

    ms_files_csv = tmp_path / "ms_files.csv"
    with ms_files_csv.open("w+") as fhndl:
        fhndl.write("\n".join(ms_files))

    ms_files_csv_short = tmp_path / "ms_files_short.csv"
    with ms_files_csv_short.open("w+") as fhndl:
        fhndl.write("\n".join(ms_files[1:4] + ms_files[7:10]))

    # FASTA
    fasta_file = tmp_path / "test.fasta"
    fasta_file.touch()

    # DLIB
    dlib_file = tmp_path / "dlib.fasta"
    dlib_file.touch()

    # Config:
    config = [
        "-profile", "standard",
        "-without-docker",
        "-stub-run",
        "-w", str(tmp_path / "work"),
        "--result_dir", str(tmp_path / "results"),
        "--mzml_dir", str(tmp_path / "mzml"),
        "--fasta", str(fasta_file),
        "--dlib", str(dlib_file),
        "--ms_file_csv", str(ms_files_csv),
        "--max_memory", "4.GB",
        "--max_cpus", "1",
    ]

    return config, ms_files_csv, ms_files_csv_short


@pytest.fixture
def real_data(tmp_path):
    """Test using small mzML files."""
    fasta_file = Path("tests/data/small-yeast.fasta")
    dlib_file = Path("tests/data/small-yeast.dlib")

    # create an input csv
    ms_files = ["file,chrlib,group"]
    for mzml_file in Path("tests/data").glob("*.mzML.gz"):
        ms_files.append(",".join([str(mzml_file), "false", "test"]))

    ms_files_csv = tmp_path / "ms_files.csv"
    with ms_files_csv.open("w+") as fhndl:
        fhndl.write("\n".join(ms_files))

    # Config:
    config = [
        "-w", str(tmp_path / "work"),
        "-c", "conf/test.config",
        "--result_dir", str(tmp_path / "results"),
        "--mzml_dir", str(tmp_path / "mzml"),
        "--fasta", str(fasta_file),
        "--dlib", str(dlib_file),
        "--ms_file_csv", str(ms_files_csv),
    ]

    return config, ms_files_csv


@pytest.fixture
def enc_peptides_txt(tmp_path):
    """A simulated peptide.txt file from EncyclopeDIA with corresponding
    annotations and contrasts.
    """
    rng = np.random.default_rng(42)
    random.seed(1)

    n_peptides = 100

    alpha = list("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
    peps = ["".join(random.choices(alpha, k=10)) for _ in range(n_peptides)]
    prots = ["".join(random.choices(alpha, k=2)) for _ in range(n_peptides)]
    quants = rng.normal(0, 1, size=(n_peptides, len(alpha))) ** 2 * 1e5
    mzml = [a + ".mzML" for a in alpha]
    raw = ["s3://stuff/blah/" + a + ".raw" for a in alpha]

    # The peptides.txt file:
    quant_df = pd.DataFrame(quants, columns=mzml)
    meta_df = pd.DataFrame(
        {"Peptide": peps, "Protein": prots, "numFragments": 1}
    )

    peptide_df = pd.concat([quant_df, meta_df], axis=1)
    peptide_file = tmp_path / "encyclopedia.peptides.txt"
    peptide_df.to_csv(peptide_file, sep="\t", index=False)

    # The annotation file:
    n_group = int(len(raw) // 2)
    input_df = pd.DataFrame({"file": raw, "chrlib": False, "group": "default"})
    input_df["condition"] = ["A"] * n_group + ["B"] * (len(raw) - n_group)
    input_file = tmp_path / "input.csv"
    input_df.to_csv(input_file, index=False)

    # contrasts:
    contrast_df = pd.DataFrame([(-1, 1)], columns=["A", "B"], index=["test"])
    contrast_file = tmp_path / "contrasts.csv"
    contrast_df.to_csv(contrast_file)

    return peptide_file, input_file, contrast_file
