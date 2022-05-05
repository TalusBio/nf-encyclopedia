include { MSCONVERT } from "../../modules/local/msconvert.nf"


workflow CONVERT_TO_MZML {
    take:
    raw_files

    main:
    raw_files
    | map { raw -> [raw, file(raw), file(raw).getParent().getBaseName()] }
    | branch {
        mzml_present: file("${params.mzml_dir}/${it[2]}/${it[1].simpleName}.mzML.gz").exists()
        return tuple(it[0], file("${params.mzml_dir}/${it[2]}/${it[1].simpleName}.mzML.gz"))
        mzml_absent: !file("${params.mzml_dir}/${it[2]}/${it[1].simpleName}.mzML.gz").exists()
        return it
    }
    | set { staging }

    MSCONVERT(staging.mzml_absent)
    | concat(staging.mzml_present)
    | set { results }

    emit:
    results
}
