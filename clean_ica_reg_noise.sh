#!/bin/bash

# This script performs nonaggressive regression of noise ICs (N-ICs) and nuisance regressors, in a single step
# Nuisance regressors can be: realigment parameters (RP), motion outliers (MO), CSF avg. signal (CSF), WM avg. signal (WM), global signal (GS) 
#
#------------------------------------------- Build CSF, WM and GS regressors -----------------------------------------#
#---------------------------------------------------------------------------------------------------------------------# 

cd $path/$dataset/PREPROCESS/$i/$task/$run/$pedir_dir

# Build csf and wm masks if they don't already exist for the current subject 
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
 fslmeants -i $func_data_in -o GS_before_ica_cleanup.txt -m mask 
 fslmeants -i $func_data_in -m masks/EF_CSF_Ventricle -o CSF_before_ica_cleanup.txt
 fslmeants -i $func_data_in -m masks/EF_WM_ero -o WM_before_ica_cleanup.txt
 
 
#--------------------------------------- Confound modeling of input functional data ----------------------------------#
#---------------------------------------------------------------------------------------------------------------------# 

# Concatenate nuisance signals to build confound model  
if [[ $flag_csf == 1 ]]; then cp CSF_before_ica_cleanup.txt regressor_csf.txt; fi
if [[ $flag_wm == 1 ]]; then cp WM_before_ica_cleanup.txt regressor_wm.txt; fi
if [[ $flag_gs == 1 ]]; then cp GS_before_ica_cleanup.txt regressor_gs.txt; fi
if [[ $flag_mo == 1 ]]; then cp mo_confound.txt regressor_mo.txt; fi

if [[ $flag_rp == 1 ]]; then

  if [[ $flag_hpf == 0 ]]; then 
  
    # Define input and output data files 
    data=prefiltered_func_data_mcf.txt
    data_out=prefiltered_func_data_mcf_tempfilt.txt
    if [[ -f $data_out ]]; then rm $data_out; fi
    
    # High-pass filter the 6 realignment parameters  
    . $path/perform_temporal_hpf_motionpars.sh 

    if [[ $flag_rp_exp == 1 ]]; then
    
      # Define input and output data files 
      data=$data_out
      data_out=prefiltered_func_data_mcf_exp_tempfilt.txt
      if [[ -f $data_out ]]; then rm $data_out; fi
      
      # Compute the time-series expansions of the realignment parameters 
      . $path/motionpars_expansions.sh     
    
    fi  
   
  else # flag_hpf == 1
  
   data_out=prefiltered_func_data_mcf.txt
   if [[ -f $data_out ]]; then rm $data_out; fi
         
   if [[ $flag_rp_exp == 1 ]]; then
    
      # Define input and output data files 
      data=$data_out
      data_out=prefiltered_func_data_mcf_exp.txt
      if [[ -f $data_out ]]; then rm $data_out; fi
      
      # Compute the time-series expansions of the realignment parameters 
      . $path/motionpars_expansions.sh     
    
    fi 
  
  fi 
  
  cp $data_out regressor_rp.txt
  
fi

# Remove previous confound_design (if existent) and write new one 
if [[ -f confound_design.txt ]]; then rm confound_design.txt; fi
paste regressor* | column -s $'\t' -t >> confound_design.txt; rm regressor*

# Add confound_design to the melodic_mix
if [[ -f melodic_mix_confound_design.txt ]]; then rm melodic_mix_confound_design.txt; fi
paste mel.ica/filtered_func_data.ica/melodic_mix confound_design.txt | column -s $'\t' -t >> melodic_mix_confound_design.txt;

# Read N-ICs from the file returned by FIX+manual classification 
noise_ics=$(tail -1 mel.ica/fix4melview_Standard_thr20.txt | head -1) 

# Remove rectangular brackets from the string in the variable "noise_ics", 
# turning into a comma separated list of numbers
noise_ics="${noise_ics:1:-1}"

# Perform nonaggressive regression of IC-N and nuisance regressors 
fsl_regfilt -i $func_data_in -o $func_data_out -d melodic_mix_confound_design.txt -f "$noise_ics"

 
