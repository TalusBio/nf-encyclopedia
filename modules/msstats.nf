process MSSTATS {
    publishDir "${params.result_dir}/${group}", failOnError: true
    label 'process_medium'

    input:
        tuple val(group), path(quant_peptides)
        path input
        path contrasts

    output:
        val group
        path "msstats/msstats.input.txt"
        path "msstats/msstats.processed.rda"
        path "msstats.proteins.txt"
        path "logs/msstats.log"
        path "msstats.stats.txt", optional: true
        path "reports/msstats.qc.pdf", optional: true

    script:
    """
    head quant_peptides
    mkdir -p msstats reports logs
    msstats.R \
        ${quant_peptides} \
        ${input} \
        ${contrasts} \
        ${params.msstats.normalization} \
        ${params.msstats.reports} \
        | tee logs/msstats.log
    [ -f QCplot.pdf ] && mv QCplot.pdf reports/msstats.qc.pdf
    """

    stub:
    """
    mkdir -p msstats reports logs
    touch msstats/msstats.input.txt
    touch msstats/msstats.processed.rda
    touch msstats.proteins.txt
    touch logs/msstats.log
    touch msstats.stats.txt
    touch reports/msstats.qc.pdf
    """
}
