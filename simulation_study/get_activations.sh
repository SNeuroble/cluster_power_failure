#!/bin/bash

# Check if group results were created correctly
if [ ! -e $ResultsDirectory/${this_perm}${Effect}_${ClusterTstat}.nii.gz   ]; then
    echo "Group analysis was not executed correctly!"
    ((NoGroupAnalysis++))
    echo "Group analysis for permutation $this_perm (CM $this_cmID__reffile (line $this_cmID), test $WBtest_number) was not executed correctly!" >> $ResultsDirectory/errorlog${Effect}.txt
    exit
fi

# Remove any previously found clusters or related masks
[[ -f $ResultsDirectory/tmp_masked.nii.gz ]] && rm $ResultsDirectory/tmp_masked.nii.gz

# Apply FWE-corrected threshold to cluster-wise corrected map
fslmaths $ResultsDirectory/${this_perm}${Effect}_${ClusterTstat}.nii.gz -thr ${FWEthreshold} -bin $ResultsDirectory/${this_perm}${Effect}_clusters.nii.gz

# If no clusters, create empty image
if [ ! -f $ResultsDirectory/${this_perm}${Effect}_clusters.nii.gz ]; then
    cp $ResultsDirectory/emptyimg.nii.gz $ResultsDirectory/${this_perm}${Effect}_clusters.nii.gz
fi


##### Get clusters
if [ "$doTPR" = true ]; then
    echo "Getting stats in original activation location (TP, FP, and ground truth) "
    this_expr="step(a*step($radius_sq-(i-$ivox)*(i-$ivox)-(j-$jvox)*(j-$jvox)-(k-$kvox)*(k-$kvox)))"
else
    echo "Getting false positive clusters."
    this_expr="step(a)"
fi

3dcalc -prefix $ResultsDirectory/tmp_masked.nii.gz                  \
    -a $ResultsDirectory/${this_perm}${Effect}_clusters.nii.gz      \
    -expr "$this_expr"    \
    &>> $ResultsDirectory/tmp.txt

# Check max p-values 
text=$(fslstats $ResultsDirectory/tmp_masked.nii.gz -R)
temp=${text[$((0))]}
values=()
values+=($temp)
anyclusters=${values[$((1))]:0:1}


##### Get other stats: false positive activation in place; ground truth activations
if [ "$doTPR" = true ]; then

    . $ScriptsDirectory/calc_true_positives__CMFPR.sh

    3dcalc -prefix $ResultsDirectory/tmp_groundtruth.nii.gz \
        -a $ResultsDirectory/${this_perm}${Effect}_roiblur+tlrc \
        -b $ResultsDirectory/all_clusters${Effect}_groundtruth.nii.gz -expr 'step(a)+b' \
        &>> $ResultsDirectory/tmp.txt

    if [[ -f $ResultsDirectory/all_clusters${Effect}_groundtruth.nii.gz && -f $ResultsDirectory/tmp_groundtruth.nii.gz ]]; then
        rm $ResultsDirectory/all_clusters${Effect}_groundtruth.nii.gz
        mv $ResultsDirectory/tmp_groundtruth.nii.gz $ResultsDirectory/all_clusters${Effect}_groundtruth.nii.gz
    fi
fi

# Add clusters to running summary of all perms
echo "++ Adding clusters to running summary."
if [ ! -f $ResultsDirectory/tmp_masked.nii.gz ]; then
    cp $ResultsDirectory/emptyimg.nii.gz $ResultsDirectory/tmp_masked.nii.gz
fi


3dcalc -prefix $ResultsDirectory/tmp2.nii.gz -a $ResultsDirectory/tmp_masked.nii.gz -b $ResultsDirectory/all_clusters${Effect}.nii.gz -expr 'a+b' \
    &>> $ResultsDirectory/tmp.txt

if [[ -f $ResultsDirectory/all_clusters${Effect}.nii.gz && -f $ResultsDirectory/tmp2.nii.gz ]]; then
    rm $ResultsDirectory/all_clusters${Effect}.nii.gz
    mv $ResultsDirectory/tmp2.nii.gz $ResultsDirectory/all_clusters${Effect}.nii.gz
fi



