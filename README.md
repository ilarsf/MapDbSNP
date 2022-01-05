# MapDbSNP
Add positions to data that only contains dbSNP IDs 

## Required R packages

* data.table
* optparse
* parallel
* here

```
Rscript ./script/positionsFromDBSNP.r \
--input=./example/example_input.txt \
--ID=ID \
--build=hg19 \
--outdir=./example \
--prefix=example \
--cpus=16
```
