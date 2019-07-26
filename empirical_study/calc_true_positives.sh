#!/bin/bash
######################################################################
#
# This script is part of the Cluster Power Failure project
#
# Details: Add mask of positives to running summary by sign of detected effects 
# Usage: Called from run_hcp_cluster_failure.sh script 
#
######################################################################

printf "++ Getting clusters and accumulating (for true positives calculation).\n"

for sign in Pos Neg ; do 

    resultImg=${permOutputsDir}/${processedSuffix}_${sign}_${ClusterTstat}.nii.gz # for randomise
    #resultImg="$permOutputsDir/${processedSuffix}_${sign}${resultImgSuffix}" # for FLAME
    resultImgBin=$outputDirSummary/clusters_${sign}_bin.nii.gz
    clusterImg=$outputDirSummary/all_clusters_${sign}.nii.gz
    clusterImgTmp=$outputDirSummary/tmp_all_clusters_${sign}.nii.gz

    # Get binarized clusters - apply FWE-corrected threshold to cluster-wise corrected map
    fslmaths "$resultImg" -thr ${FWEthreshold} -bin "$resultImgBin" 
    #fslmaths "$resultImg" -bin "$resultImgBin" # for FLAME
    
    # Accumulate full map of results
    fslmaths "$clusterImg" -add "$resultImgBin" "$clusterImgTmp"

    # Replace previous result with current (the check is because some software won't create any output if the input is empty)
    if [[ -f $clusterImg && -f $clusterImgTmp ]]; then
        rm $clusterImg
        mv $clusterImgTmp $clusterImg
    fi
    
    printf "Done adding ${sign} results. \n"
    
    # Clean up clusters and related masks
    if [[ -f $resultImgBin ]]; then
        rm $resultImgBin
    fi

done


