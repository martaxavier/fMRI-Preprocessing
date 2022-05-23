%This script receives single_subj_IC x RSN dice coefficient matrices for each pipeline in txt files. 
%Such files should be named "dice_ic_<pipeline_name>_<subject_nr>.txt". 
%The script outputs the following: 
%   A. One plot per subject and pipeline, showing the dice coefficient per IC, grouped by
%   template RSN (Yeo's 2011);
%   B. A plot showing the maximum dice coefficient values obtained for each
%   pipeline, grouped by template RSN (Yeo's 2011) and per subject;

cleanup_list = {'basic','preprocessed','ica_mo_reg','ica_mo_csf_reg','ica_mo_csf_wm_reg'};
%subj_list = {'00000','00001','00002','00003','00004','00005','00006','00007','00008','00009','00010','00011','00012','00013','00014','00015','00016','00017','00018','00019','00020','00021'};
%NOTE: This subject list does not correspond to the subject's code in the
%mig_n2treat because it's according to dual regression output. Subject
%00000 corresponds to the 1st line in file "input_list", subject 00001
%corresponds to the 2nd line, etc...therefore we create a vector for the
%subjects' legend
subj_list = {'00002'};
subj_list_legend=table2array(readtable('input_list.txt'));
group_IC_max=load('Max_GroupICs.mat');
normalized_prctile_vector=[];
distance_prctile_to_max_all=[];
nr_FP_all=[];


% Define the auxiliary variables for the histogram plots
position=1;
nbins=5;

% Define the x labels for the plots
X = categorical({'Visual','Somatomotor','Dorsal Attention','Ventral Attention', 'Limbic', 'Frontoparietal', 'DMN'});
X = reordercats(X,{'Visual','Somatomotor','Dorsal Attention','Ventral Attention', 'Limbic', 'Frontoparietal', 'DMN'});


  for i=1:size(cleanup_list,2)
      
      max_matrix_name=string(strcat('Max_all_', cleanup_list(1,i)));
      %assignin('base',max_matrix_name,[]);
      Max_all=[];
      
      for j=1:size(subj_list,2)

        % ------ Read the txt file into an array
        txt_file=strcat('Dice_ic_', cleanup_list(1,i), '_', subj_list(1,j), '.txt');
        dice_ic_table = readtable(string(txt_file));
        dice_ic_array=table2array(dice_ic_table);
        dice_ic_array_name=string(strcat('Dice_ic_', cleanup_list(1,i),'_', subj_list(1,j)));
        assignin('base',dice_ic_array_name,table2array(dice_ic_table));
        
        % ------ Compute the max coefficients for each RSN
        %Get the maximum value of each RSN (column) and the IC it corresponds to.
        [max_vector,IC]=max(dice_ic_array,[],1);
        %Add one row per pipeline in the "all" file
        Max_all = [Max_all ; max_vector];
        assignin('base',max_matrix_name, Max_all);
        
        % ----- SPECIFICITY MEASURES (D)
        
        % MEASURE 1
        % Compute the distance from the 80th percentile and the max
        %Get the 80th percentile of dice coefficients of each RSN (column).
%         prctile_X = prctile(dice_ic_array,95);
%         distance_prctile_to_max_vector=max_vector-prctile_X;
%         %Add one row per pipeline in the "all" file
%         distance_prctile_to_max_all=[distance_prctile_to_max_all;distance_prctile_to_max_vector];
        
        % MEASURE 2
        % Consider the dice coefficients above 70% of the maximum as false
        % positives and compute the number of false positives
%         FP_threshold=0.7*max_vector;
%         nr_FP_vector=sum(dice_ic_array>=FP_threshold)-1;
%         nr_FP_all=[nr_FP_all;nr_FP_vector];
 
        
        % ---- Bar plots with all dice coefficients, per IC and per subject (A)
        figure()
        b=bar(X,dice_ic_array);
        hold on;
        ylim([0 1]);
        xlabel('RSN templates from Yeo');
        ylabel('Dice coefficient');
        title (strcat(strrep(cleanup_list(1,i),'_',' '),' - subject ',strrep(subj_list(1,j),'_',' '),' - Dice coefficients per network'))
    
       % ---- Histogram with the distributions of dice coefficient values,
       % for each pipeline and for each RSN (C)
        
%         for rsn=1:size(dice_ic_array,2)
%         subplot(size(cleanup_list,2),size(X,2),position)
%         histogram(dice_ic_array(:,rsn),nbins);
%         xlim([0,max(dice_ic_array(:,rsn))])
%         title(X(1,rsn))
%         xlabel ('Dice coeff.');
%         ylabel ('Nr. ICs');
%         position=position+1;
%         end
        
      end %subjects
      
      assignin('base',max_matrix_name, Max_all);
      
        % ----- Draw the max bar plot (B)
%         figure();
%         bar(X,Max_all);
%         ylim([0 1]);
%         xlabel('RSN templates from Yeo');
%         ylabel('Dice coefficient'); 
%         hold on;
%         scatter([1 2 3 4 5 6 7],group_IC_max.Max_all(i,:),'r','filled'); % Mark the group IC's max
%         leg=strrep(subj_list_legend,'_',' ');
%         legend(leg)
%         title (strcat('Maximum dice coefficients - ', strrep(cleanup_list(1,i),'_',' ')))
      
  end %cleanups
  
%   % ----- Draw the max bar plot (B)
%         figure();
%         bar(X,Max_all);
%         ylim([0 1]);
%         xlabel('RSN templates from Yeo');
%         ylabel('Dice coefficient'); 
%         leg=strrep(cleanup_list,'_',' ');
%         legend(leg)
%         title ('Maximum dice coefficients')
%         
%         
% % ----- 2. Draw the specificity plot, based on Measure 1 (D)
%         figure();
%         bar(X,distance_prctile_to_max_all);
%         ylim([0 1]);
%         xlabel('RSN templates from Yeo');
%         ylabel('Distance from percentile to max'); 
%         leg=strrep(cleanup_list,'_',' ');
%         legend(leg)
%         title ('Specificity - Measure 1')
%         
% % ----- 2. Draw the specificity plot, based on Measure 2 (D)
%         figure();
%         bar(X,nr_FP_all);
%         xlabel('RSN templates from Yeo');
%         ylabel('Number of ICs with dice coeff higher than 0.8Max'); 
%         leg=strrep(cleanup_list,'_',' ');
%         legend(leg)
%         title ('Specificity - Measure 2')
%         
%                              