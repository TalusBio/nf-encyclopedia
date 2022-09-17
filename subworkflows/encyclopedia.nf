include { ENCYCLOPEDIA_LOCAL; ENCYCLOPEDIA_GLOBAL } from "../modules/encyclopedia"
include { MSSTATS } from "../modules/msstats"


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

        // Search each file
        // Ouput is [group, [local_elib_files], [local_dia_files], [local_feature_files], [local_encyclopedia_files]]
        ENCYCLOPEDIA_LOCAL(ungrouped_files, dlib, fasta)
        | groupTuple(by: 0)
        | map { tuple it[0], it[1], it[2], it[3], it[4] }
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
        // Ouput is [group, [local_elib_files], [local_dia_files], [local_feature_files], [local_encyclopedia_files]]
        ENCYCLOPEDIA_LOCAL(
            ungrouped_files.mzml,
            ungrouped_files.elib,
            fasta
        )
        | groupTuple(by: 0)
        | map { tuple it[0], it[1], it[2], it[3], it[4] }
        | set { local_files }

        // Only run group-wise global if needed.
        if ( local_only ) {
            Channel.empty() | set { global_files }
            Channel.empty() | set { msstats_files }
        } else {
            // Do the global analysis
            // Output is [group, global_elib_file, peptides_txt, proteins_txt, log]
            ENCYCLOPEDIA_GLOBAL(
                local_files,
                dlib,
                fasta,
                params.encyclopedia.quant_postfix
            )
            | set { global_files }
        }

    emit:
        local = local_files
        global = global_files
}


workflow PERFORM_AGGREGATE_QUANT {
    take:
        local_quant_files
        dlib
        fasta

    main:
        // Set the group for all runs to agg_name
        // The output is [agg_name, [local_elib_files], [local_dia_files], [local_feature_files], [local_encyclopedia_files]]
        local_quant_files
        | transpose()
        | map { tuple params.agg_name, it[1], it[2], it[3], it[4] }
        | groupTuple(by: 0)
        | set { all_local_files }

        // Do the global analysis
        // Ouput is ["global", global_elib_file, peptides_txt, proteins_txt, log]
        ENCYCLOPEDIA_GLOBAL(
            all_local_files,
            dlib,
            fasta,
            params.encyclopedia.quant_postfix
        )
        | set { global_files }

    emit:
        global = global_files
}
