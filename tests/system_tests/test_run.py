"""Test on real data"""
import subprocess

import pytest

#@pytest.mark.skip("Doesn't work yet.")
def test_run(real_data, tmp_path):
    """Test the workflow on real data"""
    config, _ = real_data
    cmd = ["nextflow", "run", "main.nf"] + config
    subprocess.run(cmd, check=True)


def test_walnut_run(real_data, tmp_path):
    """Test the workflow on real data"""
    config, _ = real_data

    # Remove dlib:
    dlib_idx = [i for i, c in enumerate(config) if c == "--dlib"][0]
    del config[dlib_idx:dlib_idx+2]

    cmd = ["nextflow", "run", "main.nf"] + config
    subprocess.run(cmd, check=True)
