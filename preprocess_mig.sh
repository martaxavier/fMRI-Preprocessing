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
#   $subj_MPRAGE_brain_pve0: CSF probabilistic mask, FAST output
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
  fslmaths $path/$dataset/DERIVATIVES/$i/bet_fast/"$i"_MPRAGE_brain_pve_0.nii* -thr 1 CSF_thr.nii.gz
  fslmaths $path/$dataset/DERIVATIVES/$i/bet_fast/"$i"_MPRAGE_brain_pve_2.nii* -thr 1 WM_thr.nii.gz
  fslmaths $path/$dataset/DERIVATIVES/$i/bet_fast/"$i"_MPRAGE_brain_pve_1.nii* -thr 1 GM_thr.nii.gz
  
  # Copy fieldmap phase and magnitude (before and after bet) images to current directory 
  imcp $path/$dataset/DERIVATIVES/$i/$run/fmap_prepare/"$i"_"$run"_fmap_mag.nii* FM_U_fmap_mag.nii.gz
  imcp $path/$dataset/DERIVATIVES/$i/$run/fmap_prepare/"$i"_"$run"_fmap_mag_brain.nii* FM_U_fmap_mag_brain.nii.gz
  imcp $path/$dataset/DERIVATIVES/$i/$run/fmap_prepare/"$i"_"$run"_fmap_rads.nii* FM_U_fmap.nii.gz
  
  # Copy original strucutral image and structural image after bet to current directory
  imcp $path/$dataset/DERIVATIVES/$i/bet_fast/"$i"_MPRAGE.nii* highres_head.nii.gz
  imcp $path/$dataset/DERIVATIVES/$i/bet_fast/"$i"_MPRAGE_brain.nii* highres.nii.gz
    
  # Copy registration coefficients from highres to standard space
  imcp $path/$dataset/DERIVATIVES/$i/fnirt_reg2standard/reg_nonlinear_coef_T1tostandard_2mm.nii.gz highres2standard_coef.nii.gz
  
  # Copy functional data to current directory
  imcp $path/$dataset/DATA/$i/$run/func/"$i"_"$run"_"$task"_acq-ep2d_p2_s3_bold.nii* epi.nii.gz

  # Extract example volume from middle volume
  n_vols=$(fslval epi dim4) 
  mid_vol=$(echo $(( n_vols / 2 ))) 
  fslroi epi.nii.gz example_func $mid_vol 1 
  
  
  #------------------------------------- Preprocess and regularize fieldmap images -------------------------------------#
  #---------------------------------------------------------------------------------------------------------------------# 
  
  # Create fieldmap brain mask from the magnitude fieldmap image 
  fslmaths FM_U_fmap_mag_brain -bin FM_U_fmap_mag_brain_mask -odt short 
   
  # Erode the fieldmap magnitude image and add the values with very high intensity to create final mask
  # The goal is that the final mask is eroded, but keeping the regions with very high intensity
  percentile=`fslstats 'FM_U_fmap_mag_brain' -P 98`
  thresh=`expr ${percentile%.*} / 2`
  fslmaths FM_U_fmap_mag_brain -thr $thresh -bin FM_U_fmap_mag_brain_mask50
  fslmaths FM_U_fmap_mag_brain_mask -ero FM_U_fmap_mag_brain_mask_ero
  fslmaths FM_U_fmap_mag_brain_mask_ero -add FM_U_fmap_mag_brain_mask50 -thr 0.5 -bin FM_U_fmap_mag_brain_mask
  
  # Extract the median value of the fieldmap image regions inside the brain and subtract it to the fieldmap
  # Ensure the distribution is centered in zero (it should already be)
  median=`fslstats 'FM_U_fmap' -k 'FM_U_fmap_mag_brain_mask' -P 50` 
  fslmaths FM_U_fmap -sub $median -mas FM_U_fmap_mag_brain_mask FM_U_fmap
  
  # Mask the final fieldmap image and magnitude image with the final magnitude brain mask image
  fslmaths FM_U_fmap -mas FM_U_fmap_mag_brain_mask FM_U_fmap 
  fslmaths FM_U_fmap_mag_brain -mas FM_U_fmap_mag_brain_mask FM_U_fmap_mag_brain
  
  # Erode the final mask to obtain its eroded version 
  fslmaths FM_U_fmap_mag_brain_mask -ero FM_U_fmap_mag_brain_mask_ero
  
  # Use fugue to obtain a regularized fieldmap FM_U_tmp_fmapfilt 
  fugue --loadfmap=FM_U_fmap --savefmap=FM_U_fmap_tmp_fmapfilt \
  --mask=FM_U_fmap_mag_brain_mask --despike --despikethreshold=2.1
  
  # Perform final processing operations to the fieldmap 
  fslmaths FM_U_fmap -sub FM_U_fmap_tmp_fmapfilt -mas \
  FM_U_fmap_mag_brain_mask_ero -add FM_U_fmap_tmp_fmapfilt FM_U_fmap
  #median=`fslstats 'FM_U_fmap' -k 'FM_U_fmap_mag_brain_mask' -P 50` 
  #fslmaths FM_U_fmap -sub $median -mas FM_U_fmap_mag_brain_mask FM_U_fmap
  
  # Remove files that will no longer be needed 
  rm -f FM_U_fmap_tmp_fmapfilt* FM_U_fmap_mag_brain_mask_ero* \
  FM_U_fmap_mag_brain_mask50*
  
  
  #---------------------------- Perform Distortion Correction and Registration with epi_reg ----------------------------#
  #---------------------------------------------------------------------------------------------------------------------# 
  
  # Estimate transformation matrices and transformated images and save it in "unwarp" directory
  epi_reg --epi=example_func --t1=highres_head --t1brain=highres --out=example_func2highres --fmap=FM_U_fmap \
  --fmapmag=FM_U_fmap_mag --fmapmagbrain=FM_U_fmap_mag_brain --echospacing=$echo_spacing --pedir=$pe_dir
  
  # Register the undistorted fieldmap magnitude image to functional space 
  # to obtain the undistorted fieldmap magnitude image in the functional space
  flirt -ref example_func -in FM_U_fmap_mag_brain -applyxfm -init \
  example_func2highres_fieldmaprads2epi.mat -out EF_U_fmap_mag_brain
  
  # Register the distorted example_func to structural image, to obtain the 
  # distorted example_func in structural space (this is for comparison purposes)
  flirt -ref highres -in example_func -out example_func_distorted2highres -applyxfm \
  -init example_func2highres.mat -interp trilinear 
  
  # Obtain transformation matrix from strucutral space to undistorted functional space 
  convert_xfm -inverse -omat highres2example_func.mat example_func2highres.mat
  
  # Unwarp example_func in structural space to obtain example_func_undistorted
  applywarp -i example_func2highres -r example_func --premat=highres2example_func.mat \
  -o example_func_undistorted
  
  # Obtain a version of the highres image in the example_func space
  flirt -in highres -ref example_func -applyxfm -init \
  highres2example_func.mat -out highres2example_func
  
  # Create and organize unwarp directory - contains all transformations and warps 
  mkdir unwarp; mv example_func2* highres2* example_func_distorted2* unwarp
  cd unwarp; mv example_func2highres_fieldmap2str.mat FM_U_fmap_mag_brain2highres.mat

  # Replace prefix example_func2highres_fieldmap2str for FM_U_fmap_mag_brain2highres
  for file in example_func2highres_fieldmap2str*
    do mv "$file" "FM_U_fmap_mag_brain2highres${file#example_func2highres_fieldmap2str}"
  done

  # Replace prefix example_func2highres_fieldmaprads2str for FM_U_fmap2highres  
  for file in example_func2highres_fieldmaprads2str*
    do mv "$file" "FM_U_fmap2highres${file#example_func2highres_fieldmaprads2str}"
  done

  # Replace prefix example_func2highres_fieldmaprads2epi for FM_U_fmap2epi 
  for file in example_func2highres_fieldmaprads2epi*
    do mv "$file" "FM_U_fmap2epi${file#example_func2highres_fieldmaprads2epi}"
  done
  chmod 777 *; cd .. 
  
  # Change file names in main directory 
  fslmaths example_func example_func_distorted
  fslmaths example_func_undistorted example_func
  rm example_func_undistorted.nii.gz
  
  
  #---------------------------- Perform Motion Correction and obtain Realignment Parameters ----------------------------#
  #---------------------------------------------------------------------------------------------------------------------# 
  
  # Use MCFLIRT to estimate 6 realignment parameters (RP)
  # and correct distorted functional image for motion artefacts
  mcflirt -in epi -out epi_mcf -mats -plots -reffile \
  example_func_distorted -rmsrel -rmsabs -spline_final
  
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
  
  # Apply transformations estimated with epi_reg to obtain
  # the fieldmap brain mask in the undistorted example_func space
  applywarp -i FM_U_fmap_mag_brain_mask -r example_func --rel --premat=unwarp/FM_U_fmap_mag_brain2highres.mat --postmat=unwarp/highres2example_func.mat -o EF_U_fmap_mag_brain_mask --paddingsize=1
  
  # Concatenate all 6 estimated realignment parameters in epi_mcf.cat
  cat mc/epi_mcf.mat/MAT* > mc/epi_mcf.cat 
    
