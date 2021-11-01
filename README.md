# Talus Data Pipeline - Encyclopedia

Running Nextflow on AWS:
https://t-neumann.github.io/pipelines/AWS-pipeline/

# Release
```
# See existing tags
git tag

# Create a new tag
git tag -a v0.0.1 -m "First version"

# Push to new tag
git push origin "v0.0.1"
```

# Issues
## Command `aws` cannot be found
Problem:
When creating the custom AMI, make sure to install the aws-cli outside of the /usr/ directory. During the docker mount it will overwrite it and render the docker image content unusable. 

Solution: 
Install the `aws` tool at `/home/ec2-user/bin/aws`. 

Also mentioned here: https://github.com/nextflow-io/nextflow/issues/2322

## Command 'ps' required by nextflow to collect task metrics cannot be found
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
