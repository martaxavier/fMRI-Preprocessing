#!/bin/bash

# This script performs the first part of the pre-processing pipeline - minimal pre-processing and registration
#
# Analysis inputs, specified in the begining of the script:
#   TR: acquisition repetition time (seconds)
#   echo_spacing: effective echo spacing (seconds)
#   hp_freq: high-pass filter cutoff frequency (Hz)
#   pe_dir: phase enconding direction
#   subj_ist: list of subjects to be analysed 
#
# Inputs in each DERIVATIVES/$subj/bet_fast directory:
#   $subj_MPRAGE: raw structural image 
#   $subj_MPRAGE: structural image, brain extracted, BET output 
#   $subj_MPRAGE_brain_pve0: CSF probabilistic , FAST output
#   $subj_MPRAGE_brain_pve1: WM probabilistic mask, FAST output
#
# Inputs in each DERIVATIVES/$subj/fmap_prepare directory:
#   $subj_fmap_mag: fieldmap magnitude image (one of the two: best looking one)
#   $subj_fmap_mag_brain: fieldmap magnitude image, brain extracted, BET output 
#   $subj_fmap_rads: fieldmap image, output of fsl_prepare_fieldmap
# 
# Inputs in each DATA/$subj/func directory:
#   $subj_epi: raw 4D functional data 
#
# Outputs in PREPROCESS/$subj/$pedir_dir directory:
#    unwarp: directory containing all transformations from EF_D space to EF_U space (vice-versa) and from struc to func space (vice-versa)
#    mc: directory containing the motion realignment parameters and the linear transformation (.cat) for motion artifact corrected 
#    example_func: middle volume of epi, in EF_U space 
#    example_func_distorted: middle volume of epi, in EF_D space 
#    filtered_func_data: 4D data, in EF_U space, corrected for motion artifacts, high-pass filtered 
#    mean_func: 3D image, temporal mean of filtered_func_data
#    mask: brain mask in EF_U space, output of BET (plus some processing operations)
#    highres: structural image, same as input 
#    highres_bet: structural image, brain extracted, same as input
#    mo_confound: text file for the confound model, output of motion_outliers 
#    CSF_thr: CSF mask, thresholded and binarized, in the highres space 
#    WM_thr: WM mask, thresholded and binarized, in the highres space 
# 
# Legend: 
#    FM: fieldmap space
#    EF: example_func space 
#    D: distorted 
#    U: undistorted 

