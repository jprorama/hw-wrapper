#
# check and see what the python environment looks like

import sys
print (sys.path)

import os
import numpy
os.path.abspath(numpy.__file__)
import tensorflow
os.path.abspath(tensorflow.__file__) 
