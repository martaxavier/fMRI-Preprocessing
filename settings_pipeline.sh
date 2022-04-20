#!/bin/bash

# This script assigns, for each pipeline, flag values and input functional data

# Go through all preprocessing pipelines 
if [[ $cleanup == "all" ]]; then

  flag_ica_reg=0; flag_icafix=1; flag_nuisance=1; flag_wm=1; flag_csf=1;
  flag_mo=1; flag_rp=1;flag_gs=0; flag_ss=0; flag_hpf=0; 
  func_data_in="filtered_func_data.nii.gz"
  func_data_final="filtered_func_data_preprocessed"
  mel_dir="mel_all.ssica"
  gica_dir="mel_all.gica"
   
elif [[ $cleanup == "all_gs" ]]; then
  
  flag_ica_reg=0; flag_icafix=1; flag_nuisance=1; flag_wm=1; flag_csf=1;
  flag_mo=1; flag_rp=1; flag_gs=1; flag_ss=0; flag_hpf=0;
  func_data_in="filtered_func_data.nii.gz"
  func_data_final="filtered_func_data_preprocessed_gs"
  mel_dir="mel_all_gs.ssica"
  gica_dir="mel_all_gs.gica"
    
elif [[ $cleanup == "nocleanup" ]]; then

  flag_ica_reg=0; flag_icafix=0; flag_nuisance=0; flag_wm=0; flag_csf=0;
  flag_mo=0; flag_rp=0; flag_gs=0; flag_ss=1; flag_hpf=1;
  func_data_in="filtered_func_data_nofilt.nii.gz"
  func_data_final="filtered_func_data_nocleanup_preprocessed"
  mel_dir="mel_nocleanup.ssica"
  gica_dir="mel_nocleanup.gica"
  
elif [[ $cleanup == "ica_mo_reg" ]]; then

  flag_ica_reg=1; flag_icafix=0; flag_nuisance=0; 
  flag_wm=0; flag_csf=0; flag_mo=1; flag_rp=1; flag_gs=0; 
  flag_ss=1; flag_hpf=0; flag_rp_exp=1;
  func_data_in="filtered_func_data.nii.gz"
  func_data_final="filtered_func_data_preprocessed_ica_mo_reg"
  mel_dir="mel_ica_mo_reg.ssica"
  gica_dir="mel_ica_mo_reg.gica"
  
elif [[ $cleanup == "ica_mo_csf_reg" ]]; then

  flag_ica_reg=1; flag_icafix=0; flag_nuisance=0; 
  flag_wm=0; flag_csf=1; flag_mo=1; flag_rp=1; flag_gs=0; 
  flag_ss=1; flag_hpf=0; flag_rp_exp=1;
  func_data_in="filtered_func_data.nii.gz"
  func_data_final="filtered_func_data_preprocessed_ica_mo_csf_reg"
  mel_dir="mel_ica_mo_csf_reg.ssica"
  gica_dir="mel_ica_mo_csf_reg.gica"
  
elif [[ $cleanup == "ica_mo_csf_wm_reg" ]]; then

  flag_ica_reg=1; flag_icafix=0; flag_nuisance=0; 
  flag_wm=1; flag_csf=1; flag_mo=1; flag_rp=1; flag_gs=0; 
  flag_ss=1; flag_hpf=0; flag_rp_exp=1;
  func_data_in="filtered_func_data.nii.gz"
  func_data_final="filtered_func_data_preprocessed_ica_mo_csf_wm_reg"
  mel_dir="mel_ica_mo_csf_wm_reg.ssica"
  gica_dir="mel_ica_mo_csf_wm_reg.gica"
  
elif [[ $cleanup == "ica_mo_csf_wm_gs_reg" ]]; then

  flag_ica_reg=1; flag_icafix=0; flag_nuisance=0; 
  flag_wm=1; flag_csf=1; flag_mo=1; flag_rp=1; flag_gs=1; 
  flag_ss=1; flag_hpf=0; flag_rp_exp=1;
  func_data_in="filtered_func_data.nii.gz"
  func_data_final="filtered_func_data_preprocessed_ica_mo_csf_wm_reg"
  mel_dir="mel_ica_mo_csf_wm_reg.ssica"
  gica_dir="mel_ica_mo_csf_wm_reg.gica"  
    
fi

# Write variables in temporary file 
echo ${flag_ica_reg} >> $tmpdir/flag_ica_reg.txt
echo ${flag_icafix} >> $tmpdir/flag_icafix.txt
echo ${flag_nuisance} >> $tmpdir/flag_nuisance.txt
echo ${flag_csf} >> $tmpdir/flag_csf.txt
echo ${flag_wm} >> $tmpdir/flag_wm.txt
echo ${flag_mo} >> $tmpdir/flag_mo.txt
echo ${flag_rp} >> $tmpdir/flag_rp.txt
echo ${flag_rp_exp} >> $tmpdir/flag_rp_exp.txt
echo ${flag_gs} >> $tmpdir/flag_gs.txt 
echo ${flag_hpf} >> $tmpdir/flag_hpf.txt
echo ${flag_ss} >> $tmpdir/flag_ss.txt
echo ${func_data_in} >> $tmpdir/func_data_in.txt
echo ${func_data_final} >> $tmpdir/func_data_final.txt 
echo ${mel_dir} >> $tmpdir/mel_dir.txt
echo ${gica_dir} >> $tmpdir/gica_dir.txt; 