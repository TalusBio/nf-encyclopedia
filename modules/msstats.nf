#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

process msstats {
    echo true
    publishDir params.publish_dir, mode: "copy"

    input:
        path quant_peptides
    output:
        tuple(
            path("peptides_proteins_results.csv")
            path("peptides_proteins_msstats.csv")
        )

    script:
    """
    python3 /app/src/msstats.py -f ${quant_peptides} -t encyclopedia
    """

    stub:
    """
    touch peptides_proteins_results.csv
    touch peptides_proteins_msstats.csv
    """
}

workflow {
    files = Channel.fromPath("${params.publish_dir}/*")
        | flatten
        | filter { it.name =~ /.*mzML.elib$/ }
        | collect
        | msstats
        | view
}
