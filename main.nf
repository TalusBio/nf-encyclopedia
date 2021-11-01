#!/usr/bin/env nextflow
include { gunzip } from "./modules/utils.nf"
include { msconvert } from "./modules/msconvert.nf"

nextflow.enable.dsl = 2

FILTER = "NO_FILE"

process run_encyclopedia_local {
    echo true
    publishDir "${params.experimentBucket}/${params.experimentName}/encyclopedia", mode: "copy"

    input:
        tuple file(mzml_file), file(library_file), file(fasta_file)

    output:
        tuple file("*.elib"), file("*.dia"), file("*.txt")

    script:
    // if no library file is given, there were no narrow files and we use walnut
    def walnut_flag = library_file.name == FILTER ? "-walnut" : "-l ${library_file}"
    """
    java -Djava.awt.headless=true ${params.encyclopedia.memory} \\
        -jar /code/encyclopedia-${params.encyclopedia.version}-executable.jar \\
        -i ${mzml_file} \\
        -f ${fasta_file} \\
        ${walnut_flag}
    """
}

process run_encyclopedia_global {
    echo true
    publishDir "${params.experimentBucket}/${params.experimentName}/encyclopedia", mode: "copy"

    input:
        file local_files
        file mzml_files
        file fasta_file
        file library_file
        val output_postfix

    output:
        tuple file("*.elib"), file("*.txt")

    script:
    // if no library file is given, there were no narrow files and we use walnut
    def walnut_flag = library_file.name == FILTER ? "-walnut" : "-l ${library_file}"
    """
    java -Djava.awt.headless=true ${params.encyclopedia.memory} \\
        -jar /code/encyclopedia-${params.encyclopedia.version}-executable.jar \\
        -libexport \\
        -o result-${output_postfix}.elib \\
        -i ./ \\
        -f ${fasta_file} \\
        ${walnut_flag}
    """
}

workflow encyclopedia_narrow {
    take: 
        data
        fasta
        dlib
    main:
        gunzip(data)
            .tap { unzipped_mzml }
            | combine(fasta.mix(dlib).collect())
            | run_encyclopedia_local
            | flatten
            | collect 
            | set { narrow_local_files }
        run_encyclopedia_global(narrow_local_files, unzipped_mzml | collect, fasta, dlib, params.encyclopedia.narrow_lib_postfix)
            | flatten
            | filter { it.name =~ /.*elib$/ }
            | set { narrow_elib }
    emit:
        narrow_elib
}

workflow encyclopedia_wide {
    take: 
        data
        fasta
        elib
    main:
        gunzip(data)
            .tap { unzipped_mzml }
            | combine(fasta.mix(elib).collect())
            | run_encyclopedia_local
            | flatten
            | collect 
            | set { wide_local_files }
        run_encyclopedia_global(wide_local_files, unzipped_mzml | collect, fasta, elib, params.encyclopedia.wide_lib_postfix)
            | flatten
            | filter { it.name =~ /.*elib$/ }
            | set { wide_elib }
    emit:
        wide_elib
}

workflow {
    // Get .fasta and .dlib from metadata-bucket
    fasta = Channel.fromPath("${params.metadataBucket}/${params.encyclopedia.fasta}", checkIfExists: true)
    dlib = Channel.fromPath("${params.metadataBucket}/${params.encyclopedia.dlib}", checkIfExists: true)

    // Get input paths and create separate channels for narrow and wide files
    input_paths = Channel.of(params.input_paths)
    input_paths
        .splitCsv()
        .filter { it[1] == "Narrow DIA" }
        .set { narrow }
    input_paths
        .splitCsv()
        .filter { it[1] == "Wide DIA" }
        .set { wide }

    // Run encyclopedia
    encyclopedia_narrow(narrow | msconvert, fasta, dlib)
    // If no narrow files are given the output chr-elib will be empty 
    // and we use walnut instead.
    encyclopedia_narrow.out
        .ifEmpty(file("${params.metadataBucket}/${FILTER}"))
        .set { chr_elib }
    encyclopedia_wide(wide | msconvert, fasta, chr_elib)
}