#!/bin/bash

#This script removes time-series of noise components from the functional data
#
#

if [[ $flag_icafixrp == 1 ]]; then

  # Apply cleanup, using artefacts listed in the .txt file 
	hp_2sigma=$(echo "2 / $hp_freq" | bc -l)
	/usr/local/fix/fix -a mel.ica/$fix_txt_out -m -h $hp_2sigma 
 
 # Copy fix output filtered_func_data_clean to the main directory 
  cp mel.ica/filtered_func_data_clean.nii.gz filtered_func_data_cleanrp.nii.gz 

else

  # Apply cleanup, using artefacts listed in the .txt file 
	/usr/local/fix/fix -a mel.ica/$fix_txt_out
 
  # Copy fix output filtered_func_data_clean to the main directory 
  cp mel.ica/filtered_func_data_clean.nii.gz . 

fi
