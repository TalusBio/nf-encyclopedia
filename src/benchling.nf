nextflow.enable.dsl = 2

workflow run_files_for_peptides {
    take:
        peptide_list
    main:
        input_peptides = peptide_list
            .collect { "'" + it + "'" }
            .join(",")
        
        query = """
        SELECT DISTINCT run.name\$ AS "Run", run.acquisition_type as "Acquisition Type"
        FROM runs\$raw run
        LEFT JOIN peptide ON peptide.id = ANY(ARRAY(SELECT jsonb_array_elements_text(run.digestion_id)))
        WHERE peptide.name\$ IN (
            ${input_peptides}
        );
        """
        channel.sql.fromQuery(query, db: "benchling")
            .set { run_file_list }
    emit:
        run_file_list
}

workflow {
    peptide_list = [
        "MLLTx_S1_Chrom1_Peptide",
        "MLLTx_S2_Chrom1_Peptide",
        "MLLTx_S3_Chrom1_Peptide",
        "MLLTx_S4_Chrom1_Peptide",
        "MLLTx_S5_Chrom1_Peptide",
        "MLLTx_S6_Chrom1_Peptide",
        "MLLTx_S1_Chrom2_Peptide",
        "MLLTx_S2_Chrom2_Peptide",
        "MLLTx_S3_Chrom2_Peptide",
        "MLLTx_S4_Chrom2_Peptide",
        "MLLTx_S5_Chrom2_Peptide",
        "MLLTx_S6_Chrom2_Peptide",
    ]
    
    run_files_for_peptides(peptide_list)
    run_files_for_peptides.out.view()
}