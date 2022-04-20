#!/bin/bash

#This script performs spatial smoothing of the input functional data 
#

# Extract temporal mean before performing spatial filtering 
fslmaths $func_data_in -Tmean mean_func

# Use mean_func as the usan and determine its median intensity value within the brain mask
# FWHM = 2.355 sigma, hence sigma = FWHM / 2.355
sigma=$(echo "$fwhm / 2.355" | bc -l)
median=`fslstats $func_data_in -k mask -p 50`
bright_thr=$(echo "$median * 0.75" | bc -l)
median_usan=`fslstats mean_func -k mask -p 50`
bright_thr_usan=$(echo "$median_usan * 0.75" | bc -l)
susan $func_data_in $bright_thr $sigma 3 1 1 mean_func $bright_thr_usan $func_data_out
fslmaths $func_data_out -mas mask $func_data_out

# Intensity normalization to ensure that final data has median ~ 10 000
# Median is already close to what it should be for higher level analysis but still it is better to perform this step 
median=`fslstats $func_data_out -k 'mask' -p 50` 
fac=$(echo "10000 / $median" | bc -l)
fslmaths $func_data_out -mul $fac $func_data_out