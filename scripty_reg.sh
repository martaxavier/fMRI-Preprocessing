path=/home/mxavier/eeg-fmri
cd $path

dataset=NODDI
pe_dir="y-"              
task="task-rest"         
run_list=("run-1")
cleanup_list=("ica_mo_csf_wm_reg" "ica_mo_reg" "ica_mo_csf_reg")

if [[ $pe_dir == y- ]]; then pedir_dir="minusy"; else pedir_dir="plusy"; fi

if find ${path}tmp -mindepth 1 -maxdepth 1 | read; then rm ${path}tmp/*; fi
tmpdir=$path/tmp

. settings_dataset.sh
read subj_list < $tmpdir/subj_list.txt

for cleanup in "${cleanup_list[@]}"; do  

  cd $path 
  
  # Assign flags and inputs for pipeline
  . settings_pipeline.sh
  
  # Read variables created in child process, in temporary directory
  read func_data < $tmpdir/func_data_final.txt
  read gica_dir < $tmpdir/gica_dir.txt;

  for run in "${run_list[@]}"; do 
     
      for i in "${subj_list[@]}"; do 

         cd $path/$dataset/PREPROCESS/$task/$i/$run/$pedir_dir

	       imcp $path/$dataset/DERIVATIVES/$i/bet_fast/${i}_T1_crop_restore.nii* highres_head.nii.gz
	       imcp $path/$dataset/DERIVATIVES/$i/bet_fast/${i}_T1_crop_restore_brain.nii* highres.nii.gz
	       cp $path/$dataset/DERIVATIVES/$i/reg/* unwarp
    
         fslmaths /usr/local/fsl/data/standard/MNI152_T1_2mm_brain standard
         fslmaths /usr/local/fsl/data/standard/MNI152_T1_2mm standard_head 
         fslmaths /usr/local/fsl/data/standard/MNI152_T1_2mm_brain_mask_dil standard_mask
    
         applywarp -i highres -r standard -o unwarp/highres2standard -w unwarp/highres2standard_coef 
         convert_xfm -inverse -omat unwarp/standard2highres_aff.mat unwarp/highres2standard_aff.mat
         invwarp --ref=highres --warp=unwarp/highres2standard_coef --out=unwarp/standard2highres_coef  

	       convert_xfm -omat example_func2standard_aff.mat -concat unwarp/highres2standard_aff.mat unwarp/example_func2highres.mat
         convertwarp --ref=standard --premat=unwarp/example_func2highres.mat --warp1=unwarp/highres2standard_coef --out=unwarp/example_func2standard_coef
         applywarp --ref=standard --in=example_func --out=unwarp/example_func2standard --warp=unwarp/example_func2standard_coef
    	   convert_xfm -inverse -omat unwarp/standard2example_func_aff.mat unwarp/example_func2standard_aff.mat
    	   invwarp --ref=highres --warp=unwarp/example_func2standard_coef --out=unwarp/standard2example_func_coef 

         fslroi /usr/local/fsl/data/atlases/HarvardOxford/HarvardOxford-sub-prob-2mm.nii.gz LVentricle 2 1 
         fslroi /usr/local/fsl/data/atlases/HarvardOxford/HarvardOxford-sub-prob-2mm.nii.gz RVentricle 13 1
         fslmaths LVentricle -add RVentricle -thr 0.1 -bin -dilF Ventricle 
         rm LVentricle* RVentricle* 
         applywarp --in=Ventricle --ref=highres --out=H_Ventricle --warp=unwarp/standard2highres_coef
         applywarp --in=Ventricle --ref=example_func --out=EF_Ventricle --warp=unwarp/standard2example_func_coef
    
    	   mv -f standard* example_func2* highres2* standard2* unwarp
         cd unwarp; chmod 777 *; cd ..
	   
	   echo "done for ${i}, ${run}, ${cleanup}"

	done

  done

done


