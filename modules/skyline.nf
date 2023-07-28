
// Code modified from https://github.com/mriffle/nf-teirex-dia/blob/main/modules/skyline.nf

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
        --tran-precursor-ion-charges="2, 3 ,4" \
        --tran-product-ion-charges="1,2" \
        --tran-product-ion-types="b, y, p" \
        --tran-use-dia-window-exclusion \
        --library-pick-product-ions="all_plus" \
        --tran-product-start-ion="ion 2" \
        --tran-product-end-ion="last ion - 2" \
        --associate-proteins-minimal-protein-list \
        --associate-proteins-group-proteins \
        --full-scan-product-res=10.0 \
        --full-scan-product-analyzer=centroided \
        --full-scan-rt-filter-tolerance=2 \
        --ims-library-res=30 \
        --decoys-add=shuffle \
        --timestamp \
        --memstamp \
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
    if [[ ${raw_file} == *.d.tar ]] ; then
        tar -xvf ${raw_file}
        local_rawfile=\$(find \${PWD} -d -name "*.d")
        import_extra_params="  --full-scan-isolation-scheme=\${local_rawfile}"
    else
        local_rawfile=${raw_file}
        import_extra_params=" --full-scan-isolation-scheme=\${local_rawfile}"
    fi

    wine SkylineCmd \
        --in="${skyline_zipfile.baseName}" \
        --import-no-join \
        --import-file="\${local_rawfile}" \
        --full-scan-acquisition-method="DIA" \
        --timestamp \
        --memstamp \
        \${import_extra_params} \
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
        path raw_files

    output:
        path("final.sky.zip"), emit: final_skyline_zipfile
        path("skyline-merge.log"), emit: log

    script:
    """
    echo "Input Raw files"
    echo ${raw_files}

    echo "Directory status >>>>"
    ls -lctha # For debugging ...

    echo "Unzipping skyline template file"
    unzip ${skyline_zipfile}

    import_files_params=""
    import_extra_params=""

    if [[ \$(find \${PWD} -type f -name "*.d.tar") ]] ; then
        for f in *.d.tar ; do
            echo "Decompressing \${f}"
            tar -xvf \${f}
        done
    else
        echo "No compressed .d files found"
    fi

    if [[ \$(find \${PWD} -type d -name "*.d") ]] ; then
        for f in *.d ; do
            import_files_params=" \${import_files_params} --import-file=\${f}"
            import_extra_params=" --full-scan-isolation-scheme=\${f}"
        done
    fi

    echo "Import file params >>>"
    echo \${import_files_params}

    for ftype in raw mzml mzML; do
        echo ">>> Looking for \${ftype} files"
        for f in \$(find \${PWD} -type f -name "*.\${ftype}"); do
            import_files_params=" \${import_files_params} --import-file=\${f}"
        done
    done

    echo "Import file params >>>"
    echo \${import_files_params}

    wine SkylineCmd \
        --in="${skyline_zipfile.baseName}" \
        \${import_files_params} \
        --out="final.sky" \
        --save \
        --share-zip="final.sky.zip" \
        --share-type="complete" \
        --reintegrate-model-name="reintegration_res" \
        --reintegrate-create-model \
        --timestamp \
        --memstamp \
        \${import_extra_params} \
        2>&1 | tee  "skyline-merge.log"

    echo "Directory status >>>>"
    ls -lctha # For debugging ...
    """

    stub:
    """
    touch skyline-merge.log
    touch final.sky.zip
    """
}
