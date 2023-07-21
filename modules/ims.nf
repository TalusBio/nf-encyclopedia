
process ADD_IMS_INFO {
    publishDir "${params.result_dir}/${group}/blib", pattern: '*.ims.blib', failOnError: true
    label 'process_medium'
    container 'ghcr.io/talusbio/flimsay:v0.2.0'

    input:
        path blib

    output:
        path("*.ims.blib"), emit: blib

    script:
    """
    flimsay fill_blib ${blib} blib.ims.blib 
    """

    stub:
    """
    echo "${blib}"
    touch blib.ims.blib
    """
}
