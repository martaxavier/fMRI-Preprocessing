#!/bin/bash

# This script performs dual regression of group ICA results and 
# computes the dice coefficient between each subject's ICs and
# each of the standard RSNs
#
# The following scripts are called: 
#    settings_pipeline: assigns, for each pipeline, input functional data and output directory
#
# Analysis inputs, specified in the begining of the script:
#   pe_dir: phase enconding direction
#   subj_list: list of subjects to be analysed 
#   cleanup_list: cleanup pipeline list (from a predefined list)
#
# The cleanup pipelines suported in this version are the following: 
#    all: ica-fix + nuisance regression (WM, CSF, RP, MO)
#    all_gs: ica-fix + nuisance regression (WM, CSF, RP, MO, GS)
#    nuisance: nuisance regression (WM, CSF, RP, MO)
#    nuisance_gs: nuisance regression (WM, CSF, RP, MO, GS)
#    icafix: ica-fix 
#    icafix_physio: ica-fix + nuisance regression (WM, CSF)
#    icafix_motion: ica-fix + nuisance regression (MO, RP)
#    nocleanup: none 
#

path=/home/mxavier/eeg-fmri/
cd $path

#--------------------------------------------- Declare analysis settings ---------------------------------------------# 
#---------------------------------------------------------------------------------------------------------------------# 

# Declare analysis settings 
dataset=NODDI
pe_dir="y-"              # phase encoding direction 
task="task-rest"         # "task-rest" "task-calib"

# Run list
#run_list=("run-1" "run-2" "run-3") 
run_list=("run-1")

# Cleanup list: 
cleanup_list=("ica_mo_csf_wm_reg")

# Declare reference RSN template ("smith" - Smith, 2009; "yeo" - Yeo, 2011)  
rsn_template="smith"

if [[ $pe_dir == y- ]]; then pedir_dir="minusy"; else pedir_dir="plusy"; fi


#---------------------------------------- Read RSNs list from input .txt file ----------------------------------------# 
#---------------------------------------------------------------------------------------------------------------------# 

# Specify which .txt file containing the rsn names is going to be read 
if [ $rsn_template == "smith" ]; then

  input_list="list_smith_rsns.txt"
  ref_dir=STANDARD 
  ref=PNAS_Smith09_rsn10.nii.gz
  
elif [ $rsn_template == "yeo" ]; then

  input_list="list_yeo_rsns.txt"
  ref_dir=STANDARD
  ref=Yeo11_rsn7.nii.gz
  
fi


#--------------------------------------------------- Read dataset settings -------------------------------------------# 
#---------------------------------------------------------------------------------------------------------------------# 

