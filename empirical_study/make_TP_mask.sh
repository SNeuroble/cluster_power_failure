#!/bin/bash

mkdir -p $maskDir

for sign in Pos Neg ; do  
    
    groundTruthZstat=${groundTruthZstat_prefix}${groundTruthZstat_suffix}
    groundTruthMask="${groundTruthMask_prefix}${sign}${groundTruthMask_suffix}"

    if [ "$sign" = "Neg" ]; then
        groundTruthZstat_neg=${groundTruthZstat_prefix}_Neg_tmp${groundTruthZstat_suffix}
        fslmaths ${groundTruthZstat} -mul -1 ${groundTruthZstat_neg}
        groundTruthZstat=$groundTruthZstat_neg
    fi
    
    # note: summary consists of header col, IDs in 1st col, and n voxels in 2nd col
    roiMaskSummary=$(cluster -z $groundTruthZstat --zthresh="3.1" -o $groundTruthMask | awk "NR>1" )
    roiIDs=$(echo "$roiMaskSummary" | awk '{print $1}')
   
    # Set up pos and neg vars for use elsewhere
    roiSizes=roiSizes_${sign}
    nRois=nRois_${sign}
    volTP_sum=volTP_${sign}_sum
    binTP_sum=binTP_${sign}_sum
    volTP_mean=volTP_mean_${sign}
    TPR=TPR_${sign}

    declare "$roiSizes=$(echo "$roiMaskSummary" | awk '{print $2}')"
    declare "$nRois=$(echo $roiIDs |  awk '{print $1}' )"
    declare -a "$volTP_sum=( $(for i in $(seq 1 ${!nRois} ); do echo 0; done) )"
    declare -a "$binTP_sum=( $(for i in $(seq 1 ${!nRois} ); do echo 0; done) )" 
    declare -a "$volTP_mean=( $(for i in $(seq 1 ${!nRois} ); do echo 0; done) )"
    declare -a "$TPR=( $(for i in $(seq 1 ${!nRois} ); do echo 0; done) )"



# TODO: delete all this after checking indirect indexing above
#    if [ "$sign" = "Pos" ]; then  
#        roiSizes_Pos=$(echo "$roiMaskSummary" | awk '{print $2}') 
#        nRois_Pos=$(echo $roiIDs |  awk '{print $1}' )
#
#        declare -a volTP_Pos_sum=( $(for i in $(seq 1 $nRois_Pos); do echo 0; done) )
#        declare -a binTP_Pos_sum=( $(for i in $(seq 1 $nRois_Pos); do echo 0; done) )
#    else
#         roiSizes_Neg=$(echo "$roiMaskSummary" | awk '{print $2}')
#         nRois_Neg=$(echo $roiIDs |  awk '{print $1}' )
#
#         declare -a volTP_Neg_sum=( $(for i in $(seq 1 $nRois_Neg); do echo 0; done) )
#         declare -a binTP_Neg_sum=( $(for i in $(seq 1 $nRois_Neg); do echo 0; done) )
#    fi
    # echo ${#roiSize_Pos[@]} # quick check array size

done



