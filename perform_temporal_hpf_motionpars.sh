#!/bin/bash

#This script performs temporal high-pass filtering of the input regressors

# Create unique directory for temporary files 
if find ${path}tmp -mindepth 1 -maxdepth 1 | read; then rm ${path}tmp/*; fi
tmpdir=$path/tmp

# define exit trap
#trap "rm -f $tmpdir/* ; rmdir $tmpdir ; exit" EXIT

# Count number of columns in the data
n_cols=$(awk '{print NF}' $data | sort -nu | head -n 1)

# Count number of time-points 
n_rows=$(cat $data | wc -l)

# transpose input to please fslascii2img
$path/transptxt.sh $data $tmpdir/data_transp

# create pseudoimage
fslascii2img $tmpdir/data_transp $n_cols 1 1 $n_rows 1 1 1 $TR $tmpdir/data.nii.gz

# hpf pseudoimage
fslmaths $tmpdir/data.nii.gz -Tmean tempMean
hp_sigma=$(echo "1 / (2 * $TR * $hp_freq)" | bc -l)
fslmaths $tmpdir/data.nii.gz -bptf $hp_sigma -1 -add tempMean $tmpdir/data_hpf.nii.gz
rm tempMean*

# convert to ascii
fsl2ascii $tmpdir/data_hpf.nii.gz $tmpdir/data_hpf

# concatenate ascii
cat $tmpdir/data_hpf????? | sed '/^\s*$/d' > $data_out

rm $tmpdir/*


