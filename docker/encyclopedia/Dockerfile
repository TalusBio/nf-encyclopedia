FROM proteowizard/panorama-encyclopedia:latest

RUN apt-get update \
    && apt-get install python3-pip -y

RUN pip3 install awscli==1.18.176 botocore==1.19.16

WORKDIR /app