#!/bin/bash

# SCRIPT MIGHT HAVE BUGS 
#This script computes the dice coefficient between subject's ICs 
#and each of the ICs and each of the 10 RSNs in Smith et al. 2009
#
# The following scripts are called: 
#    settings_pipeline: assigns, for each pipeline, input functional data and output directory
#    settings_dataset:
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
# Inputs in PREPROCESS/$subj/$pedir_dir/$mel_dir directory:
#    example_func: middle volume of epi, in EF_U space 
#    mask: brain mask in EF_U space, output of BET (plus some processing operations)
#    filtered_func_data_clean: functional data after ica-fix cleaning 
#    filtered_func_data_preprocessed: functional data after ica-fix + nuisance reg + smoothing
#    filtered_func_data_peprocessed_gs: functional data after ica-fix + nuisance reg (+gs) + smoothing
#    filtered_func_data_clean_preprocessed: functional data after ica-fix + smoothing
#    filtered_func_data_clean_physio_preprocessed: functional data after ica-fix + nuisance reg (wm, csf) + smoothing
#    filtered_func_data_clean_motion_preprocessed: functional data after ica-fix + nuisance reg (mo, rp) + smoothing
#    filtered_func_data_nuisance_preprocessed: functional data after nuisance reg + hp temporal filtering + smoothing
# 

path=/home/mxavier/eeg-fmri/
cd $path


#--------------------------------------------- Declare analysis settings ---------------------------------------------# 
#---------------------------------------------------------------------------------------------------------------------# 

# Declare analysis settings 
dataset=PARIS
pe_dir="y-"              # phase encoding direction 
task="task-rest"         # "task-rest" "task-calib"
run="run-3"              # "run-1" "run-2" "run-3"
flag_std_reg=0

# Cleanup list: 
cleanup_list=("ica_mo_reg" "ica_mo_csf_reg" "ica_mo_csf_wm_reg")

# Declare reference RSN template ("smith" - Smith, 2009; "yeo" - Yeo, 2011)  
rsn_template ="smith"

if [[ $pe_dir == y- ]]; then pedir_dir="minusy"; else pedir_dir="plusy"; fi
 
# Declare reference image and reference image directory 
# Specify which .txt file containing the rsn names is going to be read 
if [ $rsn_template == "smith" ]; then

  input_list="list_smith_rsns.txt"
  ref_dir=STANDARD 
  ref=PNAS_Smith09_rsn_bin.nii.gz
  
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

#----------------------------------------------------- Assign RSN ----------------------------------------------------# 
#---------------------------------------------------------------------------------------------------------------------# 

 # Assign RSN list for current patient
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
 
#------------------------------------------- Go through cleanup pipelines --------------------------------------------# 
#---------------------------------------------------------------------------------------------------------------------# 

if [[ $pe_dir == y- ]]; then pedir_dir="minusy"; else pedir_dir="plusy"; fi 

# Iterate through cleanup pipelines 
for cleanup in "${cleanup_list[@]}"; do  

  cd $path 
  
  # Assign flags and inputs for pipeline
  . settings_pipeline.sh
  
  # Read variables created in child process, in temporary directory
  read func_data < $tmpdir/func_data_final.txt
  read mel_dir < $tmpdir/mel_dir.txt;
  
  #----------------------------------------------- Go through subjects -------------------------------------------------# 
  #---------------------------------------------------------------------------------------------------------------------#                               
   s=0
                           
   for i in "${subj_list[@]}"; do 
 
    cd $path
  
    if [[ ! -f "$dataset/PREPROCESS/$i/$task/$run/$pedir_dir/${ref}_func.nii.gz" ]]; then
 
      # Register (only once for each subject) Smiths/Yeos RSNs in subject's functional space     
      applywarp --in=$ref_dir/$ref --ref=$dataset/PREPROCESS/$i/$task/$run/$pedir_dir/example_func \
      --out="$dataset/PREPROCESS/$i/$task/$run/$pedir_dir/${ref}_func" --warp=$dataset/PREPROCESS/$i/$task/$run/$pedir_dir/unwarp/standard2highres_coef.nii.gz \
      --postmat=$dataset/PREPROCESS/$i/$task/$run/$pedir_dir/unwarp/highres2example_func.mat
      
     echo "RSNs registered in functional space for $i"
    
    fi
    
   #-------------------------------------------- Compute dice coefficients  -------------------------------------------# 
   #-------------------------------------------------------------------------------------------------------------------# 
   
    cd $dataset/PREPROCESS    
    cp "$i/$task/$run/$pedir_dir/${ref}_func_bin"* $i/$task/$run/$pedir_dir/$mel_dir
    cd $i/$task/$run/$pedir_dir/$mel_dir
    
    # Split binarized reference IC maps into separate images 
    fslsplit "${ref}_func_bin" STD  
  
    # Binarize subject IC image, thresholding at Z=3
    fslmaths "${func_data}.ica/melodic_IC" -thr 3 -bin $i
    
    # Split binarized subject IC maps into separate images
    fslsplit $i subj
    
    # Assign IC list for current patient
    ic_num=`fslval "$i" dim4` 
    ic_num=$(echo "$ic_num - 1"| bc -l)
    unset ic_list
    declare -a ic_list=()
    
    c=0
 
    while [ $c -le 9 ]; do
      if [[ $c -eq ic_num ]]; then
        c=$(echo "$c + 1" | bc -l)
        break
      fi
      ic_list=( "${ic_list[@]}" "000${c}" ) 
      c=$(echo "$c + 1" | bc -l)
    done
       
    while [ $c -le $ic_num ]; do
      ic_list=( "${ic_list[@]}" "00${c}" ) 
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
        
      done
  
    done 
        
    # Append subject's IC file to main file (at the end)
    paste dice* | column -s $'\t' -t >> "${i}_dice.txt"
      
    echo "Computed dice coefficients for subject $i, task ${sub_task}..." 
    
    # Remove files of current subject 
    imrm sub*
    rm STD00*
    rm dice*
    
    # Update subject number 
    s=$(echo "$s + 1" | bc -l)    
 
   done # subjects
  
done # cleanup pipelines 