#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

process run_msconvert {
    echo true
    publishDir "${params.mzml_dir}/${outputDir}", mode: "copy"

    input:
        tuple path(raw_input), val(outputDir)
    output:
        path("${raw_input.baseName}.mzML.gz")

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

workflow msconvert {
    take: 
        raw_files
    main:
        raw_files
            | map { raw -> [raw, raw.getParent().getBaseName()] }
            | branch {
                mzml_present: file("${params.mzml_dir}/${it[1]}/${it[0].baseName}.mzML.gz").exists()
                mzml_absent: !file("${params.mzml_dir}/${it[1]}/${it[0].baseName}.mzML.gz").exists()
            }
            | set { staging }

        run_msconvert(staging.mzml_absent)
            | concat(staging.mzml_present | map { it -> it[0] })
            | set { results }

        results.view()

    emit:
        results
}
