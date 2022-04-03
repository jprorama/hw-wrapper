#!/bin/bash

# run a training scale experirment for recsys18 hello-world

PATH=`pwd`:$PATH
prefixdir=~/projects/recsys18-codes/hello-world

trainsetsize=$1


# run in docker container
dockrun="docker run --gpus all -it -v /home:/home -w $(pwd) --dns 8.8.8.8 nvcr.io/nvidia/tensorflow:21.08-tf1-py3"

# create experiment dirs to house results <code>_<chal>: hw_mympd-full and hw_mpd
mkdir -p hw_mympd-full hw_mpd
# get challenge data sets
# they are in challenge/
for size in $trainsetsize
do
	# get trainset
	trainset=mympd-full-${size}k

	rclone copy lts:mpd-datasets/${trainset} ${trainset}

	# create trainrun from template <code>_<chal>_<trainset>: hw_mympd-full_mympd-full-20k
	trainrun=hw_${trainset}
	exp_path=`pwd`/$trainrun

	cp -r exp-template ${trainrun}
	for file in ${trainrun}/*/config.ini
	do
		sed -i -e "s|EXP_PATH|${exp_path}|" $file
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
		experiment=hw_$challenge

		cp challenge/${challenge}-challenge_set.json $trainrun/challenge/challenge_set.json

	        # run data_gen $trainrun
		$dockrun ./run-dataprep.sh $trainrun $prefixdir
		if [ $? -ne 0 ]
		then
			echo "dataprep failed!"
			exit 1
		fi	


		# train if not trained
		if [ $trained -eq 0 ]
		then
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

