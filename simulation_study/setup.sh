#!/bin/bash
#set -x
echo "++ Setting stuff up"

# Study design
if [ "$DesignNum" -eq "1" ]; then
    Design=boxcar10_REML
elif [ "$DesignNum" -eq "2" ]; then
    Design=boxcar30_REML
elif [ "$DesignNum" -eq "3" ]; then
    Design=regularEvent_REML
elif [ "$DesignNum" -eq "4" ]; then
    Design=randomEvent_REML
fi

# Cluster extent thresholds
# Use z-scores instead of t-scores, to avoid changing threshold for different group sizes
# z-value = 2.326 corresponds to p = 0.01; z-value = 3.086 -> p = 0.001 (one sided)
if [ "$Cluster" -eq "1" ]; then
    ClusterDefiningThresholdP=0.01
    ClusterDefiningThreshold=2.326
    CDT=2.3
elif [ "$Cluster" -eq "2" ]; then # new addition
    ClusterDefiningThresholdP=0.005
    ClusterDefiningThreshold=2.576
    CDT=2.8
elif [ "$Cluster" -eq "3" ]; then
    ClusterDefiningThresholdP=0.001
    ClusterDefiningThreshold=3.086
    CDT=3.1
elif [ "$Cluster" -eq "5" ]; then
    ClusterDefiningThresholdP=0.0003
    ClusterDefiningThreshold=3.432
    CDT=3.4
fi
#    ClusterDefiningThresholdP=0.05
#    ClusterDefiningThreshold=1.645
#    CDT=1.6

# TODO: this is kinda hack-y, but makes sure we detect false positive in TP location
one_minus_CDTp_liberal=$(echo "1 - $ClusterDefiningThresholdP - 0.005" | bc)

# Smoothing level
if [ "$SmoothingLevel" -eq "1" ] ; then
    Smoothing=4mm
elif [ "$SmoothingLevel" -eq "2" ] ; then
    Smoothing=6mm
elif [ "$SmoothingLevel" -eq "3" ] ; then
    Smoothing=8mm
elif [ "$SmoothingLevel" -eq "4" ] ; then
    Smoothing=10mm
fi

# Set up TPR/FPR-specific things 
if [ "$doTPR" = true ]; then
    # TPR-specific options: do seed, add blur
    Effect="_activationadded"
    effectdescrip="With added activation (including underlying local FPR)."
    # TODO: see whether want to keep
    if [ "$doBlur" = false ]; then
        Blur_string=No
    fi
    SimString=TPR_wFPR/rsq${radius_sq}/EffectSize${EffectSize}/${Blur_string}Blur
else
    effectdescrip="Without added activation."
    SimString=FPR
fi

# Set up randomise-specific things, with or with TFCE
if [ "$doTFCE" = true ]; then
    SpecialThresholding="_TFCE"
    RandomiseOptions_WithThresholds="-T"
    RandomiseOptions_NoThresholds="${RandomiseOptions_WithThresholds} -R"
    UncorrectedTstat="tfce_tstat1"
    ClusterTstat="tfce_corrp_tstat1"
else
    RandomiseOptions_WithThresholds="-c ${ClusterDefiningThreshold}"
    #RandomiseOptions_WithThresholds="-c ${ClusterDefiningThreshold} -x"
    #echo " TEMPORARY CHANGE FOR TESTING "
    # TODO: might be able to lose the -c in the following, unless needed argument when not using TFCE
    RandomiseOptions_NoThresholds="${RandomiseOptions_WithThresholds} -x"
    #UncorrectedTstat="vox_p_tstat1" # SMN - COMMENTED OUT bc different tstat output (for different versions of fsl)
    UncorrectedTstat="tstat1"
    ClusterTstat="clustere_corrp_tstat1"
fi

[[ "$Testing" = true ]] && TestingString="__TESTING"

nperms=$(( $cmID_end__reffile - $cmID_start__reffile + 1 ))

