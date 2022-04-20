#!/bin/bash

# SCRIPT MIGHT HAVE BUGS 
#This script extracts the average signal from a given ROI, obtained by  
#thresholding the IC in melodic_IC most similar with the DMN in Smith et al. 2009 
#
# The following scripts are called: 
#    settings_pipeline: assigns, for each pipeline, input functional data and output directory
#    settings_dataset:
#
# Analysis inputs, specified in the begining of the script:
#   pe_dir: phase enconding direction
#   z_thresh: z threshold value to obtain rois  
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
#    filtered_func_data_nuisance_gs_preprocessed: functional data after nuisance reg (+gs) + hp temp filt + smoothing 


path=/home/mxavier/eeg-fmri/
cd $path


#--------------------------------------------- Declare analysis settings ---------------------------------------------# 
#---------------------------------------------------------------------------------------------------------------------# 

# Declare analysis settings 
dataset=PARIS
pe_dir="y-"              # phase encoding direction 
task="task-rest"         # "task-rest" "task-calib"
run="run-3"              # "run-1" "run-2" "run-3"

# Cleanup list: 
cleanup_list=("ica_mo_reg" "ica_mo_csf_reg" "ica_mo_csf_wm_reg")

# Declare reference RSN template ("smith" - Smith, 2009; "yeo" - Yeo, 2011)  
rsn_template="smith"

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

if find ${path}tmp -mindepth 1 -maxdepth 1 | read; then rm ${path}tmp/*; fi
tmpdir=$path/tmp

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
  func_data_dir=$func_data
  
    
   #----------------------------------------------- Go through subjects  ----------------------------------------------# 
   #-------------------------------------------------------------------------------------------------------------------#                                   
   s=0
                             
   for i in "${subj_list[@]}"; do 
 
     subj_dir=$dataset/PREPROCESS/$i/$task/$run/$pedir_dir
     cd $path/$subj_dir
     if [[ ! -d "rsns" ]]; then mkdir "rsns"; fi; 
     
     #-------------------------------------------- Read subject's rsns file ---------------------------------------------# 
     #-------------------------------------------------------------------------------------------------------------------# 
     
     while read line; do rsns+=("$line"); done < "rsns/rsns.txt"
        
     cd $mel_dir
       
     # Binarize subject IC image, thresholding at Z=3
     fslmaths "${func_data_dir}.ica/melodic_IC" -thr $z_thresh -bin $i
     
     # Split binarized subject IC maps into separate images
     fslsplit $i subj
     
     cd ..
       
     r=0
     
     for j in "${rsn_list[@]}"; do
      
        #------------------------------------------- Extract IC time-series  ---------------------------------------------# 
        #-----------------------------------------------------------------------------------------------------------------# 
        
        ic=$(echo "${rsns[$r]}")
        cp "$mel_dir/${func_data_dir}.ica/report/t${ic}.txt" "rsns/ic_${j}.txt"
         
        #----------------------------------------- Extract ROI from melodic_IC  ------------------------------------------# 
        #-----------------------------------------------------------------------------------------------------------------# 
        
        # Extract roi from DMN IC (in ic_list)
        ic_mel=$(echo "$ic - 1" | bc -l)
        
        if [ $ic_mel -lt 10 ]
        then
          ic_mel=$(echo "000${ic_mel}") 
        else
          ic_mel=$(echo "00${ic_mel}")
        fi
        
        cp "$mel_dir/subj${ic_mel}.nii.gz" "rsns/mask_${j}.nii.gz" 
        
        #------------------------------------- Extract average time-series from ROI  -------------------------------------# 
        #-----------------------------------------------------------------------------------------------------------------# 
      
        # Extract average signal from ROI 
        fslmeants -i $func_data -m "$mel_dir/subj${ic_mel}" -o "rsns/avg_${j}.txt"
       
        # Update rsn number 
        r=$(echo "$r + 1" | bc -l) 
      
     done # Looping through rsns
      
     # Clear rsns variable for current subject
     unset rsns
     
     # Remove aux data for current subject 
     cd $mel_dir; rm subj*; imrm sub*; cd ..
     
     # Update subject number 
     s=$(echo "$s + 1" | bc -l) 
     
     echo "RSNs extracted for ${i}"
     
   done # Subjects

done # Cleanup pipelines 
