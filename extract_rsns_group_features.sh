#!/bin/bash

path=/home/mxavier/eeg-fmri/
cd $path


#--------------------------------------------- Declare analysis settings ---------------------------------------------# 
#---------------------------------------------------------------------------------------------------------------------# 

# Declare analysis settings 
dataset=PARIS
pe_dir="y-"              # phase encoding direction 
task="task-rest"         # "task-rest" "task-calib"
run="run-3"              # "run-1" "run-2" "run-3"

# Cleanup list: 
cleanup_list=("ica_mo_reg", "ica_mo_csf_reg", "ica_mo_csf_wm_reg")

# Declare reference RSN template ("smith" - Smith, 2009; "yeo" - Yeo, 2011)  
rsn_template = "smith"

# Declare list of rsns
rsn_list=("visual_medial" "visual_lateral" "visual_occipital" "dmn" \
"cerebellum" "motor" "auditory" "executive" "left_fp" "right_fp")

if [[ $pe_dir == y- ]]; then pedir_dir="minusy"; else pedir_dir="plusy"; fi


#---------------------------------------- Read RSNs list from input .txt file ----------------------------------------# 
#---------------------------------------------------------------------------------------------------------------------# 

# Specify which .txt file containing the rsn names is going to be read 
if [ $rsn_template == "smith" ]; then

  input_list="list_smith_rsns.txt"
  
elif [ $rsn_template == "yeo" ]; then

  input_list="list_yeo_rsns.txt"
  
fi

rsn_list=() 
n=1

# Read specified file line by line and 
# add rsn name to variable rsn_list
while read line; do

  new_rsn=$(echo "$line") 
  rsn_list=( "${rsn_list[@]}" $new_rsn )
  n=$((n+1))

done < $input_list


#--------------------------------------------------- Read dataset settings -------------------------------------------# 
#---------------------------------------------------------------------------------------------------------------------# 

# Create unique temporary directory 
tmpdir=$(mktemp -d) 

# Read dataset settings
. settings_dataset.sh
read subj_list < $tmpdir/subj_list.txt 


#------------------------------------------- Go through cleanup pipelines  -------------------------------------------# 
#---------------------------------------------------------------------------------------------------------------------# 

# Iterate through cleanup pipelines 
for cleanup in "${cleanup_list[@]}"; do  

  cd $path 
  
  # Assign flags and inputs for pipeline
  . settings_pipeline.sh
  
  # Read variables created in child process, in temporary directory
  read func_data < $tmpdir/func_data_final.txt
  read gica_dir < $tmpdir/gica_dir.txt;
  func_data_dir=$func_data


#------------------------------------------------ Go through subjects ------------------------------------------------# 
#---------------------------------------------------------------------------------------------------------------------# 
   
 s=0
  
 # Iterate through subjects 
 for i in "${subj_list[@]}"; do  
 
   #-------------------------------------------- Copy results of Group ICA --------------------------------------------# 
   #------------------------------------------------- to subject's dir ------------------------------------------------# 
 
   if [ $s -le 9 ]; then
     sub="0$s"
   else
     sub=$s
   fi
 
   # Change to subjects directory
   cd $path/$dataset/PREPROCESS/
   cp "groupICA.dr/$gica_dir/dr_stage2_subject000${sub}_Z.nii.gz" $i/$task/$pedir_dir/$gica_dir
   cp groupICA.dr/$gica_dir/dr_stage2_subject000${sub}.nii.gz $i/$task/$pedir_dir/$gica_dir
   cp groupICA.dr/$gica_dir/dr_stage1_subject000${sub}.txt $i/$task/$pedir_dir/$gica_dir
   cp groupICA.stats/$gica_dir/"${i}_dice.txt" $i/$task/$pedir_dir/$gica_dir
   
   #------------------------------------------- Extract IC time-course from -------------------------------------------# 
   #------------------------------------------------ dr_stage2 txt file -----------------------------------------------# 
   
   rsn=1 
   
   for j in "${rsn_list[@]}"; do 
   
     rm $i/$task/$pedir_dir/$gica_dir/ic_${j}_group.txt
     
     # Find maximum dice for current network 
     line=$(sed "${rsn}q;d" groupICA.stats/$gica_dir/group_dice.txt)
     max=`echo ${line[@]} | awk -v RS=" " '1'| sort -r | head -1`
     IFS=', ' read -r -a line2 <<< "$line"
     for n in "${!line2[@]}"; do
        if [[ "${line2[$n]}" = "${max}" ]]; then
          maxidx=$n;
        fi
     done 
     
     maxidx=$(echo "$maxidx + 1" | bc -l) 
     awk '{print $'$maxidx'}' groupICA.dr/$gica_dir/dr_stage1_subject000${sub}.txt > $i/$task/$pedir_dir/$gica_dir/ic_${j}_group.txt
   
     # Update rsn number 
     rsn=$(echo "$rsn + 1" | bc -l)
   
   done # RSNs
   
   # Update subject number 
   s=$(echo "$s + 1" | bc -l) 
   
   echo "RSNs extracted for ${i} ..."
 
 done # Subjects 
 
done # Cleanup pipelines 