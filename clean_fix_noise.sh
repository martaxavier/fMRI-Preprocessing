#!/bin/bash

#This script removes time-series of noise components from the functional data
#
#
# Apply cleanup, using artefacts listed in the .txt file 
/usr/local/fix/fix -a mel.ica/$fix_training_dataset

# Copy fix output filtered_func_data_clean to the main directory 
cp mel.ica/filtered_func_data_clean.nii.gz . 