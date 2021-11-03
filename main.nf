#!/usr/bin/env nextflow
include { msconvert } from "./modules/msconvert.nf"

nextflow.enable.dsl = 2

FILTER = "NO_FILE"

process run_encyclopedia_local {
    echo true
    publishDir "${params.experimentBucket}/${params.experimentName}/encyclopedia", mode: "copy"

    input:
        file mzml_gz_file
        each file(library_file)
        each file(fasta_file)

    output:
        tuple file("*.elib"), file("*.dia"), file("*{features,encyclopedia,decoy}.txt")

    script:
    def mzml_file = mzml_gz_file.name.replaceAll(/\.gz/, "")
    """
    gzip -d ${mzml_gz_file}
    java -Djava.awt.headless=true ${params.encyclopedia.memory} \\
        -jar /code/encyclopedia-${params.encyclopedia.version}-executable.jar \\
        -i ${mzml_file} \\
        -f ${fasta_file} \\
        -l ${library_file} \\
        ${params.encyclopedia.local_options}
    """
}

process run_encyclopedia_global {
    echo true
    publishDir "${params.experimentBucket}/${params.experimentName}/encyclopedia", mode: "copy"

    input:
        file local_files
        file mzml_gz_files
        file library_file
        file fasta_file
        val output_postfix

    output:
        tuple file("*.elib"), file("*{peptides,proteins}.txt")

    script:
    """
    find . -type f -name '*.gz' -exec gzip -d {} \\;
    java -Djava.awt.headless=true ${params.encyclopedia.memory} \\
        -jar /code/encyclopedia-${params.encyclopedia.version}-executable.jar \\
        -libexport \\
        -o result-${output_postfix}.elib \\
        -i ./ \\
        -f ${fasta_file} \\
        -l ${library_file} \\
        ${params.encyclopedia.global_options}
    """
}

workflow encyclopedia_narrow {
    take: 
        mzml_gz_files
        dlib
        fasta
    main:
        run_encyclopedia_local(mzml_gz_files, dlib, fasta)
            | flatten
            | collect 
            | set { narrow_local_files }
        run_encyclopedia_global(narrow_local_files, mzml_gz_files | collect, dlib, fasta, params.encyclopedia.narrow_lib_postfix)
            | flatten
            | filter { it.name =~ /.*elib$/ }
            | set { narrow_elib }
    emit:
        narrow_elib
}

workflow encyclopedia_wide {
    take: 
        mzml_gz_files
        elib
        fasta
    main:
        run_encyclopedia_local(mzml_gz_files, elib, fasta)
            | flatten
            | collect 
            | set { wide_local_files }
        run_encyclopedia_global(wide_local_files, mzml_gz_files | collect, elib, fasta, params.encyclopedia.wide_lib_postfix)
            | flatten
            | filter { it.name =~ /.*elib$/ }
            | set { wide_elib }
    emit:
        wide_elib
}

workflow {
    // Get .fasta and .dlib from metadata-bucket
    fasta = Channel.fromPath("${params.metadataBucket}/${params.encyclopedia.fasta}", checkIfExists: true)
    dlib = Channel.fromPath("${params.metadataBucket}/${params.encyclopedia.dlib}", checkIfExists: true)

    // Get input paths and create separate channels for narrow and wide files
    input_paths = Channel.of(params.input_paths)
    // Create a mapping from file_key to file_type
    input_paths
        .splitCsv()
        .tap { raw_files }
        | map { raw_file, file_type ->
            def file_key = raw_file.tokenize("/")[-1].tokenize(".")[0]
            return tuple(file_key, file_type)
        }
        | set { file_key_types }
    // Convert all files using msconvert and get the original
    // file types back by merging it with the file_key_types.
    // Finally split the set of files into narrow and wide.
    raw_files
        | map { file_name, file_type -> file(file_name) }
        | msconvert
        | map { mzml_gz_file ->
            def file_key = mzml_gz_file.getBaseName().tokenize(".")[0]
            return tuple(file_key, mzml_gz_file)
        }
        | join(file_key_types)
        | branch { file_key, mzml_gz_file, file_type ->
            narrow: file_type == "Narrow DIA"
                return mzml_gz_file
            wide: file_type == "Wide DIA"
                return mzml_gz_file
        }
        | set { mzml_gz_files }

    // Run encyclopedia
    encyclopedia_narrow(mzml_gz_files.narrow, dlib, fasta)
    // If no narrow files are given the output chr-elib will be empty and we use the dlib instead.
    encyclopedia_narrow.out
        .ifEmpty(dlib)
        .set { chr_elib }
    encyclopedia_wide(mzml_gz_files.wide, chr_elib, fasta)
}