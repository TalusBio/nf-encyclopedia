process MSSTATS {
    echo true
    publishDir "${params.publish_dir}/${group}", mode: "copy"

    input:
    tuple val(group), path(quant_peptides)

    output:
    tuple(
        val(group),
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
