#!/bin/sh

# run only the inference step to build results against 
# single challenge subdir
# cd to the argument directory

cd $1

prefix=${2:-..}

python3 $prefix/main.py --dir 0to1_inorder --challenge  
python3 $prefix/main.py --dir 5_inorder --challenge  
python3 $prefix/main.py --dir 10to100_inorder --challenge  
python3 $prefix/main.py --dir 25to100_random --challenge  

python3 $prefix/merge_results.py

