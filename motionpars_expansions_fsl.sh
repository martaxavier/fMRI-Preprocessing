#!/bin/bash

# This script computes the time-series expansions of the realignment parameters 

# Create unique directory for temporary files 
rm $path/tmp/*
tmpdir=$path/tmp

# Define exit trap
#trap "rm -f $tmpdir/* ; rmdir $tmpdir ; exit" EXIT

# Count number of columns in the data
n_cols=$(awk '{print NF}' $data | sort -nu | head -n 1)

# Count number of time-points 
n_rows=$(cat $data | wc -l)

# Transpose input to please fslascii2img
$path/transptxt.sh $data $tmpdir/data_transp

# Create pseudoimage - RPs 
fslascii2img $tmpdir/data_transp $n_cols 1 1 $n_rows 1 1 1 $TR $tmpdir/data.nii.gz

# Quadratic term of RPs 
fslmaths $tmpdir/data.nii.gz -sqr $tmpdir/data_quad.nii.gz

# Derivative of RPs
# Circular shift
fslsplit $tmpdir/data.nii.gz $tmpdir/tmp
n_vols=$(fslval $tmpdir/data dim4) 
n_vols=$(echo "$n_vols -1" | bc -l)

declare -a tmp_list=()
c=0
while [ $c -le $n_vols ]; do
  if [[ $c -eq n_vols ]]; then
    tmp_list=( "0${c}" "${tmp_list[@]}" ) 
    tmp_list[0]="tmp${tmp_list[0]}"
    break
  elif [[ $c -le 9 ]]; then
    tmp_list=( "${tmp_list[@]}" "000${c}" ) 
  elif [[ $c -le 99 ]]; then
    tmp_list=( "${tmp_list[@]}" "00${c}" ) 
  elif [[ $c -le 999 ]]; then
    tmp_list=( "${tmp_list[@]}" "0${c}" ) 
  fi
  tmp_list[c]="tmp${tmp_list[c]}"
  c=$(echo "$c + 1" | bc -l)
done

fslmerge -t $tmpdir/data_shift.nii.gz $tmpdir/$tmp_list; rm $tmpdir/tmp* 
fslmaths $tmpdir/data.nii.gz -sub $tmpdir/data_shift.nii.gz $tmpdir/data_der.nii.gz

# Quadratic term of the derivative of RPs
fslmaths $tmpdir/data_der.nii.gz -sqr $tmpdir/data_der_quad.nii.gz

# Convert to ascii
fsl2ascii $tmpdir/data.nii.gz $tmpdir/data
fsl2ascii $tmpdir/data_quad.nii.gz $tmpdir/data_quad
fsl2ascii $tmpdir/data_der.nii.gz $tmpdir/data_der
fsl2ascii $tmpdir/data_der_quad.nii.gz $tmpdir/data_der_quad

# Concatenate ascii
rm $tmpdir/data.nii.gz $tmpdir/data_quad.nii.gz $tmpdir/data_der.nii.gz $tmpdir/data_der_quad.nii.gz $tmpdir/data_shift.nii.gz $tmpdir/data_transp
cat $tmpdir/data????? | sed '/^\s*$/d' > "$tmpdir/reg_$data_out";
cat $tmpdir/data_quad????? | sed '/^\s*$/d' > "$tmpdir/reg_quad_$data_out"
cat $tmpdir/data_der????? | sed '/^\s*$/d' > "$tmpdir/reg_der_$data_out"
cat $tmpdir/data_der_quad????? | sed '/^\s*$/d' > "$tmpdir/reg_der_quad_$data_out"
paste $tmpdir/reg* | column -s $'\t' -t >> $data_out
rm $tmpdir/*