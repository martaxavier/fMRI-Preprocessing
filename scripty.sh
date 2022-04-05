#!/bin/bash



#--------------------------------------------- Declare analysis settings ---------------------------------------------# 
#---------------------------------------------------------------------------------------------------------------------# 

# Declare some initial parameters 
dataset=NODDI
pe_dir="y-"              # phase encoding direction 
task="task-rest"         # "task-rest" "task-calib"
run="run-1"              # "run-1" "run-2" "run-3"
mo_metric=dvars          # dvars refrms

path=/home/mxavier/eeg-fmri
cd $path


#--------------------------------------------------- Read dataset settings -------------------------------------------# 
#---------------------------------------------------------------------------------------------------------------------# 

if find ${path}tmp -mindepth 1 -maxdepth 1 | read; then rm ${path}tmp/*; fi
tmpdir=$path/tmp

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

  cd $path/$dataset/PREPROCESS/$i/$task/$run/$pedir_dir
  
  fslmaths $path/$dataset/DERIVATIVES/$i/bet_fast/${i}_T1_crop_restore_brain_pve_1.nii* -thr 1 GM_thr.nii.gz

# Copy functional data to current directory
  cp $path/$dataset/DATA/$i/func/$func_data_raw epi.nii.gz
  
  # Copy registration files
  cp $path/$dataset/DERIVATIVES/$i/reg/* unwarp
  
  # Remove first 5 volumes of data 
  if [[ $dataset == "NODDI" ]]
  then
    fslsplit epi
    rm vol0000.nii.gz vol0001.nii.gz vol0002.nii.gz vol0003.nii.gz vol0004.nii.gz
    fslmerge -t epi vol*
    rm vol*
  else   

  # Extract example volume from middle volume
  n_vols=$(fslval epi dim4) 
  mid_vol=$(echo $(( n_vols / 2 ))) 

  fslroi epi.nii.gz example_func $mid_vol 1 
  
   # Use MCFLIRT to estimate 6 realignment parameters (RP)
  # and correct distorted functional image for motion artefacts
  mcflirt -in epi -out epi_mcf -mats -plots -reffile example_func -rmsrel -rmsabs -spline_final
     
  # Mask 4D data with thresholded brain mask to obtain final skull-stripped time-series (epi_thresh)
  fslmaths epi_mcf -mas mask epi_thresh
  
  # Use the skull-stripped time-series as input to identify outliers 
  fsl_motion_outliers -i epi_thresh -o mo_confound_dvars.txt --dvars --nomoco -m mask
  fsl_motion_outliers -i epi_thresh -o mo_confound_refrms.txt --refrms --nomoco -m mask
  
  
done 