#---------------------------------------------- Prepare some input data ----------------------------------------------# 
#---------------------------------------------------------------------------------------------------------------------# 
  
  # Binarize WM and CSF masks from probabilistic maps and copy result to current directory
  fslmaths $path/$dataset/DERIVATIVES/$i/bet_fast/${i}_T1_crop_restore_brain_pve_0.nii* -thr 1 CSF_thr.nii.gz
  fslmaths $path/$dataset/DERIVATIVES/$i/bet_fast/${i}_T1_crop_restore_brain_pve_2.nii* -thr 1 WM_thr.nii.gz

  # Copy original strucutral image and structural image after bet to current directory
  imcp $path/$dataset/DERIVATIVES/$i/bet_fast/${i}_T1_crop_restore.nii* highres_head.nii.gz
  imcp $path/$dataset/DERIVATIVES/$i/bet_fast/${i}_T1_crop_restore_brain.nii* highres.nii.gz
  
  # Copy functional data to current directory
  cp $path/$dataset/DATA/$i/func/$func_data_raw epi.nii.gz
  
  # Copy registration files
  if [[ ! -d unwarp ]]; then mkdir unwarp; fi; cp $path/$dataset/DERIVATIVES/$i/reg/* unwarp
  
  # Remove first 5 volumes of data 
  if [[ $dataset == "NODDI" ]]
  then
    fslsplit epi
    rm vol0000.nii.gz vol0001.nii.gz vol0002.nii.gz vol0003.nii.gz vol0004.nii.gz
    fslmerge -t epi vol*
    rm vol*
  else   

  # Extract example volume from middle volume
  n_vols=$(fslval epi dim4) 
  mid_vol=$(echo $(( n_vols / 2 ))) 

  fslroi epi.nii.gz example_func $mid_vol 1 
  
  #----------------------------------------- Perform Registration with epi_reg -----------------------------------------#
  #---------------------------------------------------------------------------------------------------------------------# 
  
  # Estimate transformation matrices and transformated images and save it in "unwarp" directory
  epi_reg --epi=example_func --t1=highres_head --t1brain=highres --out=example_func2highres --pedir=$pe_dir 

  # Obtain transformation matrix from strucutral space to undistorted functional space 
  convert_xfm -inverse -omat highres2example_func.mat example_func2highres.mat
  
  # Obtain a version of the highres image in the example_func space
  flirt -in highres -ref example_func -applyxfm -init highres2example_func.mat -out highres2example_func -interp trilinear 
  
  # Create and organize unwarp directory - contains all transformations and warps 
  mv example_func2* highres2* unwarp
  chmod 777 unwarp/*
  
  #---------------------------- Perform Motion Correction and obtain Realignment Parameters ----------------------------#
  #---------------------------------------------------------------------------------------------------------------------# 
  
  # Use MCFLIRT to estimate 6 realignment parameters (RP)
  # and correct distorted functional image for motion artefacts
  mcflirt -in epi -out epi_mcf -mats -plots -reffile \
  example_func -rmsrel -rmsabs -spline_final
  
  # Create and organize mc directory - contains all motion parameters 
  mkdir -p mc ; mv -f epi_mcf.mat epi_mcf.par epi_mcf_abs.rms\
   epi_mcf_abs_mean.rms epi_mcf_rel.rms epi_mcf_rel_mean.rms mc
  
  # Create plots of realignment parameters throughout time
  # MCFLIRT estimated rotations in mm (three)
  cd mc; fsl_tsplot -i epi_mcf.par -t 'MCFLIRT estimated rotations (radians)' \
  -u 1 --start=1 --finish=3 -a x,y,z -w 640 -h 144 -o rot.png
  
  # MCFLIRT estimated translations in mm (three)
  fsl_tsplot -i epi_mcf.par -t 'MCFLIRT estimated translations (mm)' \
  -u 1 --start=4 --finish=6 -a x,y,z -w 640 -h 144 -o trans.png 
  
  # MCFLIRT estimated mean displacement in mm 
  fsl_tsplot -i epi_mcf_abs.rms,epi_mcf_rel.rms \
  -t 'MCFLIRT estimated mean displacement (mm)' \
  -u 1 -w 640 -h 144 -a absolute,relative -o disp.png; cd .. 
  
  # Concatenate all 6 estimated realignment parameters in epi_mcf.cat
  cat mc/epi_mcf.mat/MAT* > mc/epi_mcf.cat 
    
  # Copy realignment parameters to main subject's directory and reshape it 
  cp mc/epi_mcf.par prefiltered_func_data_mcf.par
  mv prefiltered_func_data_mcf.par prefiltered_func_data_mcf.txt
  
  #awk '{print $1}' prefiltered_func_data_mcf.txt >> rp_1.txt;awk '{print $2}' prefiltered_func_data_mcf.txt >> rp_2.txt
  #awk '{print $3}' prefiltered_func_data_mcf.txt >> rp_3.txt;awk '{print $4}' prefiltered_func_data_mcf.txt >> rp_4.txt
  #awk '{print $5}' prefiltered_func_data_mcf.txt >> rp_5.txt;awk '{print $6}' prefiltered_func_data_mcf.txt >> rp_6.txt 
  #rm prefiltered_func_data_mcf.txt; paste rp* | column -s $'\t' -t >> prefiltered_func_data_mcf.txt; rm rp*

    
  #----------------------------- Brain extraction of 4D data and processing of brian mask  -----------------------------#
  #---------------------------------------------------------------------------------------------------------------------# 
  
  # Extract temporal average of 4D data 
  fslmaths epi_mcf -Tmean mean_func
  
  # Perform brain extraction on averaged 4D (now 3D) data and create brain mask (mask)
  bet2 mean_func mask -f 0.3 -n -m; immv mask_mask mask
  
  # Create skull-stripped time-series (epi_bet) with mask
  fslmaths epi_mcf -mas mask epi_bet
  
  # Threshold skull-stripped time-series (epi_bet) to remove values with very low
  # intensity (lower than 1/10 its 98th percentile) and obtain a final mask
  percentile=`fslstats 'epi_bet' -p 98`; thresh=`expr ${percentile%.*} / 10`
  
  # Thresh is the brain/background threshold for the final mask 
  fslmaths epi_bet -thr $thresh -Tmin -bin mask -odt char 
  fslmaths mask -dilF mask 
  
  # Mask 4D data with thresholded brain mask to obtain
  # final skull-stripped time-series (epi_thresh)
  fslmaths epi_mcf -mas mask epi_thresh
  
  #------------------------------------------ Identify Motion Outliers in 4D data --------------------------------------#
  #---------------------------------------------------------------------------------------------------------------------# 
  
  # Use the skull-stripped time-series as input to identify outliers 
  fsl_motion_outliers -i epi_thresh -o mo_confound.txt --refrms --nomoco
  
  #----------------------------------------- Apply temporal filter to 4D EPI data --------------------------------------#
  #---------------------------------------------------------------------------------------------------------------------# 
  
  # Intensity normalization to ensure that final data has median ~ 10 000
  median=`fslstats 'epi_mcf' -k 'mask' -p 50`; fac=`expr 10000 / ${median%.*}`
  fslmaths epi_thresh -mul $fac epi_intnorm
  
  # Apply high-pass temporal filter to functional data 
  hp_sigma=$(echo "1 / (2 * $TR * $hp_freq)" | bc -l)
  fslmaths epi_intnorm -Tmean tempMean
  fslmaths epi_intnorm -bptf $hp_sigma -1 -add tempMean epi_tempfilt
  imrm tempMean
  
  fslmaths epi_intnorm -Tmean mean_func

  #---------------------------------------- Apply spatial smoothing to 4D EPI data -------------------------------------#
  #---------------------------------------------------------------------------------------------------------------------# 
  
  # Use mean_func as the usan and determine its median intensity value within the brain mask
  # FWHM = 2.355 sigma, hence sigma = FWHM / 2.355
  sigma=$(echo "$fwhm / 2.355" | bc -l)
  median=`fslstats epi_tempfilt -k mask -p 50`
  bright_thr=$(echo "$median * 0.75" | bc -l)
  median_usan=`fslstats mean_func -k mask -p 50`
  bright_thr_usan=$(echo "$median_usan * 0.75" | bc -l)
  susan epi_tempfilt $bright_thr $sigma 3 1 1 mean_func $bright_thr_usan epi_smooth
  fslmaths epi_smooth -mas mask epi_smooth.nii.gz
  
  # Intensity normalization to ensure that final data has median ~ 10 000
  # Median is already close to what it should be for higher level analysis but still it is better to perform this step 
  median=`fslstats epi_smooth -k 'mask' -p 50` 
  fac=$(echo "10000 / $median" | bc -l)
  fslmaths epi_smooth -mul $fac epi_smooth
  
  fslmaths epi_smooth -Tmean mean_func
  
  mv epi_intnorm* filtered_func_data_notempfilt.nii.gz;
  mv epi_tempfilt* filtered_func_data_nospatfilt.nii.gz;
  mv epi_smooth.nii.gz filtered_func_data.nii.gz;
  rm epi*