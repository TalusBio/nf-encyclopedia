

include { MSCONVERT; TDF2MZML } from "../modules/convert"

workflow CONVERT_TO_MZML {
    take:
    raw_files

    main:
    raw_files
    | map { raw -> [raw, file(raw), file(raw).getParent().getBaseName()] }
    | branch {
        is_mzml: it[0].endsWith(".mzML.gz")
        return tuple(it[0], it[1])
        mzml_present: (
            file("${params.mzml_dir}/${it[2]}/${it[1].simpleName}.mzML.gz").exists()
            && !params.msconvert.force
        )
        return tuple(it[0], file("${params.mzml_dir}/${it[2]}/${it[1].simpleName}.mzML.gz"))
        mzml_absent: true
        return it
    }
    | set { staging }

    staging.mzml_absent
    | branch {
        is_tdf: it[0].toLowerCase().endsWith(".d.tar")
        return it
        is_raw: true
        return it
    }
    |set { to_convert }

    MSCONVERT(to_convert.is_raw)
    | concat(TDF2MZML(to_convert.is_tdf))
    | concat(staging.is_mzml)
    | concat(staging.mzml_present)
    | set { results }

    emit:
    results
}
