#!/bin/bash

# This script performs group ICA and computes the dice coefficient between 
# each of the resulting group ICs and each of the standard RSNs
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


path=/home/mxavier/eeg-fmri/
cd $path

#--------------------------------------------- Declare analysis settings ---------------------------------------------# 
#---------------------------------------------------------------------------------------------------------------------# 

# Declare analysis settings 
dataset=PARIS
pe_dir="y-"              # phase encoding direction 
task="task-rest"         # "task-rest" "task-calib"
flag_std_reg=0

# Run list
#run_list=("run-1")
run_list=("run-1" "run-2" "run-3")

# Cleanup list: 
cleanup_list=("ica_mo_reg" "ica_mo_csf_reg" "ica_mo_csf_wm_reg")
#cleanup_list=("ica_mo_csf_wm_reg")

# Declare reference RSN template ("smith" - Smith, 2009; "yeo" - Yeo, 2011)  
rsn_template="smith"

if [[ $pe_dir == y- ]]; then pedir_dir="minusy"; else pedir_dir="plusy"; fi


#---------------------------------------- Read RSNs list from input .txt file ----------------------------------------# 
#---------------------------------------------------------------------------------------------------------------------# 

# Specify which .txt file containing the rsn names is going to be read 
if [ $rsn_template == "smith" ]; then

  input_list="list_smith_rsns.txt"
  ref_dir=STANDARD 
  ref=PNAS_Smith09_rsn10_bin.nii.gz
  
elif [ $rsn_template == "yeo" ]; then

  input_list="list_yeo_rsns.txt"
  ref_dir=STANDARD
  ref=Yeo11_rsn7.nii.gz
  
fi


#--------------------------------------------------- Read dataset settings -------------------------------------------# 
#---------------------------------------------------------------------------------------------------------------------# 

# Create unique temporary directory 
if find ${path}tmp -mindepth 1 -maxdepth 1 | read; then rm ${path}tmp/*; fi
tmpdir=$path/tmp

# Read dataset settings
. settings_dataset.sh
read subj_list < $tmpdir/subj_list.txt 
read TR < $tmpdir/TR.txt


# Create output directories 
if [[ ! -d $dataset/PREPROCESS/$task/groupICA ]]; then mkdir $dataset/PREPROCESS/$task/groupICA; fi;
if [[ ! -d $dataset/PREPROCESS/$task/groupICA.stats ]]; then mkdir $dataset/PREPROCESS/$task/groupICA.stats; fi;


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


  #---------------------------- Register the cleaned data of each subject to standard space --------------------------# 
  #-------------------------------------------------------------------------------------------------------------------# 
  
  # Perform registration to std space 
  if [[ $flag_std_reg == 1 ]]; then
  
     for run in "${run_list[@]}"; do 
     
       for i in "${subj_list[@]}"; do 
       
         if [[ $run == "run-2" ]] && [[ $i == "sub-02" ]]; then continue; fi
         if [[ $run == "run-3" ]] && [[ $i == "sub-03" ]]; then continue; fi
         if [[ $run == "run-3" ]] && [[ $i == "sub-28" ]]; then continue; fi
       
         # Go to current subject directory
         cd "$path/$dataset/PREPROCESS/$task/$i/$run/$pedir_dir"
         
         # Apply warp to obtain filtered_func_data_preprocessed in standard space 
         applywarp --in=$func_data --ref=/usr/local/fsl/data/standard/MNI152_T1_2mm_brain \
         --out="${func_data}2standard" --warp=unwarp/example_func2standard_coef.nii.gz \
         
         echo "Performed registration to MNI for subject $i, run $run" 
         
       done
       
     done

  fi
  
  
  #------------------------- Run group ICA using MELODIC multi-session temporal concatenation ------------------------# 
  #-------------------------------------------------------------------------------------------------------------------# 
  
  cd $path/$dataset/PREPROCESS/$task
  
  # Write input list for melodic ica 
  rm inputlist_4groupICA.txt
  
  for run in "${run_list[@]}"; do 
  
    for i in "${subj_list[@]}"; do 
    
      if [[ $run == "run-2" ]] && [[ $i == "sub-02" ]]; then continue; fi   
      if [[ $run == "run-3" ]] && [[ $i == "sub-03" ]]; then continue; fi
      if [[ $run == "run-3" ]] && [[ $i == "sub-28" ]]; then continue; fi
         
      echo $path/$dataset/PREPROCESS/$task/$i/$run/$pedir_dir/${func_data}2standard >> inputlist_4groupICA.txt
      
    done
  
  done
  
  # Run melodic, turn off all preprocessing, giving input .txt with path to registered functional data
  melodic -i "inputlist_4groupICA.txt" -o groupICA --tr=$TR --nobet -a concat -m /usr/local/fsl/data/standard/MNI152_T1_2mm_brain_mask.nii.gz --report --Oall -d 30
  
  echo "Performed group ICA"
 
  #--------------------------------------------- Obtain dice coefficient   -------------------------------------------# 
  #------------------------------------------------- for the group ICs -----------------------------------------------# 
  
  # Split binarized reference images into separate images 
  fslsplit $path/$ref_dir/$ref groupICA.stats/STD
  
  # Binarize IC image, thresholding at Z=3
  fslmaths groupICA/melodic_IC -thr 3 -bin groupICA.stats/IC
    
  cd groupICA.stats
    
  # Split binarized IC images into separate images
  fslsplit IC IC
  
  # Assign IC list
  ic_num=`fslval IC dim4` 
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
      fslmaths "STD${j}" -mul "IC${k}" STD_IC
      
      # Compute the number of nonzero voxels in each of the volumes  
      STD_vox=`fslstats "STD${j}" -V`; STD_vox=`awk '{ print $1}' <<< "$STD_vox"`
      IC_vox=`fslstats "IC${k}" -V`; IC_vox=`awk '{ print $1}' <<< "$IC_vox"`
      STD_IC_vox=`fslstats "STD_IC" -V`; STD_IC_vox=`awk '{ print $1}' <<< "$STD_IC_vox"`
      
      # Compute the dice coefficient (only 4 decimal digits) between the two volumes 
      dice=$(echo "scale=4; 2 * $STD_IC_vox / ($STD_vox + $IC_vox)"| bc -l)
      
      # Input the dice coefficient into the .txt file 
      # It will add this dice coef to the next line of the file
      echo $dice >> "dice_ic${k}.txt"
      
      # Remove the intersection volume 
      rm STD_IC*                         
   
    done # RSNs
   
  done # ICs
  
  # Append IC file to main file (at the end)
  paste dice* | column -s $'\t' -t >> "group_dice.txt"
    
  echo "Computed group dice coefficients" 
  
  # Remove files of current subject 
  imrm IC*
  rm dice*
  rm STD*
  
  # Move final file to analysis directory 
  if [[ ! -d $gica_dir ]]; then mkdir $gica_dir; fi;
  if [[ ! -d "$gica_dir/$rsn_template" ]]; then mkdir "$gica_dir/$rsn_template"; fi;
  mv group* "$gica_dir/$rsn_template"  
  
  cd ..  
  
  if [[ ! -d groupICA/$gica_dir ]]; then mkdir groupICA/$gica_dir; fi;
  if [[ ! -d "groupICA/$gica_dir/$rsn_template" ]]; then mkdir "groupICA/$gica_dir/$rsn_template"; fi;
  mv -f groupICA/stats groupICA/report groupICA/melo* groupICA/Noise* groupICA/mean* groupICA/mask* groupICA/log* groupICA/eig* groupICA/$gica_dir/$rsn_template
   
done # cleanups 