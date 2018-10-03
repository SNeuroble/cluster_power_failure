#!/bin/bash
#set -x
# usage: e.g., combine_WBTests.sh clf_shortcut/FSL_Perm/GroupSize20/Twosamplettest/ClusterThreshold2.3/TPR_wFPR/EffectSize0.8/NoBlur/ _activationadded

[[ -z $1 ]] && { echo "Error: Argument needed." ; exit 1 ; }
#[[ -f $1 ]] && source $1 || summaryFolder="$1/Summary"

summaryFolder="$1/Summary"
effect=$2 # e.g., "_activationadded"
mkdir "$summaryFolder"

#effect="_activationadded"

# Sum detected clusters
#filename="all_clusters_activationadded.nii.gz"
basefilename="all_clusters${effect}"
filename="${basefilename}.nii.gz"
filelist=$(find $1 -maxdepth 3 -name "$filename") 
outfilename="$summaryFolder/${basefilename}_sum.nii.gz"
3dMean -sum -prefix "$outfilename" $filelist
echo "Summary image saved to ${outfilename}."

# Sum ground truth clusters
filename2="${basefilename}_groundtruth.nii.gz"
filelist2=$(find $1 -maxdepth 3 -name "$filename2")
outfilename2="$summaryFolder/${basefilename}_groundtruth_sum.nii.gz"
3dMean -sum -prefix "$outfilename2" $filelist2
echo "Summary image saved to ${outfilename2}."

# Mean of mean FWE
#filename="FWElog_activationadded.txt"
filename="FWElog${effect}.txt"
list=$( find $1 -maxdepth 3 -name "$filename" -exec sh -c "grep -i 'Current FWE is ' {} | sed 's/\(.*\)Current FWE is \(.*\) with\(.*\)/\2/' " \; )
FWEsum=$( echo $list | sed 's/ /+/g' | bc -l )
FWEcounts=( $list )
FWEcounts=${#FWEcounts[@]}
FWEmean=$( echo "scale=2; $FWEsum*100/$FWEcounts" | bc -l ) # in percent
echo "${FWEmean}" > "$summaryFolder/$(basename ${filename} .txt)_meanpercent.txt"

echo "Summary complete. Mean FWER = ${FWEmean}%."
