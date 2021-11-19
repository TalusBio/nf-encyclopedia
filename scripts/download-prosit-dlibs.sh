#!/usr/bin/env bash
set -eou

concat () {
    echo "$@"
    fname="$(echo "$@" | tr " " "_").fasta"
    tmpfa=$(mktemp -d "${TMPDIR:-/tmp/}$(basename "$0").XXXXXXXXXXXX")/${fname}
    for fasta in $@; do
        cat ${fasta} >> ${tmpfa}
    done
    echo ${tmpfa}
    cat ${tmpfa}
}

main () {
    concat
}

main
