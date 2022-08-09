process ENCYCLOPEDIA_LOCAL {
    publishDir "${params.result_dir}/${group}/elib", pattern: '*.elib', failOnError: true
    publishDir "${params.result_dir}/${group}/logs", pattern: '*.log', failOnError: true
    label 'process_medium'

    input:
        tuple val(group), path(mzml_gz_file)
        path(library_file)
        path(fasta_file)

    output:
        tuple(
            val(group),
            path("${mzml_gz_file.baseName}.elib"),
            path("${file(mzml_gz_file.baseName).baseName}.dia"),
            path("${mzml_gz_file.baseName}.features.txt.gz"),
            path("${mzml_gz_file.baseName}.encyclopedia.txt"),
            path("${mzml_gz_file.baseName}.encyclopedia.decoy.txt"),
            path("${mzml_gz_file.baseName}.local.log"),
        )

    script:
    """
    mkdir logs
    gunzip -f ${mzml_gz_file}
    java \\
        -Djava.awt.headless=true \\
        -Xmx${task.memory.toGiga()-1}G \\
        -jar /code/encyclopedia-\$VERSION-executable.jar \\
        -i ${mzml_gz_file.baseName} \\
        -f ${fasta_file} \\
        -l ${library_file} \\
        ${params.encyclopedia.args} \\
        ${params.encyclopedia.local.args} \\
    | tee ${mzml_gz_file.baseName}.local.log
    gzip ${mzml_gz_file.baseName}.features.txt
    """

    stub:
    """
    mkdir logs
    touch ${mzml_gz_file.baseName}.elib
    touch ${file(mzml_gz_file.baseName).baseName}.dia
    touch ${mzml_gz_file.baseName}.features.txt.gz
    touch ${mzml_gz_file.baseName}.encyclopedia.txt
    touch ${mzml_gz_file.baseName}.encyclopedia.decoy.txt
    touch ${mzml_gz_file.baseName}.local.log
    """
}


process ENCYCLOPEDIA_GLOBAL {
    publishDir "${params.result_dir}/${group}/elib", pattern: '*.elib', failOnError: true
    publishDir "${params.result_dir}/${group}/logs", pattern: '*.log', failOnError: true
    publishDir "${params.result_dir}/${group}/logs", pattern: '*.log', failOnError: true
    label 'process_high'

    input:
        tuple(
            val(group),
            path(local_elib_files),
            path(local_dia_files),
            path(local_feature_files),
            path(local_encyclopedia_files),
        )
        path(library_file)
        path(fasta_file)
        val output_postfix

    output:
        tuple(
            val(group),
            path("result-${output_postfix}.elib"),
            path("result-${output_postfix}.elib.peptides.txt"),
            path("result-${output_postfix}.elib.proteins.txt"),
            path("logs/result-${output_postfix}.global.log"),
            path("${output_postfix}_unique_peptides_proteins.csv")
        )

    script:
    def stem = "result-${output_postfix}.elib"
    """
    source ~/.bashrc
    mkdir logs
    gunzip ${local_feature_files}
    find * -name '*\\.mzML\\.*' -exec bash -c 'mv \$0 \${0/\\.mzML/\\.dia}' {} \\;
    java \\
        -Djava.awt.headless=true \\
        -Xmx${task.memory.toGiga()-1}G \\
        -jar /code/encyclopedia-\$VERSION-executable.jar \\
        -libexport \\
        -o ${stem} \\
        -i ./ \\
        -f ${fasta_file} \\
        -l ${library_file} \\
        ${params.encyclopedia.args} \\
        ${params.encyclopedia.global.args} \\
    | tee logs/result-${output_postfix}.global.log
    echo 'Finding unique peptides and proteins...'
    echo 'Run,Unique Proteins,Unique Peptides' \\
        > ${output_postfix}_unique_peptides_proteins.csv
    find * -name '*\\.elib' -exec bash -c 'bin/count_peptides_proteins.sh \$0 \\
        >> ${output_postfix}_unique_peptides_proteins.csv' {} \\;
    echo 'DONE!'
    """

    stub:
    def stem = "result-${output_postfix}"
    """
    mkdir logs
    touch ${stem}.elib
    touch ${stem}.elib.peptides.txt
    touch ${stem}.elib.proteins.txt
    touch logs/${stem}.global.log
    touch ${output_postfix}_unique_peptides_proteins.csv
    """
}
