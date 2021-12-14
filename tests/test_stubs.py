"""Do a quick stub run to make sure things are working"""
import subprocess
from pathlib import Path


def test_stubs(tmp_path):
    """Test the workflow logic"""
    print(tmp_path)
    cmd = [
        "nextflow", "run", "main.nf",
        "-c", "tests/data/test.config",
        "-profile", "standard",
        "-without-docker",
        "-stub-run",
        "-w", str(tmp_path / "work"),
        "--publish_dir", str(tmp_path / "results"),
        "--mzml_dir", str(tmp_path / "mzml"),
    ]

    subprocess.run(cmd, check=True)


def test_already_converted(tmp_path):
    """Test that already converted mzML files are cont conveted again."""
    mzml_dir = (tmp_path / "mzml" / "experiment")
    mzml_dir.mkdir(parents=True)
    mzml = mzml_dir / "a.mzML.gz"
    mzml.touch()
    old = mzml.stat()
    test_stubs(tmp_path=tmp_path)

    assert old == mzml.stat()
    assert (mzml_dir / "b.mzML.gz").exists()