# Set up folders (user-defined)
GroupDirectory="${InputDataDirectory}/RandomGroupAnalyses/Results/${Study}/${Smoothing}/${Design}/SubjectAnalyses"
GroupIDsDirectory="${InputDataDirectory}/RandomGroupAnalyses/Results/${Study}"
#GroupIDsDirectory=/data_dustin/cluster_failure/Data/${Study}/${Study_Filename}_subjects.txt
#DesignsDirectory="${OutputDataDirectory}/RandomGroupAnalyses/${Software}"
ResultsDirectory="${OutputDataDirectory}/RandomGroupAnalyses/Results/${Study}/${Smoothing}/${Design}/GroupAnalyses/${Software}_${Procedure}${SpecialThresholding}${TestingString}/GroupSize${GroupSize}/${ttestType}samplettest/ClusterThreshold${CDT}/${SimString}/WholeBrainTest${WBtest_number}/CM_${cmID_start__reffile}_${cmID_end__reffile}"
PermutationsDirectory="${ResultsDirectory}__permutations"
SubjectActivationsDirectory="${ResultsDirectory}/SubjectActivations"
logfile="${ResultsDirectory}/tmp.txt" # TODO: consider replacing tmp.txt throughout scripts

# Design and contrast for GroupSize 20 - TODO: automate running Text2Vest of con and dmat for diff groupsizes and test types
dmat="${DesignsDirectory}/design_matrix_${ttestType,,}samplettest_groupsize${GroupSize}.mat"
con="${DesignsDirectory}/contrasts_${ttestType,,}samplettest_groupsize${GroupSize}.con"



