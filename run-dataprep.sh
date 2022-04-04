#!/bin/bash

# run data prep to generate data files for experiments

# https://intoli.com/blog/exit-on-errors-in-bash-scripts/
# exit when any command fails
set -e

# keep track of the last executed command
trap 'last_command=${current_command}; current_command=${BASH_COMMAND}' DEBUG
# echo an error message before exiting
trap 'if [ $? -ne 0 ]; then echo "\"${last_command}\" command failed with exit code $?."; fi' EXIT

# uncomment to debug
#debug="-m pdb"

cd $1

prefix=${2:-..}

echo \*\*\* step: data_generator.py
python3 $debug $prefix/data_generator.py
