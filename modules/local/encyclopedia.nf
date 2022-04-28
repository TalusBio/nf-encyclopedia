process ENCYCLOPEDIA_LOCAL {
    echo true
    publishDir "${params.publish_dir}/${group}", mode: "copy"

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
            path("logs/${mzml_gz_file.baseName}.local.log"),
        )

    script:
    """
    mkdir logs
    gunzip -f ${mzml_gz_file}
    java -Djava.awt.headless=true ${params.encyclopedia.memory} \\
        -jar /code/encyclopedia-\$VERSION-executable.jar \\
        -i ${mzml_gz_file.baseName} \\
        -f ${fasta_file} \\
        -l ${library_file} \\
        -percolatorVersion ${params.encyclopedia.percolator_version} \\
        -percolatorTrainingFDR ${params.encyclopedia.percolator_train_fdr} \\
        -percolatorTrainingSetSize ${params.encyclopedia.percolator_training_set_size} \\
        ${params.encyclopedia.local_options} \\
    | tee logs/${mzml_gz_file.baseName}.local.log
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
    touch logs/${mzml_gz_file.baseName}.local.log
    """
}

process ENCYCLOPEDIA_GLOBAL {
    echo true
    publishDir "${params.publish_dir}/${group}", mode: "copy"

    input:
        tuple val(group), path(local_elib_files), path(local_dia_files), path(local_feature_files), path(local_encyclopedia_files)
        path(library_file)
        path(fasta_file)
        val output_postfix

    output:
        tuple(
            val(group),
            path("result-${output_postfix}*.elib"),
            path("result-${output_postfix}*.peptides.txt"),
            path("result-${output_postfix}*.proteins.txt"),
            path("logs/result-${output_postfix}*.global.log"),
            path("${output_postfix}_unique_peptides_proteins.csv")
        )

    script:
    """
    source ~/.bashrc
    mkdir logs
    gunzip ${local_feature_files}
    find * -name '*\\.mzML\\.*' -exec bash -c 'mv \$0 \${0/\\.mzML/\\.dia}' {} \\;
    java -Djava.awt.headless=true ${params.encyclopedia.memory} \\
        -jar /code/encyclopedia-\$VERSION-executable.jar \\
        -libexport \\
        -o result-${output_postfix}.elib \\
        -i ./ \\
        -f ${fasta_file} \\
        -l ${library_file} \\
        -percolatorVersion ${params.encyclopedia.percolator_version} \\
        ${params.encyclopedia.global_options} \\
    | tee logs/result-${output_postfix}.global.log
    echo 'Run,Unique Proteins,Unique Peptides' > ${output_postfix}_unique_peptides_proteins.csv
    find * -name '*\\.elib' -exec bash -c 'unique_peptides_proteins \$0 >> ${output_postfix}_unique_peptides_proteins.csv' {} \\;
    """

    stub:
    def stem = "result-${output_postfix}"
    """
    mkdir logs
    touch ${stem}.elib
    touch ${stem}.peptides.txt
    touch ${stem}.proteins.txt
    touch logs/${stem}.global.log
    touch ${output_postfix}_unique_peptides_proteins.csv
    """
}