include { ENCYCLOPEDIA_LOCAL; ENCYCLOPEDIA_GLOBAL } from "../modules/encyclopedia"
include { UNIQUE_PEPTIDES_PROTEINS } from "../modules/unique_peptides_proteins"

workflow BUILD_CHROMATOGRAM_LIBRARY {
    take:
    chrlib_files
    dlib
    fasta

    main:
    // Ungroup files for local runs
    // Output is [group, mzml_gz_file]
    chrlib_files
    | transpose()
    | map { tuple it[3], it[1] }
    | set { ungrouped_files }

    // Keep them grouped for the global runs:
    // Output is [group, [mzml_gz_files]]
    chrlib_files
    | map { tuple it[3], it[1] }
    | set { grouped_files }

    // Search each file
    // Ouput is [group, [local_elib_files], [mzml_files]]
    ENCYCLOPEDIA_LOCAL(ungrouped_files, dlib, fasta)
    | groupTuple(by: 0)
    | map { tuple it[0], it[1] }
    | join(grouped_files)
    | set { local_files }

    // Do the global analysis
    // Output is [group, global_elib_file]
    ENCYCLOPEDIA_GLOBAL(
        local_files,
        dlib,
        fasta,
        params.encyclopedia.chrlib_postfix
    )
    | map { tuple it[0], it[1] }
    | set { output_elib }

    emit:
    output_elib
}


workflow PERFORM_QUANT {
    take:
    quant_files
    dlib
    fasta
    local_only

    main:
    // Ungroup files for local runs
    // output is [group, mzml_gz_file, elib]
    quant_files
    | transpose()
    | multiMap { it ->
        mzml: tuple it[0], it[1]
        elib: it[2]
    }
    | set { ungrouped_files }

    // Perform local search:
    // Ouput is [group, [local_elib_files], [mzml_files]]
    ENCYCLOPEDIA_LOCAL(
        ungrouped_files.mzml,
        ungrouped_files.elib,
        fasta
    )
    | groupTuple(by: 0)
    | map { tuple it[0], it[1] }
    | join(quant_files)
    | map { tuple it[0], it[1], it[2] }
    | set { local_files }

    // Only run group-wise global if needed.
    if ( local_only ) {
        Channel.empty() | set { output_elib }
    } else {
        // Get the unique peptides and proteins detected
        local_files
        | map { tuple it[0], it[1] }
        | UNIQUE_PEPTIDES_PROTEINS

        // Do the global analysis
        // Ouput is [group, [global_elib_file]]
        ENCYCLOPEDIA_GLOBAL(
            local_files,
            dlib,
            fasta,
            params.encyclopedia.quant_postfix
        )
        | map { tuple it[0], it[1] }
        | set { output_elib }
    }

    emit:
    local = local_files
    global = output_elib
}


workflow PERFORM_GLOBAL_QUANT {
    take:
    local_quant_files
    dlib
    fasta

    main:
    // Set the group for all runs to "global"
    // The output is ["global", [local_elib_files], [mzml_gz_files]]
    local_quant_files
    | transpose()
    | map { tuple "global", it[1], it[2] }
    | groupTuple(by: 0)
    | set { all_local_files }

    // Get the unique peptides and proteins detected
    all_local_files
    | map { tuple it[0], it[1] }
    | UNIQUE_PEPTIDES_PROTEINS

    ENCYCLOPEDIA_GLOBAL(all_local_files, dlib, fasta, "global")
}
