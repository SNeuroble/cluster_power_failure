#!/bin/bash

### Define paths & params for this subset of perms
# TODO: consider renaming
permDir="$outputDir/perms${first_perm}-${last_perm}"
permOutputsDir="${permDir}/subset_results"
outputDirSummary="${permDir}/Summary"
dataDir_lowerlevel="${permOutputsDir}/lower_level"
logfile="$outputDirSummary/log"
templogfile="${permOutputsDir}/tmp"
emptyImg="${permOutputsDir}/emptyimg.nii.gz"

# ...additional things for FLAME setup
if [ "$doRandomise" == "false" ]; then
    designFile_Pos="$permOutputsDir/design_Pos.fsf"
    designFile_Neg="$permOutputsDir/design_Neg.fsf"
    outputFile_Pos="$permOutputsDir/${processedSuffix}_Pos"
    outputFile_Neg="$permOutputsDir/${processedSuffix}_Neg"
    resultImg_Pos="${outputFile_Pos}${resultImgSuffix}"
    resultImg_Neg="${outputFile_Neg}${resultImgSuffix}"
fi



### Check stuff

[[ ! -f $subNamesWithInput ]] && echo "Error: local repository missing. Have you run \"get_data_and_ground_truth.sh\"?" && exit

# Check whether stuff in output folder
if [[ ! -z $outputDirSummary ]]; then
    if [[ -d $outputDirSummary ]] && [ "$(ls -A $outputDirSummary)" ]; then
        echo "In progress or completed: $permDir" >> $outputDirRecord
        read -r -p "Specified output directory $outputDirSummary is not empty. Press [Y/y] to delete previous contents, [R/r] to resume from previous process, any other character to exit." response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            echo -e "\nDeleting contents of old output directory."
            rm -rf $permDir # COMMENT OUT FOR TESTING ONLY
        elif  [[ "$response" =~ ^[Rr]$ ]]; then
            echo -e "\nResuming from previous process."
            resume_previous_process=true
        else
            echo -e "\nOkay, exiting."
            exit
        fi
    else
        echo "Saving output to: $permDir" >> $outputDirRecord
    fi
else
    echo "Output directory $permDir is not specified."
    exit
fi

# Create folders if don't exist
mkdir -p $permDir
mkdir -p $permOutputsDir
mkdir -p $outputDirSummary
mkdir -p $subjectRandomizations

# Special setup if resuming from previous process
if [ "$resume_previous_process" = "true" ]; then
    cp ${logfile} ${logfile}__before_resumed_process
    ActualPermutations=$(( $( tac ${logfile} | grep -m1 'Permutation ' | sed 's/Permutation \(.*\)/\1/') ))

    # check whether any completed (none, pos, or both)
    completedResults=$( tac ${logfile} | sed '/^Permutation '$ActualPermutations'/q' | grep "Done adding" | sed 's/Done adding \(.*\)/\1/g' )
    if [ "$completedResults" = "Pos" ]; then
        printf "Only finished Positive results for permutation $ActualPermutations. Need to do Negative, too (must run manually; fix not currently implemented)."
        exit
    elif [ -z "$completedResults" ]; then # for when neither result was saved
        ActualPermutations=$(( ActualPermutations - 1 ))
    fi

    first_perm=$(( ActualPermutations + 1 ))
    if [[ $ActualPermutations == -1 ]]; then
        echo "Error reading log file $logfile."
        exit
    fi

    echo "Resuming with $ActualPermutations perms completed. $first_perm to $last_perm"
    [[ -d "$permOutputsDir" ]] && rm -r "$permOutputsDir/*"
fi


### Prepare reference files

# Create pre-randomized files, if don't exist
# TODO: IN PROGRESS
mkdir -p $subjectRandomizations
for perm in $(seq $first_perm $last_perm); do
    subNames_subset=$subjectRandomizations/perm$perm
    if [[ ! -f $subNames_subset ]]; then
        shuf -n $nSubs_subset $subNamesWithInput > ${subNames_subset}
    fi
done

# Create empty image for summary
fslmaths $groundTruthDcoeff -mul 0 $emptyImg
cp $emptyImg $outputDirSummary/all_clusters_Pos.nii.gz
cp $emptyImg $outputDirSummary/all_clusters_Neg.nii.gz






