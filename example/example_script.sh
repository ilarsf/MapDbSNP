#!/bin/bash

Rscript /net/junglebook/home/larsf/Projects/MapDbSNP/script/positionsFromDBSNP.r \
--input=/net/junglebook/home/larsf/Projects/MapDbSNP/example/example_input.txt \
--ID=ID \
--build=hg19 \
--outdir=/net/junglebook/home/larsf/Projects/MapDbSNP/example \
--prefix=example \
--cpus=4
