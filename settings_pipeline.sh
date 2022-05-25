#!/bin/bash

# This script assigns, for each pipeline, flag values and input functional data

# Go through all preprocessing pipelines 

if [[ $cleanup == "nocleanup" ]]; then

  flag_ica_reg=0; flag_icafix=0; flag_nuisance=0; flag_icafix_mc=0; 
  flag_ic=0; flag_wm=0; flag_csf=0; flag_mo=0; flag_rp=0; flag_gs=0; 
  flag_ss=1; flag_hpf=1; flag_rp_exp=0;
  func_data_in="filtered_func_data_notempfilt.nii.gz"
  func_data_final="filtered_func_data_nocleanup_preprocessed"
  mel_dir="mel_nocleanup.ssica"
  gica_dir="mel_nocleanup.gica"
  
elif [[ $cleanup == "icafixrp" ]]; then

  flag_ica_reg=0; flag_icafix=1; flag_nuisance=0; flag_icafixrp=1;
  flag_ic=0; flag_wm=0; flag_csf=0; flag_mo=0; flag_rp=0; flag_gs=0; 
  flag_ss=0; flag_hpf=0; flag_rp_exp=1;
  func_data_in="filtered_func_data.nii.gz"
  func_data_final="filtered_func_data_preprocessed_icafixrp"
  mel_dir="mel_icafixrp.ssica"
  gica_dir="mel_icafixrp.gica"    
  
elif [[ $cleanup == "icafixrp_mo_nui" ]]; then

  flag_ica_reg=0; flag_icafix=1; flag_nuisance=1; flag_icafixrp=1;
  flag_ic=0; flag_wm=0; flag_csf=0; flag_mo=1; flag_rp=0; flag_gs=0; 
  flag_ss=0; flag_hpf=0; flag_rp_exp=1;
  func_data_in="filtered_func_data.nii.gz"
  func_data_final="filtered_func_data_preprocessed_icafixrp_mo_nui"
  mel_dir="mel_all_icafixrp_mo_nui.ssica"
  gica_dir="mel_all_icafixrp_mo_nui.gica"    
 
# previous all_2v 
elif [[ $cleanup == "icafixrp_mo_csf_wm_nui" ]]; then

  flag_ica_reg=0; flag_icafix=1; flag_nuisance=1; flag_icafixrp=1;
  flag_ic=0; flag_wm=1; flag_csf=1; flag_mo=1; flag_rp=0; flag_gs=0; 
  flag_ss=0; flag_hpf=0; flag_rp_exp=1;
  func_data_in="filtered_func_data.nii.gz"
  func_data_final="filtered_func_data_preprocessed_icafixrp_mo_csf_wm_nui"
  mel_dir="mel_all_icafixrp_mo_csf_wm_nui.ssica"
  gica_dir="mel_all_icafixrp_mo_csf_wm_nui.gica"      

# previous all - but alter bc of rp expansions  
elif [[ $cleanup == "icafix_rp_mo_csf_wm_nui" ]]; then

  flag_ica_reg=0; flag_icafix=1; flag_nuisance=1; flag_icafixrp=0; 
  flag_ic=0; flag_wm=1; flag_csf=1; flag_mo=1; flag_rp=1; flag_gs=0; 
  flag_ss=0; flag_hpf=0; flag_rp_exp=1;
  func_data_in="filtered_func_data.nii.gz"
  func_data_final="filtered_func_data_preprocessed_icafix_rp_mo_csf_wm_nui"
  mel_dir="mel_icafix_rp_mo_csf_wm_nui.ssica"
  gica_dir="mel_icafix_rp_mo_csf_wm_nui.gica"
  
elif [[ $cleanup == "ica_rp_mo_csf_wm_nui" ]]; then

  flag_ica_reg=0; flag_icafix=0; flag_nuisance=1; flag_icafixrp=0; 
  flag_ic=1; flag_wm=1; flag_csf=1; flag_mo=1; flag_rp=1; flag_gs=0; 
  flag_ss=0; flag_hpf=0; flag_rp_exp=1;
  func_data_in="filtered_func_data.nii.gz"
  func_data_final="filtered_func_data_preprocessed_ica_rp_mo_csf_wm_nui"
  mel_dir="mel_ica_rp_mo_csf_wm_nui.ssica"
  gica_dir="mel_ica_rp_mo_csf_wm_nui.gica"  
      
