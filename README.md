# NextFlow - EncyclopeDIA

This repository contains Talus' NextFlow pipeline for EncyclopeDIA. It connects three open-source tools---msconvert, EncylopeDIA, and MSstats---to go from raw mass spectrometry data to quantified peptides and proteins that are ready for statistical analysis. 

## Dependencies
To run the pipeline locally, you'll need these dependencies:
- [NextFlow](https://www.nextflow.io/) - Personally I install it using conda:

``` sh
conda install -c bioconda nextflow
```

- [Docker](https://www.docker.com/)[^1] - On my Mac, I install it with [Homebrew](https://brew.sh/)

``` sh
brew install docker
```

[^1]: Note that Docker is only required to really run the pipeline. Testing using NextFlow process stubs can be done without it.

## Usage
Generally, we launch this pipeline from our [pipeline launcher](https://share.streamlit.io/talusbio/talus-pipeline-launcher/main/apps/pipeline_launcher.py). However, it can be launched like any other NextFlow pipeline locally:

``` sh
nextflow run /path/to/nf-encyclopedia --<parameters>
```

Where `<parameters>` are the pipeline parameters. The pipeline has 3 required parameters:

- `ms_file_csv` - A comma-separated values (CSV) file containing the raw mass spectrometry data files. It is required to have 4 columns: `file`, `chrlib`, and `group`.
  * `file` specifies the path of a raw MS data file.
  * `chrlib` is either `true` or `false` and specifies whether the file is part of a chromatogram library ("library files") or used for quantitation ("quant files"), respectively.
  * `group` specifies an experiment group. Quant files will searched only using library files from the same group. Any group with no library files will be searched directly with the DLIB instead. Additionally, the group will specify a subdirectory in which the pipeline results will be written. 
  * `condition` is used by comparisons with MSstats.
  
  
  An example of such a file would be:
```
      file, chrlib, group, condition
data/a.raw,   true,     x,      pool
data/b.raw,   true,     y,      pool
data/c.raw,  false,     x,      case
data/d.raw,  false,     y,   control
data/e.raw,  false,     z,      case
```

- `encyclopedia.fasta` - The FASTA file of protein sequences for EncyclopeDIA to use. This must match the provided DLIB.

- `encyclopedia.dlib` - The spectral library for EncyclopeDIA to use, in the DLIB format.

Other important optional parameters are:

- `aggregate` is either `true` or `false` (default: `false`). When set to `true`, the pipeline will perform a single global EncyclopeDIA analysis encompassing all of the quant files. When set to `false`, a global EncyclopeDIA analysis is conducted for each experiment. 

## Development
### Running Tests
We use the [pytest](https://docs.pytest.org/en/7.0.x/contents.html) Python package to run our tests. It can be installed either with either pip:

```sh
pip install pytest
```

or conda:

``` sh
conda install pytest
```

Once installed, tests can be run from the root directory of the workflow. These tests use the process stubs to test the workflow logic, but do not test the commands for the tools themselves. Run them with:

``` sh
pytest
```


### Git Flow
We use git flow for features, releases, fixes, etc. Here's an introductory article: https://jeffkreeftmeijer.com/git-flow/.
And a cheatsheet: https://danielkummer.github.io/git-flow-cheatsheet/index.html.

### Releases
```
# See existing tags
git tag

# Create a new tag
git tag -a v0.0.1 -m "First version"

# Push to new tag
git push origin "v0.0.1"
```

## Known Issues
### Command `aws` cannot be found
Problem:
When creating the custom AMI, make sure to install the aws-cli outside of the /usr/ directory. During the docker mount it will overwrite it and render the docker image content unusable. 

Solution: 
Install the `aws` tool at `/home/ec2-user/bin/aws`:
```
# https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2-linux.html
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install -b /home/ec2-user/bin
aws --version
```

Also mentioned here: https://github.com/nextflow-io/nextflow/issues/2322

### Command 'ps' required by nextflow to collect task metrics cannot be found
Problem: 
Nextflow needs certain tools installed on the system to collect metrics: https://www.nextflow.io/docs/latest/tracing.html#tasks.

Solution:
Install `ps` in the docker image, e.g.
```
RUN apt-get update && \
    apt-get install procps -y && \
    apt-get clean
```

Also mentioned here:
https://github.com/replikation/What_the_Phage/issues/89

## Resources
- Running Nextflow on AWS - https://t-neumann.github.io/pipelines/AWS-pipeline/
- Getting started with Nextflow - https://carpentries-incubator.github.io/workflows-nextflow/aio/index.html
