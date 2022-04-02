#!/bin/sh

# run the full training run to build the full data set
# cd to the argument directory

cd $1

prefix=${2:-..}

#python3 ../../data_generator.py  
python3 $prefix/main.py --dir 0to1_inorder --pretrain  
python3 $prefix/main.py --dir 0to1_inorder --title  
# copy 0to1_inorder/graph to 5_inorder #
cp -r  0to1_inorder/graph 5_inorder
python3 $prefix/main.py --dir 5_inorder --pretrain  
python3 $prefix/main.py --dir 5_inorder --dae  
# copy 0to1_inorder/graph to 10to100_inorder #
cp -r  0to1_inorder/graph 10to100_inorder
python3 $prefix/main.py --dir 10to100_inorder --pretrain  
python3 $prefix/main.py --dir 10to100_inorder --dae  
# copy 0to1_inorder/graph to 25to100_inorder #
cp -r  0to1_inorder/graph 25to100_random
python3 $prefix/main.py --dir 25to100_random --pretrain  
python3 $prefix/main.py --dir 25to100_random --dae  


