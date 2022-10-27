// Convert vendor files to mzML

// Get the file stem:
def stem(file_path) {
    return (file_path.name =~ /(.*)\.(?!gz).*$/)[0][1]
}

process MSCONVERT {
    publishDir "${params.mzml_dir}", failOnError: true
    label 'process_low_constant'
    label 'error_retry'

    input:
        tuple val(file_id), path(raw_input)

    output:
        tuple val(file_id), path("${stem(raw_input)}.mzML.gz")

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
    touch ${stem(raw_input)}.mzML.gz
    """
}
