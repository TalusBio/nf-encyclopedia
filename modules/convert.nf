process MSCONVERT {
    publishDir "${params.mzml_dir}/${outputDir}", failOnError: true
    label 'process_low_constant'
    label 'error_retry'

    input:
        tuple val(file_id), path(raw_input), val(outputDir)

    output:
        tuple val(file_id), path("${raw_input.baseName}.mzML.gz")

    script:
    """
    wine msconvert \\
        -v \\
        --gzip \\
        --mzML \\
        --64 \\
        --zlib \\
        --filter "peakPicking true 1-" \\
        ${params.msconvert.demultiplex ? '--filter "demultiplex optimization=overlap_only"' : ''} \\
        ${raw_input}
    """

    stub:
    """
    touch ${raw_input.baseName}.mzML.gz
    """
}


process TDF2MZML {
    publishDir "${params.mzml_dir}/${outputDir}", pattern: "*.mzML.gz", failOnError: true
    container 'mfreitas/tdf2mzml:latest' // I don't know which stable tag to use...
    label 'process_single'
    label 'error_retry'

    input:
        tuple val(file_id), path(tdf_input), val(outputDir)

    output:
    tuple val(file_id), path("${file(tdf_input.baseName).baseName}.mzML.gz")

    script:
    """
    echo "Unpacking..."
    tar -xvf ${tdf_input}

    echo "Converting..."
    tdf2mzml.py -i *.d # --ms1_type "centroid"

    echo "Compressing..."
    mv *.mzml ${file(tdf_input.baseName).baseName}.mzML
    gzip ${file(tdf_input.baseName).baseName}.mzML
    """

    stub:
    """
    touch ${file(tdf_input.baseName).baseName}.mzML.gz
    """
}