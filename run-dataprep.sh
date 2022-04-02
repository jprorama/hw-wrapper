#!/bin/bash

# run data prep to generate data files for experiments


cd $1

prefix=${2:-..}

python3 $prefix/data_generator.py
