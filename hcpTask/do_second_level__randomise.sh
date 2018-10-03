#!/bin/bash
# check memory requirements for large datasets

printf "\n++ Running second level (+/- contrast).\n"

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


# Run randomise (one sample -> no need for design/contrast - just add "-1" flag)
randomise -i ${permOutputsDir}/all_subjects.nii.gz -m ${permOutputsDir}/group_mask.nii.gz -n ${nPerms_forRandomise} ${RandomiseOptions_WithThresholds} -o ${permOutputsDir}/${processedSuffix}_Pos \
    >> ${templogfile}

# Negative contrast
fslmaths ${permOutputsDir}/all_subjects.nii.gz -mul -1 ${permOutputsDir}/all_subjects_Neg.nii.gz 

randomise -i ${permOutputsDir}/all_subjects_Neg.nii.gz -m ${permOutputsDir}/group_mask.nii.gz -n ${nPerms_forRandomise} ${RandomiseOptions_WithThresholds} -o ${permOutputsDir}/${processedSuffix}_Neg \
    >> ${templogfile}


printf "Done second level.\n"

