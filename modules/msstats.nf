process MSSTATS {
    debug true
    publishDir "${params.publish_dir}/${group}", mode: "copy"

    input:
    tuple val(group), path(quant_peptides), path(ms_file_csv)

    output:
    tuple(
        val(group),
        path("msstats_input.csv"),
        path("msstats_feature_level_data.csv")
    )

    script:
    """
    python /app/src/msstats.py ${quant_peptides} ${ms_file_csv}
    """

    stub:
    """
    touch msstats_input.csv
    touch msstats_processed.rda
    """
}
