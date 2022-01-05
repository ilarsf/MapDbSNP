#!/bin/bash

Rscript ./script/positionsFromDBSNP.r \
--input=./example/example_input.txt \
--ID=ID \
--build=hg19 \
--outdir=./example \
--prefix=example \
--cpus=16
