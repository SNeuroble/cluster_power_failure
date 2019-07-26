#!/bin/bash
###################################################################### 
#
# This script is part of the Cluster Power Failure project 
#
# Details: Runs second level nonparametric inference
# Usage: Called from run_hcp_cluster_failure.sh
# Note: Check memory requirements for large datasets
#
#########################################################################################

############# SETUP ############# 

# Create lists of subject files
SubjectBetas=()
SubjectMasks=()

for ((subject=1; subject<=$nSubs_subset; subject++)); do
    subID=$(sed "${subject}q;d" $subNames_subset)
    SubjectBetas[$subject]="${dataDir_localRepository_lowerLevel}/${subID}_cope${copeNum}.feat/stats/cope1.nii.gz"
    SubjectMasks[$subject]="${dataDir_localRepository_lowerLevel}/${subID}_cope${copeNum}.feat/stats/mask.nii.gz"
done

# Concatenate first-level statistics
fslmerge -t ${permOutputsDir}/all_subjects.nii.gz ${SubjectBetas[@]}

# Make group mask
if [[ -f ${permOutputsDir}/group_mask.nii.gz ]]; then
    rm ${permOutputsDir}/group_mask.nii.gz
fi

3dMean -prefix ${permOutputsDir}/group_mask.nii.gz     \
    -mask_inter ${SubjectMasks[@]}                 \
    &> ${templogfile}


############# ANALYSIS #############

# Run analysis with randomise (one-sample -> no need for design/contrast - just add "-1" flag)
printf "\n++ Running second level (+/- contrast).\n"

randomise -i ${permOutputsDir}/all_subjects.nii.gz -m ${permOutputsDir}/group_mask.nii.gz -n ${nPerms_forRandomise} ${RandomiseOptions_WithThresholds} -o ${permOutputsDir}/${processedSuffix}_Pos \
    >> ${templogfile}

# Run analysis for negative contrast
fslmaths ${permOutputsDir}/all_subjects.nii.gz -mul -1 ${permOutputsDir}/all_subjects_Neg.nii.gz 

randomise -i ${permOutputsDir}/all_subjects_Neg.nii.gz -m ${permOutputsDir}/group_mask.nii.gz -n ${nPerms_forRandomise} ${RandomiseOptions_WithThresholds} -o ${permOutputsDir}/${processedSuffix}_Neg \
    >> ${templogfile}


printf "Done second level.\n"

