process SKYLINE_ADD_LIB {
    publishDir "${params.result_dir}/skyline/", failOnError: true, mode: 'copy'
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
        --import-fasta="${fasta}" \
        --add-library-path="${blib}" \
        --out="results.sky" \
        --save \
        --share-zip="results.sky.zip" \
        --share-type="complete" \
        2>&1 | tee skyline_add_library.log \
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
    publishDir "${params.result_dir}/skyline/", failOnError: true, mode: 'copy'
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
    if [[ ${raw_file} == *.tar.d ]] ; then
        tar -xvf ${raw_file}
        raw_file=\$(ls *.d)
    else
        local_rawfile=${raw_file}
    fi

    wine SkylineCmd \
        --in="${skyline_zipfile.baseName}" \
        --import-no-join \
        --import-file="\${local_rawfile}" \
        2>&1 | tee  "${raw_file.baseName}.log"
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
    publishDir "${params.result_dir}/skyline/", failOnError: true, mode: 'copy'
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
    """
    unzip ${skyline_zipfile}
    for f in *.tar.d ]] ; do
        tar -xvf \${f}
    done

    local_files=\$(ls *.raw *.mzml *.mzML)
    import_files_params=""
    for f in \$local_files ; do
        import_files_params=" \${import_files_params} --import-file=\${f}"
    done


    wine SkylineCmd \
        --in="${skyline_zipfile.baseName}" \
        \${import_files_params} \
        --out="final.sky" \
        --save \
        --share-zip="final.sky.zip" \
        --share-type="complete" \
        2>&1 | tee  "skyline-merge.log"
    """

    stub:
    """
    touch skyline-merge.log
    touch final.sky.zip
    """
}
