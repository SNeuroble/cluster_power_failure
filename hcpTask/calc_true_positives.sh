#!/bin/bash
# Determine number/extent of TP by mask ROI location and sign 

printf "++ Getting clusters and accumulating (for true positives calculation).\n"

for sign in Pos Neg ; do 

    resultImg=${permOutputsDir}/${processedSuffix}_${sign}_${ClusterTstat}.nii.gz # for randomise
    #resultImg="$permOutputsDir/${processedSuffix}_${sign}${resultImgSuffix}" # for FLAME
    resultImgBin=$outputDirSummary/clusters_${sign}_bin.nii.gz
    clusterImg=$outputDirSummary/all_clusters_${sign}.nii.gz
    clusterImgTmp=$outputDirSummary/tmp_all_clusters_${sign}.nii.gz

    # #cp ~/test.nii.gz $resultImg # TESTING ONLY: uncomment
   
    # Get binarized clusters - apply FWE-corrected threshold to cluster-wise corrected map
    fslmaths "$resultImg" -thr ${FWEthreshold} -bin "$resultImgBin" 
    #fslmaths "$resultImg" -bin "$resultImgBin" # for FLAME
    
    # Accumulate full map of results
    fslmaths "$clusterImg" -add "$resultImgBin" "$clusterImgTmp"

    # TODO: Old safety bc afni wouldn't create the above output image if the input img was empty... check whether still needed here
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


