#!/bin/bash

# https://intoli.com/blog/exit-on-errors-in-bash-scripts/
# exit when any command fails
set -e

# keep track of the last executed command
trap 'last_command=${current_command}; current_command=${BASH_COMMAND}' DEBUG
# echo an error message before exiting
trap 'if [ $? -ne 0 ]; then echo "\"${last_command}\" command failed with exit code $?."; fi' EXIT

# uncomment to debug
#debug="-m pdb"

# run the full training run to build the full data set
# cd to the argument directory

cd $1

prefix=${2:-..}

#python3 ../../data_generator.py
echo \*\*\* step: 0to1_inorder --pretrain
python3 $debug $prefix/main.py --dir 0to1_inorder --pretrain
echo \*\*\* step: 0to1_inorder --title
python3 $debug $prefix/main.py --dir 0to1_inorder --title
# copy 0to1_inorder/graph to 5_inorder #
cp -r  0to1_inorder/graph 5_inorder
echo \*\*\* step: 5_inorder --pretrain
python3 $debug $prefix/main.py --dir 5_inorder --pretrain
echo \*\*\* step: 5_inorder --dae
python3 $debug $prefix/main.py --dir 5_inorder --dae
# copy 0to1_inorder/graph to 10to100_inorder #
cp -r  0to1_inorder/graph 10to100_inorder
echo \*\*\* step: 10to100_inorder --pretrain
python3 $debug $prefix/main.py --dir 10to100_inorder --pretrain
echo \*\*\* step: 10to100_inorder --dae
python3 $debug $prefix/main.py --dir 10to100_inorder --dae
# copy 0to1_inorder/graph to 25to100_inorder #
cp -r  0to1_inorder/graph 25to100_random
echo \*\*\* step: 25to100_random --pretrain
python3 $debug $prefix/main.py --dir 25to100_random --pretrain
echo \*\*\* step: 25to100_random --dae
python3 $debug $prefix/main.py --dir 25to100_random --dae


