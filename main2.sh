#!/bin/bash

# This script performs the second half of the pre-processing pipeline: fix-ica cleanup and nuisance regression 
#
# The following scripts are called: 
#    settings_pipeline: assigns, for each pipeline, flag values and input functional data
#    settings_dataset:
#    clean_ica_reg_noise:
#    clean_fix_noise:
#    perform_nuisance_reg:
#    perform_temporal_hpf:
#    perform_spatial_smoothing:
#
# Analysis inputs, specified in the begining of the script:
#   TR: acquisition repetition time (seconds)
#   echo_spacing: effective echo spacing (seconds)
#   hp_freq: high-pass filter cutoff frequency (Hz)
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
#    ica_mo_reg: ica + nonagressive regression (N-ICs, RP, MO)
#    ica_mo_csf_reg: ica + nonagressive regression (N-ICs, RP, WM, MO)
#    ica_mo_csf_wm_reg: ica + nonagressive regression (N-ICs, RP, WM, CSF, MO)
#
# Inputs in PREPROCESS/$subj/$pedir_dir directory:
#    unwarp: directory containing all transformations from EF_D space to EF_U space (vice-versa) and from struc to func space (vice-versa)
#    mc: directory containing the motion realignment parameters and the linear transformation (.cat) for motion artifact corrected 
#    mel.ica: directory containing 
#    example_func: middle volume of epi, in EF_U space 
#    example_func_distorted: middle volume of epi, in EF_D space 
#    filtered_func_data: 4D data, in EF_U space, corrected for motion artifacts, high-pass filtered 
#    filtered_func_data_nofilt: 4D daata, in EF_U space, corrected for motion artifacts (withou high-pass filtering) 
#    mean_func: 3D image, temporal mean of filtered_func_data
#    mask: brain mask in EF_U space, output of BET (plus some processing operations)
#    highres: structural image, same as input 
#    highres_bet: structural image, brain extracted, same as input
#    mo_confound: text file for the confound model, output of motion_outliers 
#    CSF_thr: CSF mask, thresholded and binarized, in the highres space 
#    WM_thr: WM mask, thresholded and binarized, in the highres space 
#
# Inputs in PREPROCESS/$subj/$pedir_dir/mel.ica directory:
#    mc directory
#    reg directory: example_func2highres, highres2example_func
#    filtered_func_data.ica: contains Melodic_IC, the 4D image with the IC's spatial maps               
#    example_func
#    mean_func
#    highres, highres head 
#
# Inputs in PREPROCESS/$subj/$pedir_dir/mel.ica directory:
#     fix: directory with results of fix analysis 
#     fix4me: text file with the classification of ics 
# 
# Output in PREPROCESS/$subj/$pedir_dir/unwarp directory:
#    highres2standard_aff: affine transformation from structural to standard space            
#    highres2standard_coef: warp coefficients from structural to standard space 
#    highres_coef: warp coefficients from standard to structural space 
#
# Output in PREPROCESS/$subj/$pedir_dir directory:
#    filtered_func_data_clean: functional data after ica-fix cleaning 
#    filtered_func_data_preprocessed: functional data after ica-fix + nuisance reg + smoothing
#    filtered_func_data_peprocessed_gs: functional data after ica-fix + nuisance reg (+gs) + smoothing
#    filtered_func_data_clean_preprocessed: functional data after ica-fix + smoothing
#    filtered_func_data_clean_physio_preprocessed: functional data after ica-fix + nuisance reg (wm, csf) + smoothing
#    filtered_func_data_clean_motion_preprocessed: functional data after ica-fix + nuisance reg (mo, rp) + smoothing
#    filtered_func_data_nuisance_preprocessed: functional data after nuisance reg + hp temporal filtering + smoothing
#    filtered_func_data_preprocessed_ica_mo_reg: functional data after ica + nonagressive regression of N-IC, RP and MO time-series  
#    filtered_func_data_preprocessed_ica_mo_csf_reg: functional data after ica + nonagressive regression of N-IC, RP, MO and CSF time-series
#    filtered_func_data_preprocessed_ica_mo_csf_wm_reg: functional data after ica + nonagressive regression of N-IC, RP, MO, CSF and WM time-series

path=/home/mxavier/eeg-fmri/
cd $path


#--------------------------------------------- Declare analysis settings ---------------------------------------------# 
#---------------------------------------------------------------------------------------------------------------------# 

# Declare analysis settings 
dataset=PARIS
pe_dir="y-"              # phase encoding direction 
task="task-rest"         # "task-rest" "task-calib"
run="run-3"              # "run-1" "run-2" "run-3"
mo_metric="dvars"
flag_std_reg=0

# Cleanup list: 
cleanup_list=("ica_mo_reg" "ica_mo_csf_reg" "ica_mo_csf_wm_reg")

if [[ $pe_dir == y- ]]; then pedir_dir="minusy"; else pedir_dir="plusy"; fi

