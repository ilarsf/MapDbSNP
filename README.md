# MapDbSNP

* UNIX commands and Rscripts will add positions to data that only contains dbSNP IDs
* Will download dbSNP151 from UCSC genome browser and prepare files for future runs (~90 GB hard disk space)

## Required R packages

* data.table
* optparse
* parallel
* here

``` {bash}
Rscript ./script/positionsFromDBSNP.r \
--input=./example/example_input.txt \
--ID=ID \
--build=hg19 \
--outdir=./example \
--prefix=example \
--cpus=16
```
