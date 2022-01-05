runParallel <- function(cmdLines,resources=0.5){
	require("parallel")	
	if(resources <= 0) stop("Misspecified resources")
	if(length(cmdLines) == 0) stop("No jobs specified")

	# https://stackoverflow.com/questions/41024035/detect-available-and-idle-cores-in-r
	# total cores
	N_CORES <- detectCores()

	# create list for readable lapply output
	cores <- lapply(1:N_CORES, function(x) x - 1)
	names(cores) <- paste0('CPU', 1:N_CORES - 1)

	# use platform specific system commands to get idle time
	proc_idle_time <- lapply(cores, function(x) {
	  if (.Platform$OS.type == 'windows') {
		out <- system2(
		  command = 'typeperf', 
		  args = c('-sc', 1, sprintf('"\\processor(%s)\\%% idle time"', x)),
		  stdout = TRUE)
		idle_time <- strsplit(out[3], ',')[[1]][2]
		idle_time <- as.numeric(gsub('[^0-9.]', '', idle_time))
	  } else {
		# assumes linux
		out <- system2(
		  command = 'mpstat', 
		  args = c('-P', x),
		  stdout = TRUE)
		idle_time <- as.numeric(unlist(strsplit(out[4], ' {2,}'))[12])
	  }
	  idle_time
	})
	
	# use CPUs that are idle about 80 %
	maxCores <- length(which(proc_idle_time > 80))
	
	if(length(cmdLines) == 1 | maxCores == 1 | resources == 1){
		print(paste("Running",length(cmdLines),"job(s) on 1 core"))
		for(j in 1:length(cmdLines)) system(cmdLines[j])
	} else {
		if(resources > 0 & resources < 1){
			ncores <- max(1,floor(maxCores*resources))
		} else if (resources > 1){
			ncores <- as.integer(min(maxCores,resources))
		}

		if(!file.exists(tempdir())) dir.create(tempdir())
	
		ncores <- min(ncores,length(cmdLines))
		okfiles <- paste0(tempdir(),"/Check_",formatC(1:length(cmdLines),width=5,flag=0))
		cmdLines <- paste0(cmdLines,"; touch ",okfiles)
		print(paste("Running",length(cmdLines),"jobs on",ncores,"cores"))
		errors <- unlist(parallel::mclapply(cmdLines,system, mc.cores=ncores, mc.preschedule=F))
		failedjobs <- length(which(errors > 0 | !file.exists(okfiles)))
		file.remove(okfiles)
		if(failedjobs > 0){
			stop(paste(failedjobs,"jobs failed"))
		}
	}
	print("Done")
}
