process MSSTATS {
    publishDir "${params.result_dir}/${group}/msstats", failOnError: true
    label 'process_medium'

    input:
        tuple val(group), path(quant_peptides)

    output:
        tuple(
            val(group),
            path("msstats_input.txt"),
            path("msstats_processed.rda")
        )

    script:
    """
    msstats.R ${quant_peptides}
    """

    stub:
    """
    touch msstats_input.txt
    touch msstats_processed.rda
    """
}
