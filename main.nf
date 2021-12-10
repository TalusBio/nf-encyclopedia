#!/usr/bin/env nextflow
include { msconvert as msconvert_narrow } from "./modules/msconvert.nf"
include { msconvert as msconvert_wide } from "./modules/msconvert.nf"
include { unique_peptides_proteins } from "./modules/post_processing.nf"

nextflow.enable.dsl = 2

FILTER = "NO_FILE"

process run_encyclopedia_local {
    echo true
    publishDir params.publish_dir, mode: "copy"

    input:
        path mzml_gz_file
        each path(library_file)
        each path(fasta_file)

    output:
        tuple(
            path("${mzml_gz_file.baseName}.elib"),
            path("${file(mzml_gz_file.baseName).baseName}.dia"),
            path("${mzml_gz_file.baseName}.{features,encyclopedia,encyclopedia.decoy}.txt"),
            path("${mzml_gz_file.baseName}.local.log"),
        )

    script:
    """
    gzip -df ${mzml_gz_file}
    java -Djava.awt.headless=true ${params.encyclopedia.memory} \\
        -jar /code/encyclopedia-\$VERSION-executable.jar \\
        -i ${mzml_gz_file.baseName} \\
        -f ${fasta_file} \\
        -l ${library_file} \\
        ${params.encyclopedia.local_options} \\
    &> ${mzml_gz_file.baseName}.local.log
    """

    stub:
    """
    touch ${mzml_gz_file.baseName}.elib
    touch ${file(mzml_gz_file.baseName).baseName}.dia
    touch ${mzml_gz_file.baseName}.features.txt
    touch ${mzml_gz_file.baseName}.encyclopedia.txt
    touch ${mzml_gz_file.baseName}.encyclopedia.decoy.txt
    touch ${mzml_gz_file.baseName}.log
    """
}

process run_encyclopedia_global {
    echo true
    publishDir params.publish_dir, mode: "copy"

    input:
        path local_files
        path mzml_gz_files
        path library_file
        path fasta_file
        val output_postfix

    output:
        tuple(
            path("result-${output_postfix}*.elib"), 
            path("result-${output_postfix}*.{peptides,proteins}.txt"),
            path("result-${output_postfix}*.global.log")
        )

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
    &> result-${output_postfix}.global.log
    """

    stub:
    def stem = "result-${output_postfix}"
    """
    touch ${stem}.elib
    touch ${stem}.peptides.txt
    touch ${stem}.proteins.txt
    touch ${stem}.global.log
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

        run_encyclopedia_global(
            narrow_local_files,
            mzml_gz_files | collect,
            dlib,
            fasta,
            params.encyclopedia.narrow_lib_postfix,
        )
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
        run_encyclopedia_global(
            wide_local_files | collect,
            mzml_gz_files | collect,
            elib,
            fasta,
            params.encyclopedia.wide_lib_postfix
        )
            | flatten
            | filter { it.name =~ /.*elib$/ }
            | set { wide_elib }
    emit:
        wide_elib
}

workflow {
    // Get .fasta and .dlib from metadata-bucket
    fasta = Channel.fromPath(params.encyclopedia.fasta, checkIfExists: true)
    dlib = Channel.fromPath(params.encyclopedia.dlib, checkIfExists: true)

    // Get the narrow and wide files:
    narrow_files = Channel
        .fromPath(params.narrow_files, checkIfExists: true)
        .splitCsv()
        .map { row -> file(row[0]) }

    wide_files = Channel
        .fromPath(params.wide_files, checkIfExists: true)
        .splitCsv()
        .map { row -> file(row[0]) }

    if ( !narrow_files && !wide_files ) {
        error "No raw files were given. Nothing to do."
    }

    // Convert raw files to gzipped mzML.
    narrow_files | msconvert_narrow | set { narrow_mzml_files }
    wide_files | msconvert_wide | set { wide_mzml_files }

    // Build a chromatogram library with EncyclopeDIA
    encyclopedia_narrow(narrow_mzml_files, dlib, fasta)

    // If no narrow file are given, use the dlib instead.
    encyclopedia_narrow.out
        .ifEmpty(file(params.encyclopedia.dlib))
        .set { chr_elib }

    // Perform quant runs on wide window files.
    encyclopedia_wide(wide_mzml_files, chr_elib, fasta)
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
