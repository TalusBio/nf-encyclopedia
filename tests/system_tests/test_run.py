"""Test on real data"""
import subprocess


def test_run(real_data, tmp_path):
    """Test the workflow on real data"""
    config, _ = real_data
    cmd = ["nextflow", "run", "main.nf"] + config
    subprocess.run(cmd, check=True)
