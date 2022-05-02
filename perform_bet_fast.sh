#!/bin/bash

path=/home/mxavier
cd $path

dataset=PARIS


#--------------------------------------------------- Read dataset settings -------------------------------------------# 
#---------------------------------------------------------------------------------------------------------------------# 

# Create unique temporary directory 
tmpdir=$(mktemp -d) 

# Read dataset settings
. settings_dataset.sh
read subj_list < $tmpdir/subj_list.txt 
read anat_data_raw < $tmpdir/anat_data_raw.txt 


# Iterate through subjects 
for i in "${subj_list[@]}"; do  
  
  if [[ $dataset == "PARIS" ]]; then
    anat_data_raw_sub=${i}_${anat_data_raw}
  elif [[ $dataset == "NODDI" ]]; then
    anat_data_raw_sub=${i}_${anat_data_raw}
  fi

  cd PARIS/DATA/$i/anat
  
  # Reorient to standard orientation 
  fslreorient2std $anat_data_raw_sub ${i}_T1_reori
  
  # Crop to remove head and lower neck 
  # This helps ANTS automatic brain extraction 
  robustfov -i ${i}_T1_reori -r ${i}_T1_crop
  
  # Correct for bias field 
  fast -B --nopve ${i}_T1_crop
  
  # Registration to standard space. This step helps to initialise fast segmentation usng tissue priors 
  fslmaths /usr/local/fsl/data/standard/MNI152_T1_2mm_brain standard
  fslmaths /usr/local/fsl/data/standard/MNI152_T1_2mm standard_head 
  fslmaths /usr/local/fsl/data/standard/MNI152_T1_2mm_brain_mask_dil standard_mask
    
  # Create linear and non-linear warp transformations from structural to standard space 
  # First perform a linear registration  
  flirt -in ${i}_T1_crop_restore -ref standard_head -omat highres2standard_aff.mat -cost corratio -dof 12 -interp trilinear
    
  # Use the linear transformation to initialize the non-linear registration 
  fnirt --iout=highres2standard_head --in=${i}_T1_crop_restore --aff=highres2standard_aff.mat --cout=highres2standard_coef \
  --iout=highres2standard --jout=highres2highres_jac --config=T1_2_MNI152_2mm --ref=standard_head \
  --refmask=standard_mask --warpres=10,10,10    
  
  # Obtain transformation from standard to structural space 
  convert_xfm -inverse -omat standard2highres_aff.mat highres2standard_aff.mat
  invwarp --ref=${i}_T1_crop_restore --warp=highres2standard_coef --out=standard2highres_coef  
  
  # Perform brain extraction 
  bet2 ${i}_T1_crop_restore ${i}_T1_crop_restore_brain -m 
  
  # Perform tissue segmentation 
  fast -N -s -a standard2highres_aff.mat ${i}_T1_crop_restore_brain
  rm standard.nii.gz standard_head.nii.gz standard_mask.nii.gz
  cd ../../..
  
  # Organize outputs in the DERIVATIVES directory 
  if [[ ! -d DERIVATIVES/$i ]]; then mkdir DERIVATIVES/$i; fi  
  if [[ ! -d DERIVATIVES/$i/bet_fast ]]; then mkdir DERIVATIVES/$i/bet_fast; fi
  if [[ ! -d DERIVATIVES/$i/reg ]]; then mkdir DERIVATIVES/$i/reg; fi
  
  rm DERIVATIVES/$i/bet_fast/* 
  mv DATA/$i/anat/${i}_T1_crop* "DERIVATIVES"/$i/bet_fast/
  mv DATA/$i/anat/${i}_T1_reori* "DERIVATIVES"/$i/bet_fast/
  
  mv DATA/$i/anat/highres2* DERIVATIVES/$i/reg
  mv DATA/$i/anat/standard2* DERIVATIVES/$i/reg
  
done