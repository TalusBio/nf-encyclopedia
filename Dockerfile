FROM --platform=linux/amd64 mambaorg/micromamba:latest as micromamba
# FROM --platform=linux/amd64 ibmjava:11
# FROM --platform=linux/amd64 amazoncorretto:11-al2023-headless # Uses yum for package management.
FROM --platform=linux/amd64 nextflow/nextflow:23.04.2

ARG VERSION=2.12.30
ENV VERSION ${VERSION}
LABEL authors="wfondrie@talus.bio" \
      description="Docker image for most of nf-encyclopedia"


# Install procps so that Nextflow can poll CPU usage and
# deep clean the apt cache to reduce image/layer size
# RUN apt-get install -y procps sqlite3 libgomp1 \
#     && apt-get clean -y && rm -rf /var/lib/apt/lists/*
RUN yum install -y wget


WORKDIR /code
# First Stage of the build, gets the jar for encyclopedia
RUN wget https://bitbucket.org/searleb/encyclopedia/downloads/encyclopedia-${VERSION}-executable.jar

# # Install nextflow
# RUN wget -qO- https://get.nextflow.io | bash
# RUN chmod +x nextflow
# RUN mv nextflow /usr/local/bin/.

WORKDIR /app

# Setup micromamba:
ARG MAMBA_USER=root
ARG MAMBA_USER_ID=1000
ARG MAMBA_USER_GID=1000
ARG MAMBA_DOCKERFILE_ACTIVATE=1
ENV MAMBA_USER=$MAMBA_USER
ENV MAMBA_ROOT_PREFIX="/opt/conda"
ENV MAMBA_EXE="/bin/micromamba"
RUN mkdir -p ${MAMBA_ROOT_PREFIX} 

COPY --from=micromamba "$MAMBA_EXE" "$MAMBA_EXE"
COPY --from=micromamba /usr/local/bin/_activate_current_env.sh /usr/local/bin/_activate_current_env.sh
COPY --from=micromamba /usr/local/bin/_dockerfile_shell.sh /usr/local/bin/_dockerfile_shell.sh
COPY --from=micromamba /usr/local/bin/_entrypoint.sh /usr/local/bin/mamba_entrypoint.sh
COPY --from=micromamba /usr/local/bin/_activate_current_env.sh /usr/local/bin/_activate_current_env.sh
COPY --from=micromamba /usr/local/bin/_dockerfile_initialize_user_accounts.sh /usr/local/bin/_dockerfile_initialize_user_accounts.sh
COPY --from=micromamba /usr/local/bin/_dockerfile_setup_root_prefix.sh /usr/local/bin/_dockerfile_setup_root_prefix.sh

# No need to set up accounts if we will run as root ...
# RUN /usr/local/bin/_dockerfile_initialize_user_accounts.sh &&

RUN /usr/local/bin/_dockerfile_setup_root_prefix.sh

# Setup the environment
USER $MAMBA_USER
COPY environment.yml /tmp/environment.yml

# Instruct R processes to use these empty files instead of
# clashing with a local one
RUN touch .Rprofile .Renviron

# Set the path. NextFlow seems to circumvent the conda environment
# We also need to set options for the JRE here.
ENV PATH="$MAMBA_ROOT_PREFIX/bin:$PATH:/bin" _JAVA_OPTIONS="-Djava.awt.headless=true" VERSION=$VERSION

# Setup the EncyclopeDIA executable:
RUN ln -s /code/encyclopedia-$VERSION-executable.jar /code/encyclopedia.jar

# Create the entrypoint:
# SHELL ["/usr/local/bin/_dockerfile_shell.sh"]
# ENTRYPOINT ["/usr/local/bin/mamba_entrypoint.sh", "/usr/local/bin/entry.sh"]

# Create the environment
RUN micromamba install -y -n base -f /tmp/environment.yml && \
    micromamba clean --all --yes

CMD ["/bin/bash"]

