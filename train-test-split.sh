#!/bin/bash

# split the data into train test set by moving slice files into test dir
# until testsize target is reached.

trainset=${1}
testsize=${2:-3000}
exp=${3:-hw}

expdir=${exp}_${trainset}

total=0

# move slice files to test until we reach our testsize target
for file in ${trainset}/data/mpd.slice.*.json
do
  pidcnt=`grep 'pid":' $file | wc -l`
  total=`expr ${total:-0} + ${pidcnt}`
  mv $file ${expdir}/mpd_test/
  if [ $total -gt $testsize ]
  then
    echo "testsize: " $total
    break
  fi
done

# use the remainder as the training set
mv ${trainset}/data/mpd.slice.*.json  ${expdir}/mpd_train/
