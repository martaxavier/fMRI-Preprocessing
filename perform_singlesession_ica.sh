#!/bin/bash

#This script performs subject level ica analysis of the preprocessed functional data 
#
# The following scripts are called: 
#    prepare_pipeline: assigns, for each pipeline, input functional data and output directory
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
# Inputs in PREPROCESS/$subj/$pedir_dir directory:
#    example_func: middle volume of epi, in EF_U space 
#    mask: brain mask in EF_U space, output of BET (plus some processing operations)
#    filtered_func_data_clean: functional data after ica-fix cleaning 
#    filtered_func_data_preprocessed: functional data after ica-fix + nuisance reg + smoothing
#    filtered_func_data_peprocessed_gs: functional data after ica-fix + nuisance reg (+gs) + smoothing
#    filtered_func_data_clean_preprocessed: functional data after ica-fix + smoothing
#    filtered_func_data_clean_physio_preprocessed: functional data after ica-fix + nuisance reg (wm, csf) + smoothing
#    filtered_func_data_clean_motion_preprocessed: functional data after ica-fix + nuisance reg (mo, rp) + smoothing
#    filtered_func_data_nuisance_preprocessed: functional data after nuisance reg + hp temporal filtering + smoothing
#    filtered_func_data_nuisance_gs_preprocessed: functional data after nuisance reg (+gs) + hp temp filt + smoothing 
#
# 
# Output in PREPROCESS/$subj/$pedir_dir/$mel_dir directory:
#
# Output in PREPROCESS/$subj/$pedir_dir directory:

#
# Analysis inputs, specified in the begining of the script:
#   pe_dir: phase enconding direction
#   subj: subject id 
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
cleanup_list=("ica_mo_reg", "ica_mo_csf_reg", "ica_mo_csf_wm_reg")

# Declare reference RSN template ("smith" - Smith, 2009; "yeo" - Yeo, 2011)  
rsn_template = "smith"

if [[ $pe_dir == y- ]]; then pedir_dir="minusy"; else pedir_dir="plusy"; fi


#---------------------------------------- Read RSNs list from input .txt file ----------------------------------------# 
#---------------------------------------------------------------------------------------------------------------------# 

# Specify which .txt file containing the rsn names is going to be read 
if [ $rsn_template == "smith" ]; then

  input_list="list_smith_rsns.txt"
  
elif [ $rsn_template == "yeo" ]; then

  input_list="list_yeo_rsns.txt"
  
fi

rsn_list=() 
n=1

# Read specified file line by line and 
# add rsn name to variable rsn_list
while read line; do

new_rsn=$(echo "$line") 
rsn_list=( "${rsn_list[@]}" $new_rsn )
n=$((n+1))

done < $input_list


#--------------------------------------------------- Read dataset settings -------------------------------------------# 
#---------------------------------------------------------------------------------------------------------------------# 

# Create unique temporary directory 
tmpdir=$(mktemp -d) 

# Read dataset settings
. settings_dataset.sh
read subj_list < $tmpdir/subj_list.txt 


#------------------------------------------- Go through cleanup pipelines  -------------------------------------------# 
#---------------------------------------------------------------------------------------------------------------------# 

# Iterate through cleanup pipelines 
for cleanup in "${cleanup_list[@]}"; do  

  cd $path 
  
  # Assign flags and inputs for pipeline
  . settings_pipeline.sh
  
  # Read variables created in child process, in temporary directory
  read func_data < $tmpdir/func_data_final.txt
  read mel_dir < $tmpdir/mel_dir.txt;
  

  #------------------------------------------------ Go through subjects  -----------------------------------------------# 
  #---------------------------------------------------------------------------------------------------------------------#                                                               
  for i in "${subj_list[@]}"; do 
   
    # Change to current subjects directory                                                                
    cd $path/$dataset/PREPROCESS/$i/$task/$run/$pedir_dir
    
    
    #---------------------------------------- Perform ICA to preprocessed func data ------------------------------------#
    #-------------------------------------------------------------------------------------------------------------------# 
    
    # Create $mel_dir directory, if there isn't one already 
    if [[ ! -d $mel_dir ]]; then mkdir $mel_dir; fi; 
    cp -t $mel_dir example_func.nii.gz ${func_data}.nii.gz mask.nii.gz 
    
    # Create temporal average image 
    cd $mel_dir
    fslmaths $func_data -Tmean mean_func
    
    # Perform ICA inside mel.ssica directory
    melodic -i $func_data --report 
      
  done # Subjects
  
done # Cleanup pipelines 