#  # Replace prefix epi_mcf for prefiltered_func_data_mcf
#  cd mc
#  for file in epi_mcf*
#    do mv "$file" "prefiltered_func_data_mcf${file#epi_mcf}"
#  done
#  cd ..
  
  # Copy realignment parameters to main subject's directory and reshape it 
  cp mc/epi_mcf.par prefiltered_func_data_mcf.par
  mv prefiltered_func_data_mcf.par prefiltered_func_data_mcf.txt
  
  #awk '{print $1}' prefiltered_func_data_mcf.txt >> rp_1.txt;awk '{print $2}' prefiltered_func_data_mcf.txt >> rp_2.txt
  #awk '{print $3}' prefiltered_func_data_mcf.txt >> rp_3.txt;awk '{print $4}' prefiltered_func_data_mcf.txt >> rp_4.txt
  #awk '{print $5}' prefiltered_func_data_mcf.txt >> rp_5.txt;awk '{print $6}' prefiltered_func_data_mcf.txt >> rp_6.txt 
  #rm prefiltered_func_data_mcf.txt; paste rp* | column -s $'\t' -t >> prefiltered_func_data_mcf.txt; rm rp*

  
  #-------------------------------- Unwarp 4D EPI data: motion + distortion correction ---------------------------------#
  #---------------------------------------------------------------------------------------------------------------------# 
  
  # Finally, apply warp to epi data, using as reference undistorted example_func
  # STEP 1 - epi_mcf.cat - linear spatial transformation for motion correction from realignment parameters
  # STEP 2 - example_func2highres_warp - warp coefficients from distorted func space to strucutral space
  # STEP 3 - highres2example_func.mat -  spatial transformation from structural space to undistorted func space
  applywarp -i epi -r example_func -o epi_unwarp --premat=mc/epi_mcf.cat -w unwarp/example_func2highres_warp --postmat=unwarp/highres2example_func.mat --rel --interp=spline --paddingsize=1
  
  
  #----------------------------- Brain extraction of 4D data and processing of brain mask  -----------------------------#
  #---------------------------------------------------------------------------------------------------------------------# 
  
  # Extract temporal average of 4D data 
  fslmaths epi_unwarp -Tmean mean_func
  
  # Perform brain extraction on averaged 4D (now 3D) data and create brain mask (mask)
  bet2 mean_func mask -f 0.3 -n -m; immv mask_mask mask
  
  # Create skull-stripped time-series (epi_bet) with mask
  fslmaths epi_unwarp -mas mask epi_bet
  
  # Threshold skull-stripped time-series (epi_bet) to remove values with very low
  # intensity (lower than 1/10 its 98th percentile) and obtain a final mask
  percentile=`fslstats 'epi_bet' -p 98`; thresh=`expr ${percentile%.*} / 10`
  
  # Thresh is the brain/background threshold for the final mask 
  fslmaths epi_bet -thr $thresh -Tmin -bin mask -odt char 
  fslmaths mask -dilF mask 
  
  # Mask 4D data with thresholded brain mask to obtain
  # final skull-stripped time-series (epi_thresh)
  fslmaths epi_unwarp -mas mask epi_thresh
  
  
  #------------------------------------------ Identify Motion Outliers in 4D data --------------------------------------#
  #---------------------------------------------------------------------------------------------------------------------# 
  
  # Use the skull-stripped time-series as input to identify outliers 
  fsl_motion_outliers -i epi_thresh -o "mo_confound_${mo_metric}.txt" --"$mo_metric" --nomoco -m mask -s mc/"${mo_metric}.txt" -p mc/"$mo_metric"

  
  #----------------------------------------- Apply temporal filter to 4D EPI data --------------------------------------#
  #---------------------------------------------------------------------------------------------------------------------# 
  
  # Intensity normalization to ensure that final data has median ~ 10 000
  median=`fslstats 'epi_unwarp' -k 'mask' -p 50`; fac=`expr 10000 / ${median%.*}`
  fslmaths epi_thresh -mul $fac epi_intnorm
  
  # Apply high-pass temporal filter to functional data 
  hp_sigma=$(echo "1 / (2 * $TR * $hp_freq)" | bc -l)
  fslmaths epi_intnorm -Tmean tempMean
  fslmaths epi_intnorm -bptf $hp_sigma -1 -add tempMean epi_tempfilt
  imrm tempMean
  
  # Prepare final outputs - filtered_func_data(_nofilt)
  fslmaths epi_tempfilt filtered_func_data
  fslmaths filtered_func_data -Tmean mean_func
  mv epi_intnorm* filtered_func_data_nofilt.nii.gz; rm epi*