# Check whether old ResultsDirectory already completed
if [ ! -z "$ResultsDirectory" ]; then # var is not empty
    if [ -d "$ResultsDirectory" ]; then # directory exists
        if [ "$(ls -Ap $ResultsDirectory | grep -v / )" ]; then # directory contains files

            # DO NOT CHANGE: master script launch_parallel (line 111) relies on this
            echo "In progress or completed: $ResultsDirectory" >> ~/existing_dirs.txt
            in_progress_or_completed=true
            read -r -p "Folder $ResultsDirectory is not empty. Press [Y/y] to delete previous contents, [R/r] to resume from previous process, any other character to exit." response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                echo -e "\nDeleting contents of old Results Directory."
                rm -rf $ResultsDirectory/*
            elif [[ "$response" =~ ^[Rr]$ ]]; then
                echo -e "\nResuming from previous process."
                resume_previous_process=true
            else
                exit
            fi
        fi
    fi
else
    echo "Folder $ResultsDirectory is unspecified."
    exit
fi

if [ "$in_progress_or_completed" != true ]; then
    echo "Using this directory: $ResultsDirectory" >> ~/existing_dirs.txt
fi

# Setup if starting a new process (resuming process mainly important for TPR)
if [ "$resume_previous_process" = false ]; then

    # Initialize vars
    SignificantDifferences=0
    SignificantDifferences_CMFPR=0
    FWE=0.0
    FWE_exclFPR=0.0
    AvgFWEcorrThresh=0.0
    NoGroupMask=0
    NoGroupAnalysis=0
    cmID_start__locfile=1
    this_perm=0
    FWE_exclFPR=0.0
    
    # make directories
    mkdir -p $ResultsDirectory
    mkdir -p $SubjectActivationsDirectory

    # Make an empty "zero" image for keeping track of FDR rates
    if [ "$Study" = "Oulu" ]; then examplesub=01077
    elif [ "$Study" = "Beijing" ]; then examplesub=01018
    elif [ "$Study" = "Cambridge" ]; then examplesub=00156
    else echo "Misspecified study."; return
    fi

    3dcalc -prefix $ResultsDirectory/emptyimg.nii.gz -a "$GroupDirectory/sub${examplesub}.results/full_mask.sub${examplesub}+tlrc.HEAD" -exp "a*0" &>> $ResultsDirectory/tmp.txt

    cp $ResultsDirectory/emptyimg.nii.gz $ResultsDirectory/all_clusters${Effect}.nii.gz
    if [ "$doTPR" = true ]; then
        cp $ResultsDirectory/emptyimg.nii.gz $ResultsDirectory/all_clusters${Effect}_groundtruth.nii.gz
        cp $ResultsDirectory/emptyimg.nii.gz $ResultsDirectory/all_clusters${Effect}_CMFPR.nii.gz
    fi

    # Convert sub betas to nifti
    while IFS= read -r this_sub; do
        this_nii="${GroupDirectory}/${this_sub}.results/stats.${this_sub}.nii.gz"

        if [ ! -e ${this_nii} ]; then
            echo "Creating ${this_nii} "
            3dAFNItoNIFTI -prefix "${this_nii}" "${GroupDirectory}/${this_sub}.results/stats.${this_sub}+tlrc[1]" \

                >> ${ResultsDirectory}/tmp.txt
        fi
    done < $GroupIDsDirectory/${Study_Filename}_subjects.txt

    # Create list of subjects permutations for each iteration
    echo "Randomizing subjects"
    if [ ! -d "$PermutationsDirectory" ]; then
        bash "$ScriptsDirectory/generate_permutations__Beijing.sh" "$GroupIDsDirectory/${Study_Filename}_subjects.txt" "$nperms" "$NumberOfSubjects" "$PermutationsDirectory"
    fi

else # Special setup if resuming from previous process

    cp ${ResultsDirectory}/FWElog${Effect}.txt ${ResultsDirectory}/FWElog${Effect}__before_resumed_process.txt
    # this perm is about to get incremented, but not cmID_start__locfile (so must manually increment)
    ActualPermutations=$(tac ${ResultsDirectory}/FWElog${Effect}.txt | grep -i -m1 'Current FWE is ' | sed 's/\(.*\)with \(.*\) actual tests\(.*\)/\2/')
    this_perm=$ActualPermutations
    cmID_start__locfile=$(( $ActualPermutations + 1 ))

    FWE=$( grep -i 'Current FWE is ' ${ResultsDirectory}/FWElog${Effect}.txt | tail -1 | sed 's/\(.*\)Current FWE is \(.*\) with\(.*\)/\2/')
    AvgFWEcorrThresh=$(tac ${ResultsDirectory}/FWElog${Effect}.txt | grep -i -m1 'Average FWE-corrected threshold ' | sed 's/\(.*\)FWE-corrected threshold is \(.*\)\./\2/')
    SignificantDifferences=$(echo "scale=0; ($FWE * $ActualPermutations) / 1" | bc -l)
    
    #FWE_exclFPR=$( grep -i 'when excluding ' ${ResultsDirectory}/FWElog${Effect}.txt | tail -1 | sed 's/\(.*\) ; \(.*\) when excluding\(.*\)/\2/')
    #SignificantDifferences_CMFPR=$(echo "scale=0; ($FWE_exclFPR * $ActualPermutations) / 1" | bc -l)

    # Check appropriate number of perms
    if (( "$(ls "$PermutationsDirectory" | wc -l )" < "$nperms" )); then
        echo "Not enough pre-randomized permutations files in $PermutationsDirectory - only $(ls "$PermutationsDirectory" | wc -l ) files." | tee -a $ResultsDirectory/errorlog${Effect}.txt
        exit
    fi

    # TODO: update these for completeness
    FWE_exclFPR=0 # note: this isn't saved anyways
    SignificantDifferences_CMFPR=0 # note: this isn't saved anyways
    NoGroupMask=0
    NoGroupAnalysis=0

    echo "Resuming with $ActualPermutations perms completed (local cmID will start at $cmID_start__locfile): FWE = ${FWE}, average FWE-corrected threshold = ${AvgFWEcorrThresh}."

fi

if [ "$doTPR" = "true" ]; then
    cmID_localfile=$ResultsDirectory/cmID_list.txt
    sed -n ${cmID_start__reffile},${cmID_end__reffile}p $cmID_referencefile > $cmID_localfile
fi
cmID_end__locfile=$(echo "$cmID_end__reffile - $cmID_start__reffile + 1" | bc) # if TPR, number of lines in local file

