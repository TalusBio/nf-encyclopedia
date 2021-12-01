#!/usr/bin/env nextflow
include { msconvert } from "./modules/msconvert.nf"
include { unique_peptides_proteins } from "./modules/post_processing.nf"

nextflow.enable.dsl = 2

FILTER = "NO_FILE"

process run_encyclopedia_local {
    echo true
    publishDir "${params.experimentBucket}/${params.experimentName}/encyclopedia", mode: "copy"
    storeDir "${params.cacheBucket}/${params.experimentName}"

    input:
        path mzml_gz_file
        each path(library_file)
        each path(fasta_file)

    output:
        tuple(
            path("${mzml_gz_file.name.replaceAll(/\.mzML\.gz/, "")}*.elib"),
            path("${mzml_gz_file.name.replaceAll(/\.mzML\.gz/, "")}*.dia"),
            path("${mzml_gz_file.name.replaceAll(/\.mzML\.gz/, "")}*{features,encyclopedia,decoy}.txt"),
            path("${mzml_gz_file.name.replaceAll(/\.mzML\.gz/, "")}*.log"),
        )

    script:
    def mzml_file = mzml_gz_file.name.replaceAll(/\.gz/, "")
    """
    gzip -df ${mzml_gz_file}
    java -Djava.awt.headless=true ${params.encyclopedia.memory} \\
        -jar /code/encyclopedia-\$VERSION-executable.jar \\
        -i ${mzml_file} \\
        -f ${fasta_file} \\
        -l ${library_file} \\
        ${params.encyclopedia.local_options} \\
    &> ${mzml_file}.local.log
    """
}

process run_encyclopedia_global {
    echo true
    publishDir "${params.experimentBucket}/${params.experimentName}/encyclopedia", mode: "copy"
    storeDir "${params.cacheBucket}/${params.experimentName}"

    input:
        path local_files
        path mzml_gz_files
        path library_file
        path fasta_file
        val output_postfix

    output:
        tuple path("*.elib"), path("*{peptides,proteins}.txt"), path("*.log")

    script:
    """
    find . -type f -name '*.gz' -exec gzip -df {} \\;
    java -Djava.awt.headless=true ${params.encyclopedia.memory} \\
        -jar /code/encyclopedia-\$VERSION-executable.jar \\
        -libexport \\
        -o result-${output_postfix}.elib \\
        -i ./ \\
        -f ${fasta_file} \\
        -l ${library_file} \\
        ${params.encyclopedia.global_options} \\
    &> ${output_postfix}.global.log
    """
}

workflow encyclopedia_narrow {
    take: 
        mzml_gz_files
        dlib
        fasta
    main:
        run_encyclopedia_local(mzml_gz_files, dlib, fasta)
            | flatten
            | collect
            | set { narrow_local_files }
        run_encyclopedia_global(narrow_local_files, mzml_gz_files | collect, dlib, fasta, params.encyclopedia.narrow_lib_postfix)
            | flatten
            | filter { it.name =~ /.*elib$/ }
            | set { narrow_elib }
    emit:
        narrow_elib
}

workflow encyclopedia_wide {
    take: 
        mzml_gz_files
        elib
        fasta
    main:
        // Run encyclopedia for all local files
        run_encyclopedia_local(mzml_gz_files, elib, fasta)
            .flatten()
            .tap { wide_local_files }
            | filter { it.name =~ /.*mzML.elib$/ }
            | collect
            | unique_peptides_proteins
        // Use the local .elib's as an input to the global run
        run_encyclopedia_global(wide_local_files | collect, mzml_gz_files | collect, elib, fasta, params.encyclopedia.wide_lib_postfix)
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

    // Use msconvert on raw files, pass through if mzml .gz files are given
    if (params.raw_files) {
        raw_files = Channel.fromList(params.raw_files) | map { file("${params.rawBucket}/${it}") }
        raw_files
            | msconvert
            | set { mzml_gz_files }
    } else if (params.mzml_gz_files) {
        mzml_gz_files = Channel.fromList(params.mzml_gz_files) | map { file("${params.mzmlBucket}/${it}") }
    } else {
        error "No .raw or .mzML files given. Nothing to do."
    }

    // Join the file keys to get the file type and plit the set of files into narrow and wide.
    // Get the mapping from file_key to file_type
    file_key_types = Channel.of(params.file_key_types) | splitCsv
    mzml_gz_files
        | map { mzml_gz_file ->
            // Create a file_key based off of the file path
            // E.g. mzml-bucket/210308/210308_talus_01.mzML.gz --> 210308_talus_01
            def file_key = mzml_gz_file.getBaseName().tokenize(".")[0]
            return tuple(file_key, mzml_gz_file)
        }
        | join(file_key_types)
        | branch { file_key, mzml_gz_file, file_type ->
            narrow: file_type == "Narrow DIA"
                return mzml_gz_file
            wide: file_type == "Wide DIA"
                return mzml_gz_file
        }
        | set { run_files }

    // Run encyclopedia
    encyclopedia_narrow(run_files.narrow, dlib, fasta)
    // If no narrow files are given the output chr-elib will be empty and we use the dlib instead.
    encyclopedia_narrow.out
        .ifEmpty(file("${params.metadataBucket}/${params.encyclopedia.dlib}"))
        .set { chr_elib }
    encyclopedia_wide(run_files.wide, chr_elib, fasta)
}

workflow.onComplete {
    sendMail( 
        to: params.email,
        subject: "Success: ${params.experimentName} succeeded.",
        body: "Experiment run ${params.experimentName} using Encyclopedia succeeded.",
    )
}

workflow.onError {
    sendMail( 
        to: params.email,
        subject: "Error: ${params.experimentName} failed.",
        body: "Experiment run ${params.experimentName} using Encyclopedia failed.",
    )
}
