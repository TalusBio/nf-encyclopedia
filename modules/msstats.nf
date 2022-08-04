process MSSTATS {
    publishDir "${params.result_dir}/${group}", failOnError: true
    label 'process_medium'

    input:
        tuple val(group), path(quant_peptides)

    output:
        tuple(
            val(group),
            path("msstats_input.csv"),
            path("msstats_processed.rda")
        )

    script:
    """
    python msstats.py ${quant_peptides}
    """

    stub:
    """
    touch msstats_input.csv
    touch msstats_processed.rda
    """
}
