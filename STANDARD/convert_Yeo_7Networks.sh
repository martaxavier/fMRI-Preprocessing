#!/bin/bash
#
# Convert Yeo's 7 network file from a 3D image to a binarized 4D image 
# Input is the converted Yeo's 7 network liberal parcellation from FreeSurfer space to FSL MNI 2mm space
# Input nifti is a 3D image with intensities from 1-7, each corresponding to one network
# Output is a 4D binarized image, each volume corresponding to one network 

path=/home/mxavier/eeg-fmri/STANDARD/
input_img=*_7Network*2mm_LiberalMask.nii.gz
output_img=Yeo11_rsn7.nii.gz
cd $path

for i in {2..8}; do 
  
  # Threshold input image 
  thr_1=$i; 
  thr_2=$(echo "$i - 1" | bc -l)
  fslmaths $input_img -thr $thr_1 img_1
  fslmaths $input_img -thr $thr_2 img_2
  fslmaths img_2 -sub img_1 img_3 
  fslmaths img_3 -thr -bin VOL_${i}
  
  # Merge images 
  fslmerge -t $output_img VOL*
  
done

rm img_3* img_1* img_2* 
rm VOL*
