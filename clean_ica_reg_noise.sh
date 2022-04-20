#!/bin/bash

# This script performs nonaggressive regression of noise ICs (N-ICs) and nuisance regressors, in a single step
# Nuisance regressors can be: realigment parameters (RP), motion outliers (MO), CSF avg. signal (CSF), WM avg. signal (WM), global signal (GS) 
#
#------------------------------------------- Build CSF, WM and GS regressors -----------------------------------------#
#---------------------------------------------------------------------------------------------------------------------# 

cd $path/$dataset/PREPROCESS/$task/$i/$run/$pedir_dir

# Build csf and wm masks if they don't already exist for the current subject 
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
 fslmeants -i $func_data_in -o GS_before_ica_cleanup.txt -m mask 
 fslmeants -i $func_data_in -m masks/EF_CSF_Ventricle -o CSF_before_ica_cleanup.txt
 fslmeants -i $func_data_in -m masks/EF_WM_ero -o WM_before_ica_cleanup.txt
 
 
#--------------------------------------- Confound modeling of input functional data ----------------------------------#
#---------------------------------------------------------------------------------------------------------------------# 

# Concatenate nuisance signals to build confound model  
declare -a reg_out=()
r=0

# Add CSF average signal regressor 
if [[ $flag_csf == 1 ]]; then 
  cp CSF_before_ica_cleanup.txt regressor_csf.txt
  r=$(echo "$r + 1" | bc -l)
  reg_out=( "${reg_out[@]}" "$r" )
fi

# Add white matter average signal regressor 
if [[ $flag_wm == 1 ]]; then 
  cp WM_before_ica_cleanup.txt regressor_wm.txt
  r=$(echo "$r + 1" | bc -l)  
  reg_out=( "${reg_out[@]}" "$r" )
fi

# Add global signal regressor 
if [[ $flag_gs == 1 ]]; then 
  cp GS_before_ica_cleanup.txt regressor_gs.txt
  r=$(echo "$r + 1" | bc -l)    
  reg_out=( "${reg_out[@]}" "$r" )
fi

# Add motion outliers regressors 
if [[ $flag_mo == 1 ]]; then 

  # Only if outlier file was created - if not, there are no outliers 
  if [[ -f "mo_confound_${mo_metric}.txt" ]]; then

    cp "mo_confound_${mo_metric}.txt" regressor_mo.txt
    n_cols=$(awk '{print NF}' "mo_confound_${mo_metric}.txt" | sort -nu | head -n 1)
    
    rend=$(echo "$r + $n_cols" | bc -l)
    while [ $r -le $rend ]; do
      r=$(echo "$r + 1" | bc -l)
      reg_out=( "${reg_out[@]}" "$r" )
    done
    r=$rend
  
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
  
  cp $data_out regressor_rp.txt
  
  if [[ $flag_rp_exp == 1 ]]; then
  
    rend=$(echo "$r + 24" | bc -l)
    r=$(echo "$r + 1" | bc -l)
    while [ $r -le $rend ]; do
      reg_out=( "${reg_out[@]}" "$r" )
      r=$(echo "$r + 1" | bc -l)
    done
  
  else 
  
    rend=$(echo "$r + 6" | bc -l)
    r=$(echo "$r + 1" | bc -l)
    while [ $r -le $rend ]; do
      reg_out=( "${reg_out[@]}" "$r" )
      r=$(echo "$r + 1" | bc -l)
    done
  
  fi
  
  r=$rend
  
fi #flag_rp

# Turn reg_out into a comma separated list 
reg_out=($(echo ${reg_out[@]} | tr " " ","))

# Remove previous confound_design (if existent) and write new one 
if [[ -f confound_design.txt ]]; then rm confound_design.txt; fi
paste regressor* | column -s $'\t' -t >> confound_design.txt; rm regressor*

# Read N-ICs from the file returned by FIX+manual classification 
unset noise_ics
noise_ics=$(tail -1 "mel.ica/${fix_txt_out}" | head -1) 

# Remove rectangular brackets from the string in the variable "noise_ics", 
# turning into a comma separated list of numbers
noise_ics="${noise_ics:1:-1}"
noise_ics=($(echo ${noise_ics[@]} | tr "," " "))

c=0
for n in "${noise_ics[@]}"; do 
  nnew=$(echo "$n + $r" | bc -l);
  noise_ics[$c]=$nnew
  c=$(echo "$c + 1" | bc -l); 
done

noise_ics=($(echo ${noise_ics[@]} | tr " " ","))

if [ "$noise_ics" == "" ]; then
  
  echo "Warning: there are no noise ICs in ${fix_txt_out} for subject $i"
  
  # Perform nonaggressive regression of IC-N and nuisance regressors 
  fsl_regfilt -i $func_data_in -o $func_data_out -d confound_design.txt -f "$reg_out" 
  
else

  reg_out=( "${reg_out[@]}" "," ) 
  reg_out=( "${reg_out[@]}" "$noise_ics" ) 
    
  # Add confound_design to the melodic_mix
  if [[ -f confound_design_melodic_mix.txt ]]; then rm confound_design_melodic_mix.txt; fi
  paste confound_design.txt mel.ica/filtered_func_data.ica/melodic_mix | column -s $'\t' -t >> confound_design_melodic_mix.txt;
  
  # Perform nonaggressive regression of IC-N and nuisance regressors 
  fsl_regfilt -i $func_data_in -o $func_data_out -d confound_design_melodic_mix.txt -f "$reg_out" 

fi

