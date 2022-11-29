
FROM --platform=linux/amd64 ghcr.io/talusbio/nf-encyclopedia:latest
RUN apt update && apt install default-jdk-headless git docker -y
ENV JAVA_HOME=/usr/lib/jvm/java-1*-openjdk-amd64
ENV PATH="/usr/bin:$PATH"
RUN export -n _JAVA_OPTIONS
RUN unset _JAVA_OPTIONS ; cd /bin && curl -s https://get.nextflow.io | bash