process MSCONVERT {
    publishDir "${params.mzml_dir}/${outputDir}", mode: "copy"
    storeDir "${params.store_dir}/${outputDir}"

    input:
        tuple val(file_id), path(raw_input), val(outputDir)

    output:
        tuple val(file_id), path("${raw_input.baseName}.mzML.gz")

    script:
    """
    wine msconvert \\
        ${params.msconvert.verbose} \\
        ${params.msconvert.options} \\
        ${params.msconvert.gzip} \\
        ${params.msconvert.filters} \\
        ${raw_input}
    """

    stub:
    """
    touch ${raw_input.baseName}.mzML.gz
    """
}
