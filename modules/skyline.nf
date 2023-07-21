process SKYLINE_ADD_LIB {
    publishDir "${params.result_dir}/skyline/add-lib", failOnError: true, mode: 'copy'
    label 'process_medium'
    label 'error_retry'
    container 'quay.io/protio/pwiz-skyline-i-agree-to-the-vendor-licenses:3.0.23187-2243781'

    input:
        path skyline_template_zipfile
        path fasta
        path blib

    output:
        path("results.sky.zip"), emit: skyline_zipfile
        path("skyline_add_library.log"), emit: log

    script:
    """
    unzip ${skyline_template_zipfile}

    wine SkylineCmd \
        --in="${skyline_template_zipfile.baseName}" \
        --log-file=skyline_add_library.log \
        --import-fasta="${fasta}" \
        --add-library-path="${blib}" \
        --out="results.sky" \
        --save \
        --share-zip="results.sky.zip" \
        --share-type="complete"
    """

    stub:
    """
    echo "${skyline_template_zipfile}"
    echo "${fasta}"
    echo "${blib}"
    touch skyline_add_library.log
    touch results.sky.zip
    """
}

process SKYLINE_IMPORT_DATA {
    publishDir "${params.result_dir}/skyline/import-spectra", failOnError: true, mode: 'copy'
    label 'process_medium'
    label 'process_high_memory'
    label 'error_retry'
    container 'quay.io/protio/pwiz-skyline-i-agree-to-the-vendor-licenses:3.0.23187-2243781'

    input:
        path skyline_zipfile
        each path(raw_file)

    output:
        path("*.skyd"), emit: skyd_file
        path("${raw_file.baseName}.log"), emit: log_file

    script:
    """
    unzip ${skyline_zipfile}

    wine SkylineCmd \
        --in="${skyline_zipfile.baseName}" \
        --import-no-join \
        --log-file="${raw_file.baseName}.log" \
        --import-file="${raw_file}" \
    """

    stub:
    """
    echo "${skyline_zipfile}"
    echo "${raw_file}"
    touch ${raw_file.baseName}.skyd
    touch ${raw_file.baseName}.log
    """
}

process SKYLINE_MERGE_RESULTS {
    publishDir "${params.result_dir}/skyline/import-spectra", failOnError: true, mode: 'copy'
    label 'process_high'
    label 'error_retry'
    container 'quay.io/protio/pwiz-skyline-i-agree-to-the-vendor-licenses:3.0.23187-2243781'

    input:
        path skyline_zipfile
        path '*.skyd'
        val raw_files

    output:
        path("final.sky.zip"), emit: final_skyline_zipfile
        path("skyline-merge.log"), emit: log

    script:
    import_files_params = "--import-file=${(mzml_files as List).collect{ "/tmp/" + file(it).name }.join(' --import-file=')}"
    """
    unzip ${skyline_zipfile}

    wine SkylineCmd \
        --in="${skyline_zipfile.baseName}" \
        --log-file="skyline-merge.log" \
        ${import_files_params} \
        --out="final.sky" \
        --save \
        --share-zip="final.sky.zip" \
        --share-type="complete"
    """

    stub:
    """
    touch skyline-merge.log
    touch final.sky.zip
    """
}
