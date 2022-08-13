FROM mambaorg/micromamba:latest
LABEL authors="wfondrie@talus.bio" \
      description="Docker image for most of nf-encyclopedia"

USER root
COPY environment.yml /tmp/environment.yml

# Install procps so that Nextflow can poll CPU usage and
# deep clean the apt cache to reduce image/layer size
RUN apt-get update \
    && apt-get install -y procps \
    && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Instruct R processes to use these empty files instead of
# clashing with a local one
RUN touch .Rprofile .Renviron

# Create the environment
RUN micromamba install -y -n base -f /tmp/environment.yml && \
    micromamba clean --all --yes

# Set the path. NextFlow seems to circumvent the conda environment
ENV PATH "$MAMBA_ROOT_PREFIX/bin:$PATH"
