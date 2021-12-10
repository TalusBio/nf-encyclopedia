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
            | map { it -> [it, it.getParent().getBaseName()] }
            | run_msconvert
    emit:
        run_msconvert.out
}
