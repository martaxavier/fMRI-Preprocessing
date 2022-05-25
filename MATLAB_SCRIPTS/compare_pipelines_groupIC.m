%This script receives IC x RSN dice coefficient matrices for each pipeline in txt filess. 
%Such files should be named "dice_ic_<pipeline_name>_<subject_type>.txt". 
%The script will produce three different plots: 
%1. One plot per pipeline showing the dice coefficient per IC, grouped by
%   template RSN (Yeo's 2011);
%2. A plot showing the maximum dice coefficient values obtained for each
%   pipeline, grouped by template RSN (Yeo's 2011);
%3. One histogram per pipeline and per template RSN showing the
%   distribution of the dice coefficients obtained, in order to assess for
%   the pipeline's specificity.

cleanup_list = {'basic','full_preprocessed','ica_mo_reg','ica_mo_csf_reg','ica_mo_csf_wm_reg'};
subject_type = {'HC'};
Max=[];

% Define the auxiliary variables for the histogram plots
position=1;
nbins=5;

% Define the x labels for the plots
X = categorical({'Visual','Somatomotor','Dorsal Attention','Ventral Attention', 'Limbic', 'Frontoparietal', 'DMN'});
X = reordercats(X,{'Visual','Somatomotor','Dorsal Attention','Ventral Attention', 'Limbic', 'Frontoparietal', 'DMN'});


  for j=1:size(cleanup_list,2)

        %Read the txt file into an array
        txt_file=strcat('Dice_ic_', cleanup_list(1,j), '_', subject_type(1,1), '.txt');
        dice_ic_table = readtable(string(txt_file));
        dice_ic_array=table2array(dice_ic_table);
        
        %Compute the max coefficients for each RSN

        %Get the maximum value of each column and the IC it corresponds to
        [max_vector,IC]=max(dice_ic_array,[],1);
        Max = [Max ; max_vector];
        
       %---- Bar plot with all dice coefficients, per IC
%         figure()
%         b=bar(X,dice_ic_array);
%         ylim([0 1]);
%         xlabel('RSN templates from Yeo');
%         ylabel('Dice coefficient');
%         title (strcat(strrep(cleanup_list(1,j),'_',' '),' - Dice coefficients per network'))
    
       % ---- Histogram with the distributions of dice coefficient values,
       % for each pipeline and for each RSN.
        
        for rsn=1:size(dice_ic_array,2)
        subplot(size(cleanup_list,2),size(X,2),position)
        histogram(dice_ic_array(:,rsn),nbins);
        xlim([0,max(dice_ic_array(:,rsn))])
        title(X(1,rsn))
        xlabel ('Dice coeff.');
        ylabel ('Nr. ICs');
        position=position+1;
        end
        
  end
  
  
%   %Draw the max bar plot
%         figure();
%         bar(X,Max);
%         ylim([0 1]);
%         xlabel('RSN templates from Yeo');
%         ylabel('Dice coefficient'); 
%         leg=strrep(cleanup_list,'_',' ');
%         legend(leg)
%         title ('Maximum dice coefficients')
%         
