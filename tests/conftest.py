"""Fixtures for test"""
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

    chrlibs = ["true"] * 6 + ["false"] * 7
    groups = "xy" * 6 + "z"


    # create an input csv
    ms_files = ["file,chrlib,group,condition,bioreplicate"]
    for i, row in enumerate(zip(raw_files, chrlibs, groups)):
        row = list(row) + ["blah", str(i)]
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
        "--publish_dir", str(tmp_path / "results"),
        "--mzml_dir", str(tmp_path / "mzml"),
        "--email", "''",
        "--encyclopedia.fasta", str(fasta_file),
        "--encyclopedia.dlib", str(dlib_file),
        "--ms_file_csv", str(ms_files_csv),
    ]

    return config, ms_files_csv, ms_files_csv_short
