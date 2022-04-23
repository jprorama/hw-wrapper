#!/bin/bash

# run a training scale experirment for recsys18 hello-world
# uses dependency tree to break down learning tasks into shorter jobs

# submit scripts for job dependency submission

submit_cpu_task () {

    work=$1
    task=$2
    jobid=$3

    args="--job-name=$METHOD-$CNAME-$DATASET_${task} \
	  -n 1 -N 1 \
	  --time=11h \
	  --mem=8G \
	  --partition=amd-hdr100,intel-dcb,long \
	  --output=${resultsdir}/slurm-%j.out \
          --error=${resultsdir}/slurm-%j.out \
	  $miscargs"
    
    if [ "$jobid" != "" ]
    then
	$args="$args --dependency=afterok:$jobid"
    fi

    # create the job
    # https://stackoverflow.com/a/1655389/8928529
    read -r -d '' job << 'EOF'
#!/bin/bash

# exit when any command fails
set -e

# keep track of the last executed command
trap 'last_command=${current_command}; current_command=${BASH_COMMAND}' DEBUG
# echo an error message before exiting
trap 'if [ $? -ne 0 ]; then echo "\"${last_command}\" command failed with exit code $?."; fi' EXIT

# run the full training run to build the full data set
# cd to the argument directory

cd $trainrun

prefix=$prefixir


echo \*\*\* step: $task
"$work"

EOF

    # example wrapper for capuring job id
    # https://hpc.nih.gov/docs/job_dependencies.html
    sbr=`echo "$job" | sbatch "$args"`

    if [[ "$sbr" =~ Submitted\ batch\ job\ ([0-9]+) ]]; then
	jobid=`echo "${BASH_REMATCH[1]}"`
    else
	echo "sbatch failed: $task $subtask"
	exit 1
    fi

    func_result=$jobid
}

submit_train_task () {

    task=$1
    subtask=$2
    jobid=$3

    args="--job-name=$METHOD-$CNAME-$DATASET_${task}_${subtask} \
	  -n 28 -N 1 \
	  --time=11h \
	  --mem=239G \
	  --partition=pascalnodes \
	  --gpus-per-node=4 \
	  --exclusive \
	  --output=${resultsdir}/slurm-%j.out \
          --error=${resultsdir}/slurm-%j.out \
	  $miscargs"
    
    if [ "$jobid" != "" ]
    then
	$args="$args --dependency=afterok:$jobid"
    fi

    # create the job
    # https://stackoverflow.com/a/1655389/8928529
    read -r -d '' job << 'EOF'
#!/bin/bash

# exit when any command fails
set -e

# keep track of the last executed command
trap 'last_command=${current_command}; current_command=${BASH_COMMAND}' DEBUG
# echo an error message before exiting
trap 'if [ $? -ne 0 ]; then echo "\"${last_command}\" command failed with exit code $?."; fi' EXIT

# run the full training run to build the full data set
# cd to the argument directory

cd $trainrun

prefix=$prefixir


echo \*\*\* step: $task --$subtask
${dockrun} python3 $debug $prefix/main.py --dir $task --$subtask

EOF

    # example wrapper for capuring job id
    # https://hpc.nih.gov/docs/job_dependencies.html
    sbr=`echo "$job" | sbatch "$args"`

    if [[ "$sbr" =~ Submitted\ batch\ job\ ([0-9]+) ]]; then
	jobid=`echo "${BASH_REMATCH[1]}"`
    else
	echo "sbatch failed: $task $subtask"
	exit 1
    fi

    func_result=$jobid
}

submit_infer_task () {

    jobid=$1

    args="--job-name=$METHOD-$CNAME-$DATASET_${task}_${subtask} \
	  -n 28 -N 1 \
	  --time=11h \
	  --mem=239G \
	  --partition=pascalnodes \
	  --gpus-per-node=4 \
	  --exclusive \
	  --output=${resultsdir}/slurm-%j.out \
          --error=${resultsdir}/slurm-%j.out \
	  $miscargs"
    
    if [ "$jobid" != "" ]
    then
	$args="$args --dependency=afterok:$jobid"
    fi

    # create the job
    # https://stackoverflow.com/a/1655389/8928529
    read -r -d '' job << 'EOF'
#!/bin/bash

# exit when any command fails
set -e

# keep track of the last executed command
trap 'last_command=${current_command}; current_command=${BASH_COMMAND}' DEBUG
# echo an error message before exiting
trap 'if [ $? -ne 0 ]; then echo "\"${last_command}\" command failed with exit code $?."; fi' EXIT

# run the full training run to build the full data set
# cd to the argument directory

cd $trainrun

prefix=$prefixir


echo \*\*\* step: $task --$subtask

${dockrun} python3 $prefix/main.py --dir 0to1_inorder --challenge  
${dockrun} python3 $prefix/main.py --dir 5_inorder --challenge  
${dockrun} python3 $prefix/main.py --dir 10to100_inorder --challenge  
${dockrun} python3 $prefix/main.py --dir 25to100_random --challenge  

${dockrun} python3 $prefix/merge_results.py

EOF

    # example wrapper for capuring job id
    # https://hpc.nih.gov/docs/job_dependencies.html
    sbr=`echo "$job" | sbatch "$args"`

    if [[ "$sbr" =~ Submitted\ batch\ job\ ([0-9]+) ]]; then
	jobid=`echo "${BASH_REMATCH[1]}"`
    else
	echo "sbatch failed: $task $subtask"
	exit 1
    fi

    func_result=$jobid
}


#
# main ()
#

PATH=`pwd`:$PATH
prefixdir=~/projects/recsys18-codes/hello-world

