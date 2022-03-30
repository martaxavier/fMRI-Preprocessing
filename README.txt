# fMRI-Preprocessing

STEP 1: check settings_dataset.sh to check if dataset specs are ok
STEP 2: open main1.sh and define input dataset, task and run 
STEP 3: run main1.sh
STEP 4: classify unknown components returned by fix and edit .txt in output directory mel.ica
STEP 5: open main2.sh and define input dataset, task, run, cleanup pipeline and registration flag 
STEP 6: run main2.sh
STEP 7: run perform_group_ica.sh (preferable) or perform_singlesession_ica.sh to perform a group ica or subject ica analysis (open first to edit input variables)
STEP 8 (GROUP ICA): open perform_group_ica2.sh and define input reference RSN template + run perform_group_ica2.sh (edit other input variables as well) 
STEP 8 (SUBJECT ICA): open compute_dice.sh and define input reference RSN template + run compute_dice.sh
STEP 9: (GROUP ICA): run extract_rsns_group_features.sh (open first to edit input variables) 
STEP 9: (SUBJECT ICA): run extract_rsns_features.sh (open first to edit input variables) 
