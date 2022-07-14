#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// Subworkflows:
include { CONVERT_TO_MZML } from "./subworkflows/msconvert"
include {
    BUILD_CHROMATOGRAM_LIBRARY;
    PERFORM_QUANT;
    PERFORM_GLOBAL_QUANT
} from "./subworkflows/encyclopedia"


def replace_missing_elib(elib) {
    // Use the DLIB when the ELIB is unavailable.
    if (elib == null) {
        return file(params.encyclopedia.dlib)
    }
    return elib
}


workflow {
    // Get .fasta and .dlib from metadata-bucket
    fasta = Channel.fromPath(params.encyclopedia.fasta, checkIfExists: true).first()
    dlib = Channel.fromPath(params.encyclopedia.dlib, checkIfExists: true).first()

    // Get the narrow and wide files:
    ms_files = Channel
        .fromPath(params.ms_file_csv, checkIfExists: true)
        .splitCsv(header: true, strip: true)
        .multiMap { it ->
            runs: it.file
            meta: tuple it.file, it.chrlib.toBoolean(), it.group
        }

    if ( !ms_files.runs ) {
        error "No MS data files were given. Nothing to do."
    }

    // Convert raw files to gzipped mzML and group them by experiment.
    // The chrlib and quant channels take the following form:
    // [[file_ids], [mzml_gz_files], is_chrlib, group]
    CONVERT_TO_MZML(ms_files.runs)
    | join(ms_files.meta)
    | groupTuple(by: [2, 3])
    | branch {
        chrlib: it[2]
        quant: !it[2]
    }
    | set { mzml_gz_files }

    // Build chromatogram libraries with EncyclopeDIA:
    // The output is [group, elib]
    BUILD_CHROMATOGRAM_LIBRARY(mzml_gz_files.chrlib, dlib, fasta)
    | set { chrlib_elib_files }

    // Group quant files with either corresponding library ELIB.
    // If none exists, use the DLIB.
    // The output is [group, [quant_mzml_gz_files], elib_file]
    mzml_gz_files.quant
    | map { tuple it[3], it[1] }
    | join(chrlib_elib_files, remainder: true)
    | map { tuple it[0], it[1], replace_missing_elib(it[2]) }
    | set { quant_files }

    // Analyze the quantitative runs with EncyclopeDIA.
    // The output has two channels:
    // local -> [group, [local_elib_files], [mzml_gz_files]]
    // global -> [group, global_elib, peptides, proteins] or null
    // msstats -> [group, input_csv, feature_csv]
    PERFORM_QUANT(quant_files, dlib, fasta, params.aggregate)
    | set { quant_results }

    // Perform an global analysis on all files if needed:
    if ( params.aggregate ) {
        PERFORM_GLOBAL_QUANT(quant_results.local, dlib, fasta)
    }
}


// A dummy workflow for testing:
workflow dummy {
    channel.of('This workflow doesn\'t do anything...')
}


// Email notifications:
workflow.onComplete {
    def msg = """\
        ${params.experimentName}
        Pipeline execution summary
        --------------------------
        Completed at  : ${workflow.complete}
        Duration      : ${workflow.duration}
        Success       : ${workflow.success}
        Exit Status   : ${workflow.exitStatus}
        """
        .stripIndent()

    sendMail(
        to: "$params.email",
        subject: "${params.experimentName} Completed",
        body: msg
    )
}


// Email notifications:
workflow.onError {
    def msg = """\
        ${params.experimentName}
        Pipeline execution summary
        --------------------------
        Completed at  : ${workflow.complete}
        Duration      : ${workflow.duration}
        Success       : ${workflow.success}
        Exit Status   : ${workflow.exitStatus}
        Error Message :
            ${workflow.errorMessage}
        Error Report  :
            ${workflow.errorReport}
        """
        .stripIndent()

    sendMail(
        to: "$params.email",
        subject: "${params.experimentName} Failed",
        body: msg
    )
}
