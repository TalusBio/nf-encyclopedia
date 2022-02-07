"""Do a quick stub run to make sure things are working"""
import subprocess


def test_no_aggregate(base_project, tmp_path):
    """Test the workflow logic for per experiment workflows"""
    config, *_ = base_project
    cmd = ["nextflow", "run", "main.nf"] + config
    subprocess.run(cmd, check=True)

    base = tmp_path / "results"
    expected = [
        base / "x" / "result-quant.elib",
        base / "y" / "result-quant.elib",
        base / "z" / "result-quant.elib",
        base / "x" / "result-chr.elib",
        base / "y" / "result-chr.elib",
    ]

    for fname in expected:
        assert fname.exists()

    not_expected = base / "global" / "result-global.elib"
    assert not not_expected.exists()


def test_aggregate(base_project, tmp_path):
    """Test workflow logic for global analyses."""
    config, *_ = base_project

    cmd = [
        "nextflow", "run", "main.nf",
        "--aggregate", "true",
    ]

    cmd += config

    subprocess.run(cmd, check=True)

    base = tmp_path / "results"
    not_expected = [
        base / "x" / "result-quant.elib",
        base / "y" / "result-quant.elib",
        base / "z" / "result-quant.elib",
    ]

    for fname in not_expected:
        assert not fname.exists()

    expected = base / "global" / "result-global.elib"
    assert expected.exists()


def test_already_converted(base_project, tmp_path):
    """Test that already converted mzML files are not converted again."""
    mzml_dir = (tmp_path / "mzml" / "experiment")
    mzml_dir.mkdir(parents=True)
    mzml = mzml_dir / "a.mzML.gz"
    mzml.touch()
    old = mzml.stat()
    test_no_aggregate(base_project=base_project, tmp_path=tmp_path)

    assert old == mzml.stat()
    assert (mzml_dir / "b.mzML.gz").exists()
