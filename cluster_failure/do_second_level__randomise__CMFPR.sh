#!/bin/bash

[[ -e ${ResultsDirectory}/all_subjects_CMFPR.nii.gz ]] && rm "${ResultsDirectory}/all_subjects_CMFPR.nii.gz"

fslmerge -t ${ResultsDirectory}/all_subjects_CMFPR.nii.gz ${Betas_allSubs_nii[@]}   \
    &>> $ResultsDirectory/tmp.txt

randomise -i ${ResultsDirectory}/all_subjects_CMFPR.nii.gz -d ${dmat} -t ${con} \
    -m $ResultsDirectory/group_mask.nii.gz -n 1 ${RandomiseOptions_NoThresholds} \
    -o $ResultsDirectory/${this_perm}${Effect}_CMFPR >> ${ResultsDirectory}/tmp.txt

