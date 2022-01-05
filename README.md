# MapDbSNP

* UNIX commands and Rscripts will add positions to data that only contains dbSNP IDs
* Will download dbSNP151 from UCSC genome browser and prepare files for future runs (~90 GB hard disk space)

## Required R packages

* data.table
* optparse
* parallel
* here


## Usage

```{bash}
Rscript ./script/positionsFromDBSNP.r [options]
```

### Options:

--input=path to file with dbSNP IDs, e.g. summary statistics  
--ID=column name with dbSNP IDs  
--build=Genome Build: hg19 or hg38  
--outdir=Path of output directory  
--prefix=Prefix for output file name without path or extension  
--cpus=Number of available CPUs for parallel runs (uses up to 64 for hg19 or 68 for hg38)  
--skip=Skip lines of input file  

## Example command line:
```{bash}
Rscript ./script/positionsFromDBSNP.r \
--input=./example/example_input.txt \
--ID=ID \
--build=hg19 \
--outdir=./example \
--prefix=example \
--cpus=16
```
