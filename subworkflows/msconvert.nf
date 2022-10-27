include { MSCONVERT } from "../modules/msconvert.nf"


// Case insensitive extension matching.
def mzml_file(file_path) {
    def stem = (file_path.name =~ /(.*)\.(?!gz).*$/)[0][1]
    def fname = file("${params.mzml_dir}/${stem}.mzML.gz")
    return fname
}


workflow CONVERT_TO_MZML {
    take:
    raw_files

    main:
    raw_files
    | branch {
        is_mzml: it.toLowerCase().endsWith(".mzml.gz")
        return tuple(it, file(it))
        mzml_present: mzml_file(file(it)).exists() && !params.msconvert.force
        return tuple(it, mzml_file(file(it)))
        mzml_absent: true
        return tuple(it, file(it))
    }
    | set { staging }

    MSCONVERT(staging.mzml_absent)
    | concat(staging.is_mzml)
    | concat(staging.mzml_present)
    | set { results }

    emit:
    results
}