elif [[ $cleanup == "ica_rp_reg" ]]; then

  flag_ica_reg=1; flag_icafix=0; flag_nuisance=0; flag_icafixrp=0;
  flag_ic=0; flag_wm=0; flag_csf=0; flag_mo=0; flag_rp=1; flag_gs=0; 
  flag_ss=0; flag_hpf=0; flag_rp_exp=1;
  func_data_in="filtered_func_data.nii.gz"
  func_data_final="filtered_func_data_preprocessed_ica_rp_reg"
  mel_dir="mel_ica_rp_reg.ssica"
  gica_dir="mel_ica_rp_reg.gica"

# previous ica_mo_reg  
elif [[ $cleanup == "ica_rp_mo_reg" ]]; then

  flag_ica_reg=1; flag_icafix=0; flag_nuisance=0; flag_icafixrp=0;
  flag_ic=0; flag_wm=0; flag_csf=0; flag_mo=1; flag_rp=1; flag_gs=0; 
  flag_ss=0; flag_hpf=0; flag_rp_exp=1;
  func_data_in="filtered_func_data.nii.gz"
  func_data_final="filtered_func_data_preprocessed_ica_rp_mo_reg"
  mel_dir="mel_ica_rp_mo_reg.ssica"
  gica_dir="mel_ica_rp_mo_reg.gica"

# previous ica_mo_csf_reg  
elif [[ $cleanup == "ica_rp_mo_csf_reg" ]]; then

  flag_ica_reg=1; flag_icafix=0; flag_nuisance=0; flag_icafixrp=0;
  flag_ic=0; flag_wm=0; flag_csf=1; flag_mo=1; flag_rp=1; flag_gs=0; 
  flag_ss=0; flag_hpf=0; flag_rp_exp=1;
  func_data_in="filtered_func_data.nii.gz"
  func_data_final="filtered_func_data_preprocessed_ica_rp_mo_csf_reg"
  mel_dir="mel_ica_mo_csf_reg.ssica"
  gica_dir="mel_ica_mo_csf_reg.gica"
  
# previous ica_mo_csf_wm_reg   
elif [[ $cleanup == "ica_rp_mo_csf_wm_reg" ]]; then

  flag_ica_reg=1; flag_icafix=0; flag_nuisance=0; flag_icafixrp=0;
  flag_ic=0; flag_wm=1; flag_csf=1; flag_mo=1; flag_rp=1; flag_gs=0; 
  flag_ss=0; flag_hpf=0; flag_rp_exp=1;
  func_data_in="filtered_func_data.nii.gz"
  func_data_final="filtered_func_data_preprocessed_ica_mo_csf_wm_reg"
  mel_dir="mel_ica_mo_csf_wm_reg.ssica"
  gica_dir="mel_ica_mo_csf_wm_reg.gica"  
    
fi

# Write variables in temporary file 
echo ${flag_ica_reg} >> $tmpdir/flag_ica_reg.txt
echo ${flag_icafix} >> $tmpdir/flag_icafix.txt
echo ${flag_nuisance} >> $tmpdir/flag_nuisance.txt
echo ${flag_icafixrp} >> $tmpdir/flag_icafixrp.txt
echo ${flag_csf} >> $tmpdir/flag_csf.txt
echo ${flag_wm} >> $tmpdir/flag_wm.txt
echo ${flag_mo} >> $tmpdir/flag_mo.txt
echo ${flag_rp} >> $tmpdir/flag_rp.txt
echo ${flag_rp_exp} >> $tmpdir/flag_rp_exp.txt
echo ${flag_ic} >> $tmpdir/flag_ic.txt 
echo ${flag_hpf} >> $tmpdir/flag_hpf.txt
echo ${flag_ss} >> $tmpdir/flag_ss.txt
echo ${func_data_in} >> $tmpdir/func_data_in.txt
echo ${func_data_final} >> $tmpdir/func_data_final.txt 
echo ${mel_dir} >> $tmpdir/mel_dir.txt
echo ${gica_dir} >> $tmpdir/gica_dir.txt; 
