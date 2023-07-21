#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// Subworkflows
include { CONVERT_TO_MZML } from "./subworkflows/convert"
include {
    BUILD_CHROMATOGRAM_LIBRARY;
    PERFORM_QUANT;
    PERFORM_AGGREGATE_QUANT
} from "./subworkflows/encyclopedia"

// Modules
include { MSSTATS } from "./modules/msstats"
include { ADD_IMS_INFO } from "./modules/ims"
include { 
    SKYLINE_ADD_LIB;
    SKYLINE_IMPORT_DATA;
    SKYLINE_MERGE_RESULTS
} from "./modules/skyline"


//
// Used for email notifications
//
def email() {
    // Create the email text:
    def (subject, msg) = TalusTemplate.email(workflow, params)
    // Send the email:
    if (params.email) {
        sendMail(
            to: "$params.email",
            subject: subject,
            body: msg
        )
    }
}


//
// Use the DLIB when the ELIB is unavailable.
//
def replace_missing_elib(elib) {
    if (elib == null) {
        return file(params.dlib)
    }
    return elib
}


//
// The main workflow
//
workflow {
    input = file(params.input, checkIfExists: true)
    fasta = file(params.fasta, checkIfExists: true)
    dlib = file(params.dlib, checkIfExists: true)

    // Optional contrasts arg:
    if ( params.contrasts != null ) {
        contrasts = file(params.contrasts, checkIfExists: true)
    } else {
        contrasts = file("${baseDir}/assets/NO_FILE", checkIfExists: true)
    }

    // Get the narrow and wide files:
    ms_files = Channel
        .fromPath(params.input, checkIfExists: true)
        .splitCsv(header: true, strip: true)
        .multiMap { it ->
            runs: it.file
            meta: tuple(
                it.file,
                it.chrlib.toBoolean(),
                it.group ?: '',  // no group if missing
            )
        }

    if ( !ms_files.runs ) {
        error "No MS data files were provided. Nothing to do."
    }

    // Raw Mass Spec files (raw including .raw or .d/.tar)
    // These files will be used later to quant using skyline.
    // This also filter out files that are chromatogram libraries
    ms_files.runs
    | join(ms_files.meta)
    | filter { !it[1] }
    | map { it[0] }
    | filter( ~/^.*((.raw)|(.d.tar))$/ )
    | set { raw_quant_files }

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
    // global -> [group, peptides, proteins] or null
    PERFORM_QUANT(quant_files, dlib, fasta, params.aggregate)
    | set { quant_results }

    // Perform an aggregate analysis on all files if needed:
    if ( params.aggregate ) {
        // Aggregate quantitative runs with EncyclopeDIA.
        // The output has one channel:
        // global -> [agg_name, peptides_txt, proteins_txt] or null
        // lib -> blib
        PERFORM_AGGREGATE_QUANT(quant_results.local, dlib, fasta)
        | set { enc_results }

        quant_results.local
        | map { it[0] }
        | set { groups }

        ADD_IMS_INFO(groups, enc_results.blib)
        | set { blib }

        skyline_template = file(params.skyline_template, checkIfExists: true)
        SKYLINE_ADD_LIB(skyline_template, blib, fasta)
        | set { skyline_template_zipfile }

        println raw_quant_files
        raw_quant_files.view()
        SKYLINE_IMPORT_DATA(
            skyline_template_zipfile.skyline_zipfile,
            raw_quant_files,
        )
        | set { skyline_import_results }

        raw_quant_files = raw_quant_files.collect()

        skyd_files = skyline_import_results.skyd_file.collect()
        skyd_files.view()

        SKYLINE_MERGE_RESULTS(
            skyline_template_zipfile.skyline_zipfile,
            skyd_files,
            raw_quant_files,
        )


    } else {
        quant_results | set{ enc_results }
    }

    // Run MSstats
    if ( params.msstats.enabled ) {
        MSSTATS(enc_results.global, input, contrasts)
    }

    // 
}


//
// This is a dummy workflow for testing
//
workflow dummy {
    println "This is a workflow that doesn't do anything."
}

// Email notifications:
workflow.onComplete { email() }
