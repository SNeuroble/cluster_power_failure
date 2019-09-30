#!/bin/bash
# check memory requirements for large datasets

printf "\n++ Running second level.\n"

# Create lists of subject files
Subjects=()
subjectstring=${Randomized[$((0))]}
Subjects+=($subjectstring)

Masks_allSubs=()
Betas_allSubs=()
Betas_allSubs_nii=()
Betas_allSubs_wNames=()

for i in $(seq 0 $(( NumberOfSubjects - 1 ))); do
    this_sub=${Subjects[$((i))]}
    Masks_allSubs[$i]="${GroupDirectory}/${this_sub}.results/mask_group+tlrc.HEAD"
    Betas_allSubs[$i]="${GroupDirectory}/${this_sub}.results/stats.${this_sub}+tlrc[1]"
    Betas_allSubs_nii[$i]="${GroupDirectory}/${this_sub}.results/stats.${this_sub}.nii.gz"
    Betas_allSubs_wNames[$i]="${this_sub} ${GroupDirectory}/${this_sub}.results/stats.${this_sub}+tlrc[1] "
done

# Make group mask
if [ -f $ResultsDirectory/group_mask.nii.gz ]; then rm $ResultsDirectory/group_mask.nii.gz ; fi

3dMean -prefix $ResultsDirectory/group_mask.nii.gz     \
    -mask_inter ${Masks_allSubs[@]}                 \
    &>> $ResultsDirectory/tmp.txt

# Check if mask created correctly
if [ ! -e $ResultsDirectory/group_mask.nii.gz  ]; then
    echo "Group mask was not created correctly!"
    ((NoGroupMask++))
    echo "Group mask for permutation $this_perm (CM $this_cmID__reffile (line $this_cmID), test $WBtest_number) was not created correctly!" >> $ResultsDirectory/errorlog${Effect}.txt
    exit
fi

# Concatenate first-level statistics
# Add activations for TP
[[ -f ${ResultsDirectory}/all_subjects.nii.gz ]] && rm ${ResultsDirectory}/all_subjects.nii.gz 
if [ "$doTPR" = "true" ]; then
    . $ScriptsDirectory/add_activation.sh
    fslmerge -t ${ResultsDirectory}/all_subjects.nii.gz     \
        ${Betas_Group1_ActivationsAdded[@]} ${Betas_allSubs_nii[@]:${GroupSize}:${GroupSize}} \
        &>> $ResultsDirectory/tmp.txt
else
    fslmerge -t ${ResultsDirectory}/all_subjects.nii.gz     \
        ${Betas_allSubs_nii[@]}             \
        &>> $ResultsDirectory/tmp.txt
fi

# Run randomise
randomise -i ${ResultsDirectory}/all_subjects.nii.gz -d ${dmat} -t ${con} \
    -m $ResultsDirectory/group_mask.nii.gz -n ${nperms_forRandomise} \
    ${RandomiseOptions_WithThresholds} -o $ResultsDirectory/${this_perm}${Effect} \
    > ${ResultsDirectory}/clusterthreshold.txt

# NOTE: this output differs from saved file in this version fsl
FWEcorrThreshold=$(grep -i "tstat1 is:" ${ResultsDirectory}/clusterthreshold.txt | sed "s/\(.*\)tstat1 is: \(.*\)/\2/")


 

######## If TP, also run tests without activation added (-> FP rate in activation location)
# only using rand to run second level, NOT to cluster - clustering later w above FWEcorrThreshold
if [ "$doTPR" = "true" ]; then
    . $ScriptsDirectory/do_second_level__randomise__CMFPR.sh
fi


printf "Done second level.\n"

