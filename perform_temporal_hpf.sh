#!/bin/bash

#This script performs temporal high-pass filtering of the input functional data 

fslmaths $func_data_in -Tmean tempMean
hp_sigma=$(echo "1 / (2 * $TR * $hp_freq)" | bc -l)
fslmaths $func_data_in -bptf $hp_sigma -1 -add tempMean $func_data_out
rm tempMean*