#!/bin/bash

# Report detected activations and FWE
ActualPermutations=$(( $this_perm - $NoGroupAnalysis - $NoGroupMask ))

if [ "$anyclusters" -eq "0" ]; then
    echo "00 No significant group activation detected. ${effectdescrip}"
else
    echo "** Significant group activation detected! ${effectdescrip}"
    ((SignificantDifferences++))

    # count TPs that occurred without FPs
    if [ "$doTPR" = true ] && [ $anyclusters_CMFPR -eq 0 ]; then
        ((SignificantDifferences_CMFPR++))
        echo "Activation detected without underlying FP cluster."
        FWE_exclFPR=$(echo "scale=3; $SignificantDifferences_CMFPR /  $ActualPermutations" | bc)
        FWE_exclFPR_string="; $FWE_exclFPR when excluding FPR"
    fi

fi

FWE=$(echo "scale=3; $SignificantDifferences /  $ActualPermutations" | bc)
printf "Current FWE is $FWE with $ActualPermutations actual tests $FWE_exclFPR_string \n" >> $ResultsDirectory/FWElog$Effect.txt

AvgFWEcorrThresh=$(echo "scale=3; ($AvgFWEcorrThresh * ($ActualPermutations-1)/$ActualPermutations) + ($FWEcorrThreshold/$ActualPermutations)" | bc)
printf "Average FWE-corrected threshold is ${AvgFWEcorrThresh}. \n" >> $ResultsDirectory/FWElog$Effect.txt