if find ${path}tmp -mindepth 1 -maxdepth 1 | read; then rm ${path}tmp/*; fi
tmpdir=$path/tmp

# Read dataset settings
. settings_dataset.sh
read subj_list < $tmpdir/subj_list.txt 


#------------------------------------------------- Assign RSN list  --------------------------------------------------# 
#---------------------------------------------------------------------------------------------------------------------# 

# List of RSNs 
rsn_num=`fslval "${ref_dir}/${ref}" dim4` 
rsn_num=$(echo "$rsn_num - 1"| bc -l)
declare -a rsn_list=()
c=0
  
while [ $c -le 9 ]; do
  rsn_list=( "${rsn_list[@]}" "000${c}" ) 
  c=$(echo "$c + 1" | bc -l)
done
      
while [ $c -le $rsn_num ]; do
  rsn_list=( "${rsn_list[@]}" "00${c}" ) 
  c=$(echo "$c + 1" | bc -l)
done 


#------------------------------------------- Go through cleanup pipelines  -------------------------------------------# 
#---------------------------------------------------------------------------------------------------------------------# 

# Iterate through cleanup pipelines 
for cleanup in "${cleanup_list[@]}"; do  

  cd $path 
  
  # Assign flags and inputs for pipeline
  . settings_pipeline.sh
  
  # Read variables created in child process, in temporary directory
  read func_data < $tmpdir/func_data_final.txt
  read gica_dir < $tmpdir/gica_dir.txt;
  
  #---------------------------------------------- Run dual regression ------------------------------------------------# 
  #-------------------------------------------------------------------------------------------------------------------#  
  
  cd $dataset/PREPROCESS 
  
  # Perform dual regression, turn on variance normalisation of the timecourses used as stage-2 regressors 
  dual_regression groupICA/$gica_dir/$rsn_template/melodic_IC 1 -1 0 groupICA.dr `cat inputlist_4groupICA.txt`
  
  echo "Performed dual regression"

  #------------------------------------------- Obtain dice coefficient for -------------------------------------------# 
  #------------------------------------------------ each subject ICs -------------------------------------------------# 
  
  s=0
  
  # Split binarized reference images into separate images 
  fslsplit $path/$ref_dir/$ref groupICA.stats/STD
  
  for run in "${run_list[@]}"; do 
  
    for i in "${subj_list[@]}"; do 
    
      if [[ $run == "run-2" ]] && [[ $i == "sub-02" ]]; then continue; fi
      if [[ $run == "run-3" ]] && [[ $i == "sub-03" ]]; then continue; fi
      if [[ $run == "run-3" ]] && [[ $i == "sub-28" ]]; then continue; fi    
    
      if [ $s -le 9 ]; then
        sub_num="0$s"
      else
        sub_num=$s
      fi
    
      # Binarize subject IC image, thresholding at Z=3
      fslmaths "groupICA.dr/dr_stage2_subject000${sub_num}_Z" -thr 3 -bin "groupICA.stats/$i"
      
      # Split binarized subject IC maps into separate images
      fslsplit "groupICA.stats/$i" groupICA.stats/subj
      
      cd groupICA.stats
      
      # Assign IC list for current patient
      ic_num=`fslval "$i" dim4` 
      ic_num=$(echo "$ic_num -1"| bc -l)
      unset ic_list
      declare -a ic_list=()
      
      c=0
    
      while [ $c -le 9 ] && [ $c -le $ic_num ]; do
        ic_list=( "${ic_list[@]}" "000${c}" ) 
        c=$(echo "$c + 1" | bc -l)
      done
    
      while [ $c -le 99 ] && [ $c -le $ic_num ]; do
        ic_list=( "${ic_list[@]}" "00${c}" ) 
        c=$(echo "$c + 1" | bc -l)
      done
         
      while [ $c -le $ic_num ]; do
        ic_list=( "${ic_list[@]}" "0${c}" ) 
        c=$(echo "$c + 1" | bc -l)
      done
      
      # Iterate through subject's ICs 
      for k in "${ic_list[@]}"; do 
      
        # Iterate through RSNs 
        for j in "${rsn_list[@]}"; do 
      
          # Create an image of the intersection between the two volumes
          fslmaths "STD${j}" -mul "subj${k}" STD_subj
          
          # Compute the number of nonzero voxels in each of the volumes  
          STD_vox=`fslstats "STD${j}" -V`; STD_vox=`awk '{ print $1}' <<< "$STD_vox"`
          subj_vox=`fslstats "subj${k}" -V`; subj_vox=`awk '{ print $1}' <<< "$subj_vox"`
          STD_subj_vox=`fslstats "STD_subj" -V`; STD_subj_vox=`awk '{ print $1}' <<< "$STD_subj_vox"`
          
          # Compute the dice coefficient (only 4 decimal digits) between the two volumes 
          dice=$(echo "scale=4; 2 * $STD_subj_vox / ($STD_vox + $subj_vox)"| bc -l)
          
          # Input the dice coefficient into the .txt file 
          # It will add this dice coef to the next line of the file
          echo $dice >> "dice_${i}_ic${k}.txt"
          
          # Remove the intersection volume 
          rm STD_subj*
          
        done #rsns
    
      done #ics
           
      # Append subject's IC file to main file (at the end)
      paste dice* | column -s $'\t' -t >> "${i}_dice.txt"
      
      # Save file in subjects PREPROCESS directory 
      if [[ ! -d $path/$dataset/PREPROCESS/$i/$task/$run/$pedir_dir/$gica_dir ]]; then mkdir $path/$dataset/PREPROCESS/$i/$task/$run/$pedir_dir/$gica_dir; fi;
      if [[ ! -d $path/$dataset/PREPROCESS/$i/$task/$run/$pedir_dir/$gica_dir/$rsn_template ]]; then mkdir $path/$dataset/PREPROCESS/$i/$task/$run/$pedir_dir/$gica_dir/$rsn_template; fi;
      cp "${i}_dice.txt" $path/$dataset/PREPROCESS/$i/$task/$run/$pedir_dir/$gica_dir/$rsn_template
        
      echo "Computed dice coefficients for subject $i" 
      
      # Remove files of current subject 
      imrm sub*
      rm dice*
      
      # Update subject number 
      s=$(echo "$s + 1" | bc -l) 
      
      cd ..
    
    done # subjs
    
  done # runs 
  
  # Move all dual regression files to current analysis directory 
  if [[ ! -d groupICA.dr/$gica_dir ]]; then mkdir groupICA.dr/$gica_dir; fi;
  if [[ ! -d groupICA.dr/$gica_dir/$rsn_template ]]; then mkdir groupICA.dr/$gica_dir/$rsn_template; fi;
  mv -f groupICA.dr/mas* groupICA.dr/dr* groupICA.dr/script* groupICA.dr/$gica_dir/$rsn_template
    
  cd groupICA.stats; rm STD00*
  
  # Move all files to analysis directory 
  mv sub* $gica_dir/$rsn_template
  
done # cleanup