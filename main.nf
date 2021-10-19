#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// params.experimentName = "orange-marmot"
params.experimentName = "green-walnut"
// to use s3, params.outDir needs to be s3 path
s3_prefix = params.use_aws ? "s3://talus-data-pipeline-" : ""
params.experimentBucket = s3_prefix+"experiment-bucket"
params.metadataBucket = s3_prefix+"metadata-bucket"
params.mzmlBucket = s3_prefix+"mzml-bucket"

params.memory = "-Xmx24G"
params.encyclopedia_version = "0.9.5"
params.narrow_output_postfix = "chr"
params.wide_output_postfix = "quant"
params.filter = "NO_FILE"

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

process run_encyclopedia_local {
    echo true
    publishDir "${params.experimentBucket}/${params.experimentName}/encyclopedia", mode: "copy"

    input:
        tuple file(mzml_file), file(library_file), file(fasta_file)

    output:
        tuple file("*.elib"), file("*.dia"), file("*.txt")

    script:
    // if no library file is given, there were no narrow files and we use walnut
    def walnut_flag = library_file.name == params.filter ? "-walnut" : "-l ${library_file}"
    """
    java -Djava.awt.headless=true ${params.memory} \\
        -jar /code/encyclopedia-${params.encyclopedia_version}-executable.jar \\
        -i ${mzml_file} \\
        -f ${fasta_file} \\
        ${walnut_flag}
    """
}

process run_encyclopedia_global {
    echo true
    publishDir "${params.experimentBucket}/${params.experimentName}/encyclopedia", mode: "copy"

    input:
        file local_files
        file mzml_files
        file fasta_file
        file library_file
        val output_postfix

    output:
        tuple file("*.elib"), file("*.txt")

    script:
    // if no library file is given, there were no narrow files and we use walnut
    def walnut_flag = library_file.name == params.filter ? "-walnut" : "-l ${library_file}"
    """
    java -Djava.awt.headless=true ${params.memory} \\
        -jar /code/encyclopedia-${params.encyclopedia_version}-executable.jar \\
        -libexport \\
        -o result-${output_postfix}.elib \\
        -i ./ \\
        -f ${fasta_file} \\
        ${walnut_flag}
    """
}

workflow encyclopedia_narrow {
    take: 
        data
        fasta
        dlib
    main:
        gunzip(data)
            .tap { unzipped_mzml }
            | combine(fasta.mix(dlib).collect())
            | run_encyclopedia_local
            | flatten
            | collect 
            | set { narrow_local_files }
        run_encyclopedia_global(narrow_local_files, unzipped_mzml | collect, fasta, dlib, params.narrow_output_postfix)
            | flatten
            | filter { it.name =~ /.*elib$/ }
            | set { narrow_elib }
    emit:
        narrow_elib
}

workflow encyclopedia_wide {
    take: 
        data
        fasta
        elib
    main:
        gunzip(data)
            .tap { unzipped_mzml }
            | combine(fasta.mix(elib).collect())
            | run_encyclopedia_local
            | flatten
            | collect 
            | set { wide_local_files }
        run_encyclopedia_global(wide_local_files, unzipped_mzml | collect, fasta, elib, params.wide_output_postfix)
            | flatten
            | filter { it.name =~ /.*elib$/ }
            | set { wide_elib }
    emit:
        wide_elib
}

workflow {
    input_files = Channel.of(
        ["210308_talus_01","Wide DIA"],
        ["210308_talus_02","Wide DIA"],
        // ["210308_talus_04","Narrow DIA"],
        // ["210308_talus_05","Narrow DIA"],
    )

    fasta = Channel.fromPath("${params.metadataBucket}/uniprot_human_25apr2019.fasta", checkIfExists: true)
    dlib = Channel.fromPath("${params.metadataBucket}/uniprot_human_25apr2019.fasta.z2_nce33.dlib", checkIfExists: true)

    // Create separate channels for narrow and wide files
    input_files
        .filter { it[1] == "Narrow DIA" }
        .map { file("${params.mzmlBucket}/narrow/${it[0].split('_')[0]}_MLLtx/${it[0]}.mzML.gz") }
        .set { narrow }
    input_files
        .filter { it[1] == "Wide DIA" }
        .map { file("${params.mzmlBucket}/wide/${it[0].split('_')[0]}_MLLtx/${it[0]}.mzML.gz") }
        .set { wide }
    // input_files
    //     .filter { it[1] == "Narrow DIA" }
    //     .map { file("${params.mzmlBucket}/${it[0].split('_')[0]}/${it[0]}.mzML.gz") }
    //     .set { narrow }
    // input_files
    //     .filter { it[1] == "Wide DIA" }
    //     .map { file("${params.mzmlBucket}/${it[0].split('_')[0]}/${it[0]}.mzML.gz") }
    //     .set { wide }

    // Run encyclopedia
    encyclopedia_narrow(narrow, fasta, dlib)
    // If no narrow files are given the output chr-elib will be empty 
    // and we use walnut instead.
    encyclopedia_narrow.out
        .ifEmpty(file("${params.metadataBucket}/${params.filter}"))
        .set { chr_elib }
    encyclopedia_wide(wide, fasta, chr_elib)
}