trainsetsize=$1
lr_dae=${2:-0.005}
lr_pretrain=${3:-0.01}
tag=$4
tf_container_ver=${5:-21.08}
resultsdir=${6:-.}

# suppress noisy infomation messages from tensorflow
export TF_CPP_MIN_LOG_LEVEL=1

# run in docker container
#dockrun="docker run --gpus all -it -v /home:/home -w $(pwd) --dns 8.8.8.8 nvcr.io/nvidia/tensorflow:21.08-tf1-py3"
#dockrun="nvidia-docker run --shm-size=1g --ulimit memlock=-1 --ulimit stack=67108864 \
#	--gpus all -it -v /home:/home -w $(pwd) --dns 8.8.8.8 nvcr.io/nvidia/tensorflow:${tf_container_ver}-tf1-py3"

# with singularity you need to explicitly import env vars
export SINGULARITYENV_PATH=$PATH
export SINGULARITYENV_LD_LIBRARY_PATH=$LD_LIBRARY_PATH
export SINGULARITYENV_TF_CPP_MIN_LOG_LEVEL=$TF_CPP_MIN_LOG_LEVEL
#dockrun="singularity run --nv -B /cm tensorflow_latest-gpu.sif"
# explicity pull the image first
# singularity pull tensorflow_${tf_container_ver}-tf1-py3.sif docker://nvcr.io/nvidia/tensorflow:${tf_container_ver}-tf1-py3
dockrun="singularity run --nv -B /cm -B /data/user/$USER tensorflow_${tf_container_ver}-tf1-py3.sif"

# check python env
#$dockrun python3 ./py-env.py


# create experiment dirs to house results <code>_<chal>: hw_mympd-full and hw_mpd
#mkdir -p hw_mympd-full hw_mpd
# get challenge data sets
# they are in challenge/
for size in $trainsetsize
do
	# get trainset
	trainset=mympd-full-${size}k
	srctrainset=$trainset
	if [ "$tag" != "" ]
	then
		trainset=${trainset}_${tag}
	fi

	#rclone copy lts:mpd-datasets/${srctrainset} ${trainset}
	cp -r ~/projects/mpd-test-sets/data/${srctrainset} ${trainset}
	chmod -R u+w ${trainset}

	# create trainrun from template <code>_<chal>_<trainset>: hw_mympd-full_mympd-full-20k
	trainrun=hw_${trainset}
	exp_path=`pwd`/$trainrun

	cp -r exp-template ${trainrun}
	for file in ${trainrun}/*/config.ini
	do
		sed -i -e "s|EXP_PATH|${exp_path}|" $file
		sed -i -e "s|LR_DAE|${lr_dae}|" $file
		sed -i -e "s|LR_PRETRAIN|${lr_pretrain}|" $file
	done
	# complete the templates missing dirs
	mkdir ${trainrun}/challenge
	mkdir ${trainrun}/mpd_train
	mkdir ${trainrun}/mpd_test

	# provide a test subset for validation
	train-test-split.sh $trainset

	# record time for start of experiment
	DATESTR=`date +'%Y-%m-%dT%H:%M:%S'`

	trained=0
	loopcnt=0
	for challenge in mympd-full mpd
	do

	        read -r -d '' work << 'EOF'
		# create output dir for experiment
		experiment=${resultsdir}/hw_${challenge}
		if [ "$tag" != "" ]
		then
			experiment=${experiment}_${tag}
		fi
		mkdir -p $experiment


		cp challenge/${challenge}-challenge_set.json $trainrun/challenge/challenge_set.json

	        # run data_gen $trainrun
		echo \*\*\* step: ./run-dataprep.sh $trainrun $prefixdir
		$dockrun ./run-dataprep.sh $trainrun $prefixdir 
		if [ $? -ne 0 ]
		then
			echo "dataprep failed!"
			exit 1
		fi

               	EOF

                submit_cpu_task("$work", "dataprep", $jobid)
		lastjobid=$func_result
		
		# train if not trained
		if [ $trained -eq 0 ]
		then
		    for step in  0to1_inorder:pretrain  0to1_inorder:title \
							copy_title_graph \
							5_inorder:pretrain  5_inorder_dae \
							10to100_inorder_pretrain  10to100_inorder_dae \
							25to100_random_pretrain 25to100_random_pretrain
		    do

			task=`echo $step | cut -d: -f1`
			subtask=`echo $step | cut -d: -f2`


			submit_train_task($task, $subtask, $lastjobid)
			lastjobid=$func_result
			
			if [ "$joblist" == "" ]
			then
			    joblist="$lastjobid"
			else
			    joblist="$joblist:$lastjobid"
			if
		    done

		    # carry the jobs to the next step
		    # this synchronizes the training work to a common step
		    lastjobid=$joblist

		fi

		# run inference
		submit_infer_task($lastjobid)
		lastjobid=$func_result
		
		read -r -d '' work << 'EOF'
		# collect results
		# don't gzip in batch
		#gzip -f $trainrun/results.csv
		mv $trainrun/results.csv $experiment/method-hw_${challenge}_${srctrainset}_${DATESTR}_slurm-${SLURM_JOBID}.csv
	
		# preserve model
		tar -czf $experiment/${trainrun}_${DATESTR}.tar.gz $trainrun/[0125]* $trainrun/tf_logs/

                EOF

		submit_cpu_task($lastjobid)
		lastjobid=$func_result

	done

	read -r -d '' work << 'EOF'

	# remove files owned by container and caller
	${dockrun} rm -rf $trainrun
	rm -rf $trainrun $trainset


       	EOF
	submit_cpu_task($lastjobid, "workdir_cleanup")
	lastjobid=$func_result

done

echo $lastjobid > $experiment/lastjob-${SLURM_JOBID}
