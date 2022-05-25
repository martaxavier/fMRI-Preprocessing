#!/bin/bash

#This script performs nuisance regression of the input functional data 
#
#------------------------------------- Build regressors (only once for each subject) ---------------------------------#
#---------------------------------------------------------------------------------------------------------------------# 

cd $path/$dataset/PREPROCESS/$task/$i/$run/$pedir_dir

# Build csf and wm masks only once for current subject  
if [[ ! -d masks ]]; then
  
  # Co-register CSF and WM masks into functional space
  flirt -in CSF_thr -ref example_func -applyxfm -init \
  unwarp/highres2example_func.mat -interp nearestneighbour -out EF_CSF_thr
  
  flirt -in WM_thr -ref example_func -applyxfm -init \
  unwarp/highres2example_func.mat -interp nearestneighbour -out EF_WM_thr
  
  flirt -in GM_thr -ref example_func -applyxfm -init \
  unwarp/highres2example_func.mat -interp nearestneighbour -out EF_GM_thr
  
  # Erode CSF and WM masks 
  fslmaths EF_CSF_thr -kernel gauss 1.8 -ero -bin EF_CSF_ero
  fslmaths EF_WM_thr -kernel gauss 2.2 -ero -bin EF_WM_ero
  fslmaths EF_GM_thr -kernel gauss 2.2 -ero -bin EF_GM_ero
  
  # Binarize the registered ventricle mask
  fslmaths EF_Ventricle -thr 0.9 -bin EF_Ventricle_bin 
  fslmaths EF_CSF_ero -mas EF_Ventricle_bin EF_CSF_Ventricle
  
  # Save all masks in directory masks
  mkdir masks; mv -f EF* Ventricle* CSF_thr* WM_thr* GM_thr* masks 
  
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
if [[ $flag_mo == 1 ]]; then 
  if [[ -f "mo_confound_${mo_metric}.txt" ]]; then
    cp "mo_confound_${mo_metric}.txt" regressor_mo.txt
  else
    echo "Warning: there are no motion outliers for subject $i"
  fi
fi


# Add motion realignment parameters regressors 
if [[ $flag_rp == 1 ]]; then

  if [[ $flag_hpf == 0 ]]; then 
  
   # Define input and output data files 
   data=prefiltered_func_data_mcf.txt
   data_out=prefiltered_func_data_mcf_tempfilt.txt
   if [[ -f $data_out ]]; then rm $data_out; fi
   
     # High-pass filter the 6 realignment parameters  
     . $path/perform_temporal_hpf_motionpars.sh 
   
     echo "Temporal high-pass of motion realignment parameters done for subject $i" 
 
     if [[ $flag_rp_exp == 1 ]]; then
     
       # Define input and output data files 
       data=$data_out
       data_out=prefiltered_func_data_mcf_exp_tempfilt.txt
       if [[ -f $data_out ]]; then rm $data_out; fi
       
       # Compute the time-series expansions of the realignment parameters 
       ${path}motionpars_expansions.sh $data $data_out
       mv prefiltered_func_data_mcf_exp_tempfilt.dat prefiltered_func_data_mcf_exp_tempfilt.txt
       
       echo "Time-series expansions of motion realignment parameters computed for subject $i"  
     
     fi  # flag_rp_exp == 1
   
  else # flag_hpf == 0
  
   data_out=prefiltered_func_data_mcf.txt
   if [[ -f $data_out ]]; then rm $data_out; fi
         
   if [[ $flag_rp_exp == 1 ]]; then
    
      # Define input and output data files 
      data=$data_out
      data_out=prefiltered_func_data_mcf_exp.txt
      if [[ -f $data_out ]]; then rm $data_out; fi
      
      # Compute the time-series expansions of the realignment parameters   
      ${path}motionpars_expansions.sh $data $data_out
      mv prefiltered_func_data_mcf_exp.dat prefiltered_func_data_mcf_exp.txt
      
      echo "Time-series expansions of motion realignment parameters computed for subject $i"    
    
   fi # flag_rp_exp == 1
  
  fi  # flag_hfp
  
cp $data_out regressor_rp  
fi #flag_rp

if [[ $flag_ic == 1 ]]; then

  # Copy melodic mix .txt file to current directory 
  cp mel.ica/filtered_func_data.ica/melodic_mix melodic_mix.txt
  
  # Read N-ICs from the file returned by FIX+manual classification 
  unset noise_ics; noise_ics=$(tail -1 "mel.ica/${fix_txt_out}" | head -1) 

  # Remove rectangular brackets from the string in the variable "noise_ics", 
  # turning into a comma separated list of numbers
  noise_ics="${noise_ics:1:-1}"
  noise_ics=($(echo ${noise_ics[@]} | tr "," " "))

  # Copy N-ICs columns of melodic mix to regressor_ic .txt file  
  for n in "${noise_ics[@]}"; do 
    awk -v n=$n '{print $n}' melodic_mix.txt > "reg_ic_$n".txt
  done 
  paste reg_ic* >> "regressor_ic.txt"
  rm reg_ic*
  
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