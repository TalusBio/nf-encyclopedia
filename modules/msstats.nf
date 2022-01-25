#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

process msstats {
    echo true
    publishDir params.publish_dir, mode: "copy"

    input:
        path quant_peptides
    output:
        tuple(
            path("msstats_input.csv"),
            path("msstats_feature_level_data.csv")
        )

    script:
    """
    python /app/src/msstats.py -f ${quant_peptides} -t encyclopedia
    """

    stub:
    """
    touch msstats_input.csv
    touch msstats_feature_level_data.csv
    """
}

workflow {
    files = Channel.fromPath("result-quant.elib.peptides.txt")
        | msstats
        | view
}