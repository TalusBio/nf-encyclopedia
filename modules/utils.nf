#!/usr/bin/env nextflow

process gunzip {
    echo true

    input:
        file f_in
    output:
        file f_out
    script:
    f_out = f_in.name.replaceAll(/\.gz/, '')
    """
    gzip -dc ${f_in} > ${f_out}
    """
}