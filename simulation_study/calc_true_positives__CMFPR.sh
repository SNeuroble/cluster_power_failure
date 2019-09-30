#!/bin/bash
# Check whether there's a FP activation underlying a TP detected effect 

if [ -f $ResultsDirectory/tmp_masked_CMFPR.nii.gz ]; then
    rm $ResultsDirectory/tmp_masked_CMFPR.nii.gz
fi

##### Get FWE-corr maps
if [ "$doTFCE" = false ]; then
    # Apply voxelwise CDTp threshold; get all clusters
    cluster -i $ResultsDirectory/${this_perm}${Effect}_CMFPR_${UncorrectedTstat}.nii.gz -t ${one_minus_CDTp_liberal} -o $ResultsDirectory/${this_perm}${Effect}_CMFPR_cluster_index.nii.gz --osize=$ResultsDirectory/${this_perm}${Effect}_CMFPR_cluster_size > $ResultsDirectory/CMFPR_cluster_info.txt

    # Apply cluster size threshold (previously calculated to control FWER)
    fslmaths $ResultsDirectory/${this_perm}${Effect}_CMFPR_cluster_size.nii.gz -thr ${FWEcorrThreshold} -bin $ResultsDirectory/${this_perm}${Effect}_CMFPR_${ClusterTstat}_manual.nii.gz

else
    # Apply TFCE threshold (previously calculated to control FWER)
    fslmaths $ResultsDirectory/${this_perm}${Effect}_CMFPR_${UncorrectedTstat}.nii.gz -thr ${FWEcorrThreshold} -bin $ResultsDirectory/${this_perm}${Effect}_CMFPR_${ClusterTstat}_manual.nii.gz

fi

# If no clusters, create empty image
if [ ! -f $ResultsDirectory/${this_perm}${Effect}_CMFPR_${ClusterTstat}_manual.nii.gz ]; then
    cp $ResultsDirectory/emptyimg.nii.gz $ResultsDirectory/${this_perm}${Effect}_CMFPR_${ClusterTstat}_manual.nii.gz
fi

# Mask cluster image to get FP clusters in activation location
3dcalc -prefix $ResultsDirectory/tmp_masked_CMFPR.nii.gz                                                  \
    -a $ResultsDirectory/${this_perm}${Effect}_CMFPR_${ClusterTstat}_manual.nii.gz               \
    -expr "step(a*step($radius_sq-(i-$ivox)*(i-$ivox)-(j-$jvox)*(j-$jvox)-(k-$kvox)*(k-$kvox)))"    \
    &>> $ResultsDirectory/tmp.txt

#### Check whether any significant FWE-corr voxels
text=$(fslstats $ResultsDirectory/tmp_masked_CMFPR.nii.gz -R)
temp=${text[$((0))]}
values=()
values+=($temp)
anyclusters_CMFPR=${values[$((1))]:0:1}

# Add clusters to running summary of all perms
if [ ! -f $ResultsDirectory/tmp_masked_CMFPR.nii.gz ]; then
    cp $ResultsDirectory/emptyimg.nii.gz $ResultsDirectory/tmp_masked_CMFPR.nii.gz
fi

3dcalc -prefix $ResultsDirectory/tmp2_CMFPR.nii.gz -a $ResultsDirectory/tmp_masked_CMFPR.nii.gz -b $ResultsDirectory/all_clusters${Effect}_CMFPR.nii.gz -expr 'a+b' \
    &>> $ResultsDirectory/tmp.txt

if [[ -f $ResultsDirectory/all_clusters${Effect}_CMFPR.nii.gz && -f $ResultsDirectory/tmp2_CMFPR.nii.gz ]]; then
    rm $ResultsDirectory/all_clusters${Effect}_CMFPR.nii.gz
    mv $ResultsDirectory/tmp2_CMFPR.nii.gz $ResultsDirectory/all_clusters${Effect}_CMFPR.nii.gz
fi


