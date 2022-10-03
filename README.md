# nf-encyclopedia

nf-encyclopedia is a NextFlow pipeline for specifically designed to analyze DIA proteomics experiment that leverage chromatogram libraries; however it is perfectly suited to analyze DIA proteomics experiments without chromatogram libraries as well. 
The nf-encyclopedia connects three, open-source tools---MSconvert, EncyclopeDIA, and MSstats---to go from mass spectra to quantified peptides and proteins. 

See the [nf-encyclopedia documentation](https://TalusBio.github.io/nf-encyclopedia)

## Development
### Running Tests
We use the [pytest](https://docs.pytest.org/en/7.0.x/contents.html) Python package to run our tests. It can be installed either with either pip:

```sh
pip install pytest
```

or conda:

``` sh
conda install pytest
```

Once installed, tests can be run from the root directory of the workflow. These tests use the process stubs to test the workflow logic, but do not test the commands for the tools themselves. Run them with:

``` sh
pytest
```

## References

This pipeline uses code and infrastructure developed and maintained by the [nf-core](https://nf-co.re) initiative, and reused here under the [MIT license](https://github.com/nf-core/tools/blob/master/LICENSE).

> The nf-core framework for community-curated bioinformatics pipelines.
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> Nat Biotechnol. 2020 Feb 13. doi: 10.1038/s41587-020-0439-x.

## Credits

This pipeline was originally written by @ricomnl and @wfondrie at Talus Bio. 
Additionally, @cia23 has spent numerous hours reviewing @wfondrie's messy PRs and performing validation experiments. 

