#!/bin/bash

# run a training scale experirment for recsys18 hello-world

PATH=`pwd`:$PATH
prefixdir=~/projects/recsys18-codes/hello-world

trainsetsize=$1
lr_dae=${2:-0.005}
lr_pretrain=${3:-0.01}
tag=$4
tf_container_ver=${5:-21.08}
resultsdir=${6:-.}


# run in docker container
#dockrun="docker run --gpus all -it -v /home:/home -w $(pwd) --dns 8.8.8.8 nvcr.io/nvidia/tensorflow:21.08-tf1-py3"
#dockrun="nvidia-docker run --shm-size=1g --ulimit memlock=-1 --ulimit stack=67108864 \
#	--gpus all -it -v /home:/home -w $(pwd) --dns 8.8.8.8 nvcr.io/nvidia/tensorflow:${tf_container_ver}-tf1-py3"

# with singularity you need to explicitly import env vars
export SINGULARITYENV_PATH=$PATH
export SINGULARITYENV_LD_LIBRARY_PATH=$LD_LIBRARY_PATH
#dockrun="singularity run --nv -B /cm tensorflow_latest-gpu.sif"
# explicity pull the image first
# singularity pull tensorflow_${tf_container_ver}-tf1-py3.sif docker://nvcr.io/nvidia/tensorflow:${tf_container_ver}-tf1-py3
dockrun="singularity run --nv -B /cm -B /data/user/$USER tensorflow_${tf_container_ver}-tf1-py3.sif"

# check python env
$dockrun python3 ./py-env.py

# create experiment dirs to house results <code>_<chal>: hw_mympd-full and hw_mpd
mkdir -p hw_mympd-full hw_mpd
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

	rclone copy lts:mpd-datasets/${srctrainset} ${trainset}

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
	for challenge in mympd-full mpd
	do
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


		# train if not trained
		if [ $trained -eq 0 ]
		then
			echo \*\*\* step: ./run-train.sh  $trainrun $prefixdir
			$dockrun ./run-train.sh  $trainrun $prefixdir
			if [ $? -eq 0 ]
			then
				trained=1
			else
				echo "training failed!"
				exit 1
			fi
		fi

		# run inference
		echo \*\*\* step: ./run-inf.sh $trainrun $prefixdir
		$dockrun ./run-inf.sh $trainrun $prefixdir
		if [ $? -ne 0 ]
		then
			echo "inference failed!"
			exit 1
		fi
		
		# collect results
		gzip -f $trainrun/results.csv
		mv $trainrun/results.csv.gz $experiment/method-hw_${challenge}_${trainset}_${DATESTR}_$notag.csv.gz
	
		# preserve model
		tar -czf $experiment/${trainrun}_${DATESTR}.tar.gz $trainrun/[0125]*
	done

	# remove files owned by container and caller
	${dockrun} rm -rf $trainrun
	rm -rf $trainrun $trainset

done

