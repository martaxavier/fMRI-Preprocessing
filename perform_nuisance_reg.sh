#!/bin/bash

#This script performs nuisance regression of the input functional data 
#
#------------------------------------- Build regressors (only once for each subject) ---------------------------------#
#---------------------------------------------------------------------------------------------------------------------# 

cd $path/$dataset/PREPROCESS/$i/$task/$run/$pedir_dir

# Build csf and wm masks only once for current subject  
if [[ ! -d masks ]]; then
  
  # Co-register CSF and WM masks into functional space
  flirt -in CSF_thr -ref example_func -applyxfm -init \
  unwarp/highres2example_func.mat -interp nearestneighbour -out EF_CSF_thr
  
  flirt -in WM_thr -ref example_func -applyxfm -init \
  unwarp/highres2example_func.mat -interp nearestneighbour -out EF_WM_thr
  
  # Erode CSF and WM masks 
  fslmaths EF_CSF_thr -kernel gauss 1.8 -ero -bin EF_CSF_ero
  fslmaths EF_WM_thr -kernel gauss 2.2 -ero -bin EF_WM_ero
  
  # Binarize the registered ventricle mask
  fslmaths EF_Ventricle -thr 0.9 -bin EF_Ventricle_bin 
  fslmaths EF_CSF_ero -mas EF_Ventricle_bin EF_CSF_Ventricle
  
  # Save all masks in directory masks
  mkdir masks; mv -f EF* Ventricle* CSF_thr* WM_thr* masks 
  
fi
 
 # Compute nuisance signals of GS, CSF and WM signals 
 fslmeants -i $func_data_in -o GS.txt -m mask 
 fslmeants -i $func_data_in -m masks/EF_CSF_Ventricle -o CSF.txt
 fslmeants -i $func_data_in -m masks/EF_WM_ero -o WM.txt


#--------------------------------------- Confound modeling of input functional data ----------------------------------#
#---------------------------------------------------------------------------------------------------------------------# 


# Concatenate nuisance signals to build confound model  
if [[ $flag_csf == 1 ]]; then cp CSF.txt regressor_csf.txt; fi
if [[ $flag_wm == 1 ]]; then cp WM.txt regressor_wm.txt; fi
if [[ $flag_gs == 1 ]]; then cp GS.txt regressor_gs.txt; fi
if [[ $flag_mo == 1 ]]; then cp mo_confound.txt regressor_mo.txt; fi


if [[ $flag_rp == 1 ]]; then

  if [[ $flag_icafix == 1 ]]; then 
  
    cp prefiltered_func_data_mcf_tempfilt.txt regressor_rp.txt; 
   
  else
  
   cp prefiltered_func_data_mcf.txt regressor_rp.txt;   
  
  fi
  
fi
  
# Remove previous confound_design (if existent) and write new one 
if [[ -f confound_design.txt ]]; then rm confound_design.txt; fi
paste regressor* | column -s $'\t' -t >> confound_design.txt; rm regressor*

# Extract temporal mean before performing nuisance regression 
fslmaths $func_data_in -Tmean mean_func 

# Perform confound regression to clean residual structured noise 
# Turn on normalisation of both data and design columns to std=1, and demean both data and design columns (or not?)
fsl_glm --in=$func_data_in --design=confound_design.txt --out_res=$func_data_out
fslmaths $func_data_out -add mean_func $func_data_out