#--------------------------------------------------- Read dataset settings -------------------------------------------# 
#---------------------------------------------------------------------------------------------------------------------# 

# Create unique temporary directory 
if find ${path}tmp -mindepth 1 -maxdepth 1 | read; then rm ${path}tmp/*; fi
tmpdir=$path/tmp

# Define exit trap
#trap "rm -f $tmpdir/* ; rmdir $tmpdir ; exit" EXIT

# Read dataset settings
. settings_dataset.sh
read TR < $tmpdir/TR.txt
read hp_freq < $tmpdir/hp_freq.txt
read fwhm < $tmpdir/fwhm.txt
read fix_train_data < $tmpdir/fix_train_data.txt
read fix_txt_out < $tmpdir/fix_txt_out.txt
read subj_list < $tmpdir/subj_list.txt 

#---------------------------------------- Perform registration to standard space -------------------------------------# 
#---------------------------------------------------------------------------------------------------------------------# 
  
# Perform registration to std space 
if [[ $flag_std_reg == 1 ]]; then

  # Iterate through subjects 
  for i in "${subj_list[@]}"; do 
    
    cd $path/$dataset/PREPROCESS/$i/$task/$run/$pedir_dir
    
    fslmaths /usr/local/fsl/data/standard/MNI152_T1_2mm_brain standard
    fslmaths /usr/local/fsl/data/standard/MNI152_T1_2mm standard_head 
    fslmaths /usr/local/fsl/data/standard/MNI152_T1_2mm_brain_mask_dil standard_mask
    
    # Create linear and non-linear warp transformations from structural to standard space 
    # First perform a linear registration  
    flirt -in highres -ref standard -omat highres2standard_aff.mat -cost corratio -dof 12 -interp trilinear
    
    # Use the linear transformation to initialize the non-linear registration 
    fnirt --iout=highres2standard_head --in=highres_head --aff=highres2standard_aff.mat --cout=highres2standard_coef \
    --iout=highres2standard --jout=highres2highres_jac --config=T1_2_MNI152_2mm --ref=standard_head \
    --refmask=standard_mask --warpres=10,10,10
    
    # Use the transformation to register the structural image to standard space
    applywarp -i highres -r standard -o highres2standard -w highres2standard_coef 
    
    # Obtain transformations from standard to structural space (linear and non-linear)
    convert_xfm -inverse -omat standard2highres_aff.mat highres2standard_aff.mat
    invwarp --ref=highres --warp=highres2standard_coef --out=standard2highres_coef  

    # Create linear and non-linear warp transformation from functional to standard space 
    convert_xfm -omat example_func2standard_aff.mat -concat unwarp/highres2standard_aff.mat unwarp/example_func2highres.mat
    convertwarp --ref=standard --premat=unwarp/example_func2highres.mat --warp1=unwarp/highres2standard_coef --out=example_func2standard_coef
    
    # Use the transformation to register the functional image to standard space
    applywarp --ref=standard --in=example_func --out=example_func2standard --warp=example_func2standard_coef
    
    # Obtain transformations from standard to functional space (linear and non-linear)
    convert_xfm -inverse -omat standard2example_func_aff.mat example_func2standard_aff.mat
    invwarp --ref=highres --warp=example_func2standard_coef --out=standard2example_func_coef 
    
    # Create a ventricle mask from an atlas
    fslroi /usr/local/fsl/data/atlases/HarvardOxford/HarvardOxford-sub-prob-2mm.nii.gz LVentricle 2 1 
    fslroi /usr/local/fsl/data/atlases/HarvardOxford/HarvardOxford-sub-prob-2mm.nii.gz RVentricle 13 1
    fslmaths LVentricle -add RVentricle -thr 0.1 -bin -dilF Ventricle 
    rm LVentricle* RVentricle* 
  
    # Register the ventrical mask to current subject's structural space
    applywarp --in=Ventricle --ref=highres --out=H_Ventricle --warp=unwarp/standard2highres_coef
    
    # Register the ventrical mask to current subject's functional space 
    applywarp --in=Ventricle --ref=example_func --out=EF_Ventricle --warp=standard2example_func_coef
    
    # Move warp files to unwarp directory (contains all transformations)
    mv -f standard* example_func2* highres2* standard2* unwarp; rm highres_to*;
    
    # Change permissions in unwarp directory 
    cd unwarp; chmod 777 *; cd ..
    
  done
  
fi 


#------------------------------------------- Go through cleanup pipelines  -------------------------------------------# 
#---------------------------------------------------------------------------------------------------------------------# 

# Iterate through cleanup pipelines 
for cleanup in "${cleanup_list[@]}"; do 

  echo "Applying the ${cleanup} cleanup pipeline..." 

  cd $path 
  
  # Assign flags and inputs for pipeline
  . settings_pipeline.sh
  
  # Read variables created in child process, in temporary directory
  read flag_wm < $tmpdir/flag_wm.txt
  read flag_csf < $tmpdir/flag_csf.txt
  read flag_mo < $tmpdir/flag_mo.txt
  read flag_rp < $tmpdir/flag_rp.txt
  read flag_rp_exp < $tmpdir/flag_rp_exp.txt  
  read flag_gs < $tmpdir/flag_gs.txt   
  read flag_ica_reg < $tmpdir/flag_ica_reg.txt
  read flag_icafix < $tmpdir/flag_icafix.txt
  read flag_nuisance < $tmpdir/flag_nuisance.txt
  read flag_ss < $tmpdir/flag_ss.txt
  read flag_hpf < $tmpdir/flag_hpf.txt
  read func_data_in < $tmpdir/func_data_in.txt
  read func_data_final < $tmpdir/func_data_final.txt


  #---------------------------------------- Perform ICA+Nuisance Reg. Cleanup ----------------------------------------# 
  #-------------------------------------------------------------------------------------------------------------------# 
  
  if [[ $flag_ica_reg == 1 ]]; then
  
    func_data_out="filtered_func_data_ica_reg.nii.gz"
    
    # Iterate through subjects 
    for i in "${subj_list[@]}"; do 
      
      cd $path/$dataset/PREPROCESS/$i/$task/$run/$pedir_dir
      . $path/clean_ica_reg_noise.sh 
      
      echo "Nuisance regression (N-ICs + regressors) performed for subject $i"
      
    done
    
    # Update input func data for rest of pipeline
    func_data_in=$func_data_out
    
  fi
  
  
  #---------------------------------------------- Perform ICA-FIX cleanup  -------------------------------------------# 
  #-------------------------------------------------------------------------------------------------------------------# 
  
  # Perform ica-fix cleanup 
  if [[ $flag_icafix == 1 ]]; then
    
    func_data_out="filtered_func_data_clean.nii.gz"
    
    # Iterate through subjects 
    for i in "${subj_list[@]}"; do 
      
      cd $path/$dataset/PREPROCESS/$i/$task/$run/$pedir_dir
      . $path/clean_fix_noise.sh 
      
      echo "FIX-ICA performed for subject $i"      
      
    done
    
    # Update input func data for rest of pipeline
    func_data_in=$func_data_out
    
  fi 
  
  #-------------------------------------------- Perform nuisance regression  -----------------------------------------# 
  #-------------------------------------------------------------------------------------------------------------------# 
  
  # Perform ica-fix cleanup 
  if [[ $flag_nuisance == 1 ]]; then
  
  func_data_out="filtered_func_data_nuisance.nii.gz"

    # Iterate through subjects 
    for i in "${subj_list[@]}"; do 
      
      cd $path/$dataset/PREPROCESS/$i/$task/$run/$pedir_dir
      . $path/perform_nuisance_reg.sh 
      
      echo "Nuisance regression performed for subject $i"      
      
    done
    
    # Update input func data for rest of pipeline
    func_data_in=$func_data_out
    
  fi
  
  
  #-------------------------------------------- Perform high-pass filtering  -----------------------------------------# 
  #-------------------------------------------------------------------------------------------------------------------# 
  
  # Perform ica-fix cleanup 
  if [[ $flag_hpf == 1 ]]; then
  
    func_data_out="filtered_func_data_tempfilt.nii.gz" 
    
    # Iterate through subjects 
    for i in "${subj_list[@]}"; do 
      
      cd $path/$dataset/PREPROCESS/$i/$task/$run/$pedir_dir
      . $path/perform_temporal_hpf.sh
      
      echo "Temporal high-pass filtering performed for subject $i"      
      
    done
    
    # Update input func data for rest of pipeline
    func_data_in=$func_data_out
    
  fi
  
  #--------------------------------------------- Perform spatial smoothing  ------------------------------------------# 
  #-------------------------------------------------------------------------------------------------------------------# 
  
  if [[ $flag_ss == 1 ]]; then
  
    func_data_out="filtered_func_data_smooth.nii.gz"
  
    # Iterate through subjects 
    for i in "${subj_list[@]}"; do 
    
      cd $path/$dataset/PREPROCESS/$i/$task/$run/$pedir_dir
      . $path/perform_spatial_smoothing.sh
      
      echo "Spatial smoothing performed for subject $i"      
    
    done
  
    # Update input func data for rest of pipeline
    func_data_in=$func_data_out
    
  fi
  
  #--------------------------------------------- Finishing operations  ------------------------------------------# 
  #-------------------------------------------------------------------------------------------------------------------#
      
  # Iterate through subjects 
  for i in "${subj_list[@]}"; do 
  
    cd $path/$dataset/PREPROCESS/$i/$task/$run/$pedir_dir
    
    # Extract temporal mean of filtered_func_data_preprocessed
    fslmaths $func_data_in -Tmean mean_func
    
    # Rename the output according to the current pipeline
    cp $func_data_in ${func_data_final}.nii.gz
    
    echo "Cleanup finished for subject $i"     
  
  done
    
done