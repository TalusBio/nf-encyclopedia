#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

process unique_peptides_proteins {
    echo true
    publishDir "${params.experimentBucket}/${params.experimentName}/encyclopedia", mode: "copy"

    input:
        path elib_files
    output:
        path("unique_peptides_proteins.csv")
    script:
    """
    python3 /app/src/unique_peptides_proteins.py -g "./*.mzML.elib" -t encyclopedia
    """
}

workflow {
    files = Channel.fromPath("experiment-bucket/blue-sparrow/encyclopedia/*")
    files | flatten | filter { it.name =~ /.*mzML.elib$/ } | collect | unique_peptides_proteins | view
}