#!/bin/bash

# This script performs the first part of the pre-processing pipeline - independent component analysis 
#
# Analysis inputs, specified in the begining of the script:
#   pe_dir: phase enconding direction
#   subj_ist: list of subjects to be analysed 
#
# Inputs in PREPROCESS/$subj/$pedir_dir directory:
#    unwarp: directory containing all transformations going from EF_D space to EF_U space, and vice-versa
#    example_func: middle volume of epi, in EF_U space 
#    filtered_func_data: 4D data, in EF_U space, corrected for motion artifacts, high-pass filtered 
#    mean_func: 3D image, temporal mean of filtered_func_data
#    mask: brain mask in EF_U space, output of BET (plus some processing operations)
#    highres: structural image, same as input 
#    highres_bet: structural image, brain extracted, same as input
#
# Outputs in PREPROCESS/$subj/$pedir_dir/mel.ica directory:
#    mc directory
#    reg directory: example_func2highres, highres2example_func
#    filtered_func_data.ica: contains Melodic_IC, the 4D image with the IC's spatial maps               
#    example_func
#    mean_func
#    highres, highres head 

  
#------------------------------------------- Perform ICA to filtered_func_data ---------------------------------------#
#---------------------------------------------------------------------------------------------------------------------# 

# Create mel.ica directory, if there isn't one already 
if [[ ! -d mel.ica ]]; then mkdir mel.ica; fi; 
cp -t mel.ica example_func.nii.gz filtered_func_data.nii.gz mask.nii.gz mean_func.nii.gz 
#cp -t mel.ica example_func.nii.gz filtered_func_data_cut.nii.gz mask.nii.gz mean_func_cut.nii.gz 

# Perform ICA inside mel.ica directory
cd mel.ica 
#mv filtered_func_data_cut.nii.gz filtered_func_data.nii.gz
#mv mean_func_cut.nii.gz mean_func.nii.gz
melodic -i filtered_func_data --report 
cd ..

# Change name of files in directory mc to match fix input 
cd mc/ 
for file in epi*; do mv "$file" "${file/epi/prefiltered_func_data}"; done
cd ..
cp -r mc mel.ica 

# Copy registration files to the mel.ica directory 
mkdir mel.ica/reg
cp -t mel.ica/reg example_func.nii.gz highres.nii.gz highres_head.nii.gz
cp -t mel.ica/reg unwarp/example_func2highres.mat unwarp/example_func2highres.nii.gz 
cp -t mel.ica/reg unwarp/highres2example_func.mat 
  
