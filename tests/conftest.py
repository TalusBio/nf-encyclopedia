"""Fixtures for test"""
from pathlib import Path

import pytest


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
        "-with-docker", "nf-encyclopedia", # Built from Dockerfile.
        "--result_dir", str(tmp_path / "results"),
        "--mzml_dir", str(tmp_path / "mzml"),
        "--fasta", str(fasta_file),
        "--dlib", str(dlib_file),
        "--ms_file_csv", str(ms_files_csv),
    ]

    return config, ms_files_csv
