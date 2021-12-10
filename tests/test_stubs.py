"""Do a quick stub run to make sure things are working"""
import subprocess


def test_stubs(tmp_path):
    """Test the workflow logic"""
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
