#!/bin/bash

# This script assigns, for each pipeline, flag values and input functional data

# Go through all preprocessing pipelines 
if [[ $dataset == "MIGN2TREAT" ]]; then

  TR=1.26                  # seconds 
  echo_spacing=0.00031     # seconds 
  hp_freq=0.01             # Hz
  fwhm=3.3                 # FWHM, mm  
  pe_dir="y-"              # phase encoding direction 
  fix_thr="20"             # fix noise/signal threshold 
  fix_train_data="WhII_MB6.RData"        # fix dataset
  fix_txt_out="fix4melview_WhII_MB6_thr20.txt"           # fix output file 
  anat_data_raw=_MPRAGE.nii.gz         
  func_data_raw=${run}_${task}_acq-ep2d_p2_s3_bold.nii
  
  # Subjects
  #subj_list=("sub-control019" "sub-control020" "sub-control025" "sub-control026" "sub-control027" "sub-control029" "sub-control030" "sub-control031" "sub-control033" "sub-control044" "sub-control046")
  subj_list=("sub-control046")

elif [[ $dataset == "PARIS" ]]; then

  TR=2                                         # seconds 
  echo_spacing=""                              # seconds 
  hp_freq=0.01                                 # Hz 
  fwhm=4                                       # FWHM, mm 
  fix_thr="20"                                 # fix noise/signal threshold 
  fix_train_data=Standard.RData.txt            # fix training dataset
  fix_txt_out=fix4melview_Standard_thr20.txt   # fix output file  
  anat_data_raw=T1
  func_data_raw=${task}_${run}_bold.nii.gz
  
  # Subjects
  subj_list=("sub-04")
  #subj_list=("sub-05" "sub-06" "sub-07" "sub-08" "sub-09" "sub-10" "sub-11" "sub-12" "sub-13" "sub-14" "sub-15" "sub-16" "sub-17" "sub-19" "sub-20" "sub-21" "sub-22" "sub-23" "sub-24" "sub-25" "sub-27" "sub-29") 

elif [[ $dataset == "NODDI" ]]; then

  TR=2.16                                        # seconds
  echo_spacing=""                                # seconds  
  hp_freq=0.01                                   # Hz 
  fwhm=5                                         # FWHM, mm 
  fix_thr="20"                                   # fix noise/signal threshold 
  fix_train_data=Standard.RData.txt              # fix training dataset
  fix_txt_out=fix4melview_Standard_thr20.txt     # fix output file  
  anat_data_raw=T1
  func_data_raw=${task}_epi.nii.gz
    
  # Subjects 
  subj_list=("sub-32" "sub-35" "sub-36" "sub-37" "sub-38" "sub-39" "sub-40" "sub-42" "sub-43" "sub-44" "sub-45" "sub-46" "sub-47" "sub-48" "sub-49" "sub-50")

elif [[ $dataset == "CIBM" ]]; then

  TR=1                       # seconds 
  echo_spacing=""            # seconds 
  hp_freq=""                 # Hz 
  fwhm=""                    # FWHM, mm 
  fix_thr=""                 # fix noise/signal threshold 
  fix_train_data=""          # fix training dataset
  fix_txt_out=""             # fix output file 
  anat_data_raw=MP2RAGE
  func_data_raw=""
  
  # Subjects
  subj_list=("sub-01" "sub-03" "sub-05" "sub-06" "sub-07" "sub-09" "sub-10" "sub-11" "sub-12")

fi

echo ${TR} >> $tmpdir/TR.txt
echo ${echo_spacing} >> $tmpdir/echo_spacing.txt
echo ${hp_freq} >> $tmpdir/hp_freq.txt
echo ${fwhm} >> $tmpdir/fwhm.txt
echo ${fix_thr} >> $tmpdir/fix_thr.txt
echo ${fix_train_data} >> $tmpdir/fix_train_data.txt
echo ${fix_txt_out} >> $tmpdir/fix_txt_out.txt
echo ${func_data_raw} >> $tmpdir/func_data_raw.txt
echo ${anat_data_raw} >> $tmpdir/anat_data_raw.txt
echo ${subj_list} >> $tmpdir/subj_list.txt
