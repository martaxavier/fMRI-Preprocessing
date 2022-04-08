#!/bin/bash



#--------------------------------------------- Declare analysis settings ---------------------------------------------# 
#---------------------------------------------------------------------------------------------------------------------# 

# Declare some initial parameters 
dataset=PARIS
pe_dir="y-"              # phase encoding direction 
task="task-rest"         # "task-rest" "task-calib"
run="run-1"              # "run-1" "run-2" "run-3"

path=/home/mxavier/eeg-fmri/
cd $path


#--------------------------------------------------- Read dataset settings -------------------------------------------# 
#---------------------------------------------------------------------------------------------------------------------# 

if find ${path}tmp -mindepth 1 -maxdepth 1 | read; then rm ${path}tmp/*; fi
tmpdir=${path}tmp

# Read dataset settings
. settings_dataset.sh
#read TR < $tmpdir/TR.txt
#read echo_spacing < $tmpdir/echo_spacing.txt
#read hp_freq < $tmpdir/hp_freq.txt
#read fwhm < $tmpdir/fwhm.txt
#read fix_thr < $tmpdir/fix_thr.txt
#read fix_train_data < $tmpdir/fix_train_data.txt
#read fix_txt_out < $tmpdir/fix_txt_out.txt
#read func_data_raw < $tmpdir/func_data_raw.txt
read subj_list < $tmpdir/subj_list.txt 


#--------------------------------------------------- Run preprocess --------------------------------------------------# 
#---------------------------------------------------------------------------------------------------------------------# 

if [[ $pe_dir == y- ]]; then pedir_dir="minusy"; else pedir_dir="plusy"; fi
    
# Iterate through subjects 
for i in "${subj_list[@]}"; do  
  
#  func_data_raw_sub=${i}_${func_data_raw}
  
  cd $path/$dataset/PREPROCESS/$i/$task/$run/$pedir_dir
  fslmaths $path/$dataset/DERIVATIVES/$i/bet_fast/${i}_T1_crop_restore_brain_pve_1.nii* -thr 1 masks/GM_thr.nii.gz
  flirt -in masks/GM_thr -ref example_func -applyxfm -init unwarp/highres2example_func.mat -interp nearestneighbour -out masks/EF_GM_thr
  fslmaths masks/EF_GM_thr -kernel gauss 2.2 -ero -bin masks/EF_GM_ero
  
#  fslmaths $path/$dataset/DERIVATIVES/$i/bet_fast/${i}_T1_crop_restore_brain_pve_1.nii* -thr 1 GM_thr.nii.gz

  # Copy functional data to current directory
#  cp $path/$dataset/DATA/$i/func/$func_data_raw_sub epi.nii.gz

  # Remove first 5 volumes of data 
#  if [[ $dataset == "NODDI" ]]
#  then
#    fslsplit epi
#    rm vol0000.nii.gz vol0001.nii.gz vol0002.nii.gz vol0003.nii.gz vol0004.nii.gz
#    fslmerge -t epi vol*
#    rm vol*
#  fi   

  # Extract example volume from middle volume
#  n_vols=$(fslval epi dim4) 
#  mid_vol=$(echo $(( n_vols / 2 ))) 

#  fslroi epi.nii.gz example_func $mid_vol 1 
  
  # Use MCFLIRT to estimate 6 realignment parameters (RP)
  # and correct distorted functional image for motion artefacts
#  mcflirt -in epi -out epi_mcf -mats -plots -reffile example_func -rmsrel -rmsabs -spline_final
  
#  mv -f epi_mcf.mat* epi_mcf.par epi_mcf_abs.rms epi_mcf_abs_mean.rms epi_mcf_rel.rms epi_mcf_rel_mean.rms mc; cd mc
#  rm -rf epi*; cd ..
     
  # Mask 4D data with thresholded brain mask to obtain final skull-stripped time-series (epi_thresh)
#  fslmaths epi_mcf -mas mask epi_thresh
  
#  rm mo* 
  
  # Use the skull-stripped time-series as input to identify outliers 
#  fsl_motion_outliers -i epi_thresh -o mo_confound_dvars.txt --dvars --nomoco -m mask -s mc/dvars.txt -p mc/dvars 
#  fsl_motion_outliers -i epi_thresh -o mo_confound_refrms.txt --refrms --nomoco -m mask -s mc/refrms.txt -p mc/refrms
#  fsl_motion_outliers -i epi_thresh -o mo_confound_fd.txt --fd -m mask -s mc/fd.txt -p mc/fd 
  
#  mv epi* mc/
  
  echo "done for $i"
  
done 