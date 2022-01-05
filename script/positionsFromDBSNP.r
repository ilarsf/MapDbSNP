library("data.table")
library("optparse")
library("parallel")
library("here")

# Extend timeout to 60 min for download
options(timeout=3600)

source("./script/function.runParallel.r")

option_list <- list(
  make_option("--input", type="character", default="", help="file with summary statistics"),
  make_option("--ID", type="character", default="ID", help="column name with SNP ID"),
  make_option("--build", type="character", default="hg19", help="Genome Build, hg19 or hg38"),
  make_option("--outdir", type="character", default="", help="Output directory"),
  make_option("--prefix", type="character", default="", help="Prefix for output file name without path"),
  make_option("--cpus", type="integer", default=6,help="CPUs"),
  make_option("--skip", type="integer", default=0,help="Skip lines")
)
parser <- OptionParser(usage="%prog [options]", option_list=option_list)
args <- parse_args(parser, positional_arguments = 0)
opt <- args$options
print(t(data.frame(opt)))

dbsnp_hg19_filtered <- "./data/snp151_hg19_filtered.txt"
dbsnp_hg38_filtered <- "./data/snp151_hg38_filtered.txt"
RsMerge <- "./data/RsMergeArch.bcp"

if(!file.exists("./data")) dir.create("./data")

if(!file.exists(RsMerge)){
	download.file(url="ftp://ftp.ncbi.nlm.nih.gov/snp/organisms/human_9606/database/organism_data/RsMergeArch.bcp.gz",
		destfile="./data/RsMergeArch.bcp.gz")
	system("gzip -d ./data/RsMergeArch.bcp.gz")
}

if(!file.exists(dbsnp_hg19_filtered)){
	dbsnp_hg19 <- "./data/snp151_hg19.txt.gz"
	if(!file.exists(dbsnp_hg19)) download.file(url="https://hgdownload.soe.ucsc.edu/goldenPath/hg19/database/snp151.txt.gz",
		destfile=dbsnp_hg19)
	cmdLine <- paste("pigz -p 4 -dc ",dbsnp_hg19,
		"| cut -f 2-5",  # only keep position and ID
		"| grep -v -e Un_ -e hap -e random -e Y -e fix -e alt -e M\t", # remove alternative chromosomes
		"| sed 's/chr//g' >",dbsnp_hg19_filtered)
	if(!file.exists(dbsnp_hg19_filtered)) system(cmdLine)

	# split file to speed up lookup
	cmdLine <- paste("split --suffix-length=3 --numeric-suffixes --lines=10000000",
		dbsnp_hg19_filtered,
		gsub(".txt","",dbsnp_hg19_filtered))
	system(cmdLine)	
	file.remove(dbsnp_hg19)
}

if(!file.exists(dbsnp_hg38_filtered)){
	dbsnp_hg38 <- "./data/snp151_hg38.txt.gz"
	if(!file.exists(dbsnp_hg38)) download.file(url="https://hgdownload.soe.ucsc.edu/goldenPath/hg38/database/snp151.txt.gz",
		destfile=dbsnp_hg38)
	cmdLine <- paste("pigz -p 4 -dc ",dbsnp_hg38,
		"| cut -f 2-5", # only keep position and ID
		"| grep -v -e Un_ -e hap -e random -e Y -e fix -e alt -e M\t", # remove alternative chromosomes
		"| sed 's/chr//g' >",dbsnp_hg38_filtered)
	if(!file.exists(dbsnp_hg38_filtered)) system(cmdLine)

	# split file to speed up lookup
	cmdLine <- paste("split --suffix-length=3 --numeric-suffixes --lines=10000000",
		dbsnp_hg38_filtered,
		gsub(".txt","",dbsnp_hg38_filtered))
	system(cmdLine)	
	file.remove(dbsnp_hg38)
}


ID <- opt$ID
input <- opt$input
outdir <- opt$outdir
prefix <- opt$prefix
cpus <- opt$cpus
build <- opt$build
setDTthreads(cpus)

dbsnp_filtered <- paste0("./data/snp151_",build,"_filtered.txt")

if(opt$skip > 0) {
	stripped <- tempfile()
	system(paste0("tail -n +",opt$skip+1," ",input," > ",stripped))
	input <- stripped
}

header <- fread(input,nrow=2)
rscolumn <- which(names(header) == ID)

# part 1: update outdated rsIDs
print("Checking / replacing outdated dbSNP IDs")
updated1 <- fread(cmd = paste(
	paste0("awk -v col=",rscolumn," -f ./script/RsMerge_awk.txt"),
	RsMerge,
	input),sep="\t",header=T)
temp1 <- tempfile()
snpids <- as.character(updated1[[ID]])
snpids <- snpids[grep("^rs",snpids)]
write(snpids,temp1)

# part 2: extract positions from dbSNP 151
print("Extracting positions based on dbSNP ID")
dbsnp <- list.files(paste0(here(),"/data"),gsub(".txt","\\1[0-9]+",basename(dbsnp_filtered)),full.name=T)
outfiles <- tempfile(paste0(basename(dbsnp),"_"))
cmdLines <- paste(
	paste0("awk -f ",here(),"/script/Extract_SNPs_dbSNP_awk.txt"),
	temp1,
	dbsnp,
	">",outfiles)

runParallel(cmdLines,min(cpus,64))

print("Process and combine input / output")
# only read non-empty files
outfiles <- outfiles[file.info(outfiles)$size > 0]
snppos <- list()
for(i in 1:length(outfiles)){
	snppos[[i]] <- fread(outfiles[i],header=F,col.names=c("CHROM","POS0","POS",ID))
}
snppos <- rbindlist(snppos)

# zero based start positions
setnames(updated1,c("CHROM","POS0","POS"),c("CHROM_old","POS0_old","POS_old"),skip_absent=T)

updated2 <- merge(snppos,updated1,by=ID)
noMatch <- which(!updated1[[ID]] %in% snppos[[ID]])
if(length(noMatch) >0) fwrite(updated1[noMatch,],paste0(outdir,"/",prefix,"_noMatch_dbSNP151.txt"),sep="\t",quote=F)

# Use zero based positions for larger indels to match VCF nomenclature
indels <- which(updated2$POS - updated2$POS0 > 1)
if(length(indels)>0) updated2[indels,POS:=POS0]
updated2[,POS0:=NULL]

suppressWarnings(updated2 <- updated2[order(as.numeric(CHROM),POS),])
fwrite(updated2,paste0(outdir,"/",prefix,"_dbSNP151_",build,".txt"),sep="\t",quote=F)
