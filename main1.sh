#!/bin/bash

# This script performs the first half of the pre-processing pipeline: minimal pre-processing and fix-ica
#
# The following scripts are called: 
#    preprocess: performs motion and field distortion correction, registration and high-pass filtering of the 4D data
#    perform_ica: performs ica on 4D functional data to obtain a set of spatially independent components and their time-courses 
#    perform_fix: performs fix classification of independent components obtained with perform_ica into noise or signal sources
#
# Analysis inputs, specified in the begining of the script:
#   TR: acquisition repetition time (seconds)
#   echo_spacing: effective echo spacing (seconds)
#   hp_freq: high-pass filter cutoff frequency (Hz)
#   pe_dir: phase enconding direction
#   subj_list: list of subjects to be analysed 
#   thr: threshold for fix noise/signal 
#
# Inputs in each DERIVATIVES/$subj/bet_fast directory:
#   $subj_MPRAGE: raw structural image 
#   $subj_MPRAGE: structural image, brain extracted, BET output 
#   $subj_MPRAGE_brain_pve0: CSF probabilistic mask, FAST output
#   $subj_MPRAGE_brain_pve1: WM probabilistic mask, FAST output
#
# Inputs in each DERIVATIVES/$subj/fmap_prepare directory:
#   $subj_fmap_mag: fieldmap magnitude image (one of the two: best looking one)
#   $subj_fmap_mag_brain: fieldmap magnitude image, brain extracted, BET output 
#   $subj_fmap_rads: fieldmap image, output of fsl_prepare_fieldmap
# 
# Inputs in each DATA/$subj/func directory:
#   $subj_epi: raw 4D functional data 
#
# Outputs in PREPROCESS/$subj/$pedir_dir directory:
#    unwarp: directory containing all transformations from EF_D space to EF_U space (vice-versa) and from struc to func space (vice-versa)
#    mc: directory containing the motion realignment parameters and the linear transformation (.cat) for motion artifact corrected 
#    mel.ica: directory containing 
#    example_func: middle volume of epi, in EF_U space 
#    example_func_distorted: middle volume of epi, in EF_D space 
#    filtered_func_data: 4D data, in EF_U space, corrected for motion artifacts, high-pass filtered 
#    mean_func: 3D image, temporal mean of filtered_func_data
#    mask: brain mask in EF_U space, output of BET (plus some processing operations)
#    highres: structural image, same as input 
#    highres_bet: structural image, brain extracted, same as input
#    mo_confound: text file for the confound model, output of motion_outliers 
#    CSF_thr: CSF mask, thresholded and binarized, in the highres space 
#    WM_thr: WM mask, thresholded and binarized, in the highres space 
#
# Outputs in PREPROCESS/$subj/$pedir_dir/mel.ica directory:
#    mc directory
#    reg directory: example_func2highres, highres2example_func
#    filtered_func_data.ica: contains Melodic_IC, the 4D image with the IC's spatial maps               
#    example_func
#    mean_func
#    highres, highres head 
#
# Outputs in PREPROCESS/$subj/$pedir_dir/mel.ica directory:
#     fix: directory with results of fix analysis 
#     fix4me: text file with the classification of ics 
# 
# Legend: 
#    FM: fieldmap space
#    EF: example_func space 
#    D: distorted 
#    U: undistorted 


#--------------------------------------------- Declare analysis settings ---------------------------------------------# 
#---------------------------------------------------------------------------------------------------------------------# 

# Declare some initial parameters 
pe_dir="y-"              # phase encoding direction 
task="task-rest"         # "task-rest" "task-calib"
run="run-3"              # "run-1" "run-2" "run-3"

path=/home/mxavier/eeg-fmri
cd $path


#--------------------------------------------------- Read dataset settings -------------------------------------------# 
#---------------------------------------------------------------------------------------------------------------------# 

# Create unique temporary directory 
tmpdir=$(mktemp -d) 

# Read dataset settings
. settings_dataset.sh
read TR < $tmpdir/TR.txt
read echo_spacing < $tmpdir/echo_spacing.txt
read hp_freq < $tmpdir/hp_freq.txt
read fwhm < $tmpdir/fwhm.txt
read fix_thr < $tmpdir/fix_thr.txt
read fix_train_data < $tmpdir/fix_train_data.txt
read fix_txt_out < $tmpdir/fix_txt_out.txt
read func_data_raw < $tmpdir/func_data_raw.txt
read subj_list < $tmpdir/subj_list.txt 


#--------------------------------------------------- Run preprocess --------------------------------------------------# 
#---------------------------------------------------------------------------------------------------------------------# 

if [[ $pe_dir == y- ]]; then pedir_dir="minusy"; else pedir_dir="plusy"; fi
    
# Iterate through subjects 
for i in "${subj_list[@]}"; do  

  if [[ ! -d $path/$dataset/PREPROCESS/$i/$task/$run/$pedir_dir ]]
    then 
      mkdir $path/$dataset/PREPROCESS/$i
      mkdir $path/$dataset/PREPROCESS/$i/$task 
      mkdir $path/$dataset/PREPROCESS/$i/$task/$run
      mkdir $path/$dataset/PREPROCESS/$i/$task/$run/$pedir_dir
  fi

  # Preprocess data 
  # Use dot calling syntax to save parent's environment 
  cd $path/$dataset/PREPROCESS/$i/$task/$run/$pedir_dir
  
  if [[ $dataset == "MIGN2TREAT" ]]
  then
    . $path/preprocess_mig.sh 
  else 
    . $path/preprocess.sh 
  fi 
  
  echo "Preprocessed data for $i"

done


#-------------------------------------------------- Run perform_ica --------------------------------------------------# 
#---------------------------------------------------------------------------------------------------------------------# 

# Iterate through subjects 
for i in "${subj_list[@]}"; do  

  # Change to subjects directory
  cd $path/$dataset/PREPROCESS/$i/$task/$run/$pedir_dir
  
  # Perform ICA to current data 
  . $path/perform_ica.sh 
  echo "Performed ICA for $i"

done


#-------------------------------------------------- Run perform_fix --------------------------------------------------# 
#---------------------------------------------------------------------------------------------------------------------# 

# Iterate through subjects 
for i in "${subj_list[@]}"; do  

  # Change to subjects directory
  cd $path/$dataset/PREPROCESS/$i/$task/$run/$pedir_dir
  
  # Perform FIX to current data 
  . $path/perform_fix.sh 
  echo "Performed FIX for $i"

done