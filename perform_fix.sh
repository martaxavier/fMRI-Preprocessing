#!/bin/bash

# This script performs the first part of the pre-processing pipeline - independent component classification 
#
# Analysis inputs, specified in the begining of the script:
#   pe_dir: phase enconding direction
#   subj: subject id 
#   thr: threshold for fix noise/signal 
#
#
# Inputs in PREPROCESS/$subj/$pedir_dir/mel.ica directory:
#    mc directory
#    reg directory: example_func2highres, highres2example_func
#    filtered_func_data.ica: result of ica analysis
#    example_func
#    mean_func
#    highres, highres head 
# 
# Outputs in PREPROCESS/$subj/$pedir_dir/mel.ica directory:
#     fix: directory with results of fix analysis 
#     fix4me: text file with the classification of ics 


#-------------------------------------------- Perform FIX classification ---------------------------------------------# 
#---------------------------------------------------------------------------------------------------------------------# 

# Extract features
/usr/local/fix/fix -f mel.ica 

# Classify components 
/usr/local/fix/fix -c mel.ica /usr/local/fix/training_files/$fix_train_data $fix_thr

