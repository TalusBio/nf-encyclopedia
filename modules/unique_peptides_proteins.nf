process UNIQUE_PEPTIDES_PROTEINS {
    echo true
    publishDir "${params.publish_dir}/${group}", mode: "copy"

    input:
    tuple val(group), path(elib_files)

    output:
    path("unique_peptides_proteins.csv")

    script:
    """
    python3 /app/src/unique_peptides_proteins.py -g "./*.mzML.elib" -t encyclopedia
    """

    stub:
    """
    touch unique_peptides_proteins.csv
    """
}
