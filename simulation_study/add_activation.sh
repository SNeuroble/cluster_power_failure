#!/bin/bash

#################### Add an activation to Group 1 then test for group differences ####################
# Choose CM until CM is both in mask and shows non-negative smoothness
echo "+++ Selecting activation center of mass (CM)."
printf "CMs attempted: "
cm_misses_counter=0
max_allowable_cm_misses=$(($cmID_end__locfile-$cmID_start+1))

while : ; do
    # Choose center of mass (CM) from pre-randomized file
    cm=$(head "-${this_cmID}" "${cmID_localfile}" | tail -1)
    printf "#$(( $cm_misses_counter + 1 )) ($cm) "
    ivox=$(echo $cm | cut -d " " -f 1)
    jvox=$(echo $cm | cut -d " " -f 2)
    kvox=$(echo $cm | cut -d " " -f 3)
    cm_inmask="$(3dmaskdump -quiet -ibox $ivox $jvox $kvox $ResultsDirectory/group_mask.nii.gz )"
    cm_inmask=$(echo $cm_inmask | cut -d " " -f 4)

    if [ ${cm_inmask} -eq 1 ]; then

        # Estimate local smoothness map from betas
        # typically estimated from residuals, but can equivalently estimate from stat maps when null is true (cf. Eklund 2016)
        # using geometric mean, like afni 3dFWHMx default
        # SPHERE(15); 19 vox radius --> 'SPHERE(4.26)'
        3dLocalstat -quiet -stat FWHM -nbhd 'SPHERE(12)' -mask $ResultsDirectory/group_mask.nii.gz     \
            -prefix $ResultsDirectory/${this_perm}${Effect}_fwhm             \
            ${Betas_allSubs[@]}                                                                     \
            &>> $ResultsDirectory/tmp.txt

        # TODO: consider adding more realistic acf; estimating from first-level residuals rather than coefficients - maybe more independent
        # (note: quiet may not be an option)
        # Then will also have to change line 325 to accumulate all residual maps
        #3dLocalACF -quiet -nbhd 'SPHERE(12)' -mask $ResultsDirectory/group_mask.nii.gz     \
            #-prefix $ResultsDirectory/${this_perm}${Effect}_acf             \
            #-input ${Residuals_allSubs[@]}                                                                     \
            #&>> $ResultsDirectory/tmp.txt


        # Check that estimated smoothness is non-negative (can be negative if some inputs are 0)

        if [ "$doBlur" = true ]; then

            fwhm="$(3dmaskdump -quiet -ibox $ivox $jvox $kvox $ResultsDirectory/${this_perm}${Effect}_fwhm+tlrc.BRIK )"
            fwhmx=$(echo $fwhm | cut -d " " -f 4)
            fwhmy=$(echo $fwhm | cut -d " " -f 5)
            fwhmz=$(echo $fwhm | cut -d " " -f 6)
            fwhm_avg=$(echo "scale=6; ($fwhmx + $fwhmy + $fwhmz)/3" | bc -l)


            if [[ ${fwhm_avg} > 0 ]]; then
                break
            fi # exit loop bc cm in mask and non-negative smoothness

            echo "++ Negative smoothness: i,j,k = ($cm), perm ${this_perm}." >> $ResultsDirectory/cm_miss_log.txt

        else
            break # exit loop bc cm in mask and blurring irrelevant
        fi

    else
        echo "++ Center of activation fell out of mask: i,j,k = ($cm), perm ${this_perm}." >> $ResultsDirectory/cm_miss_log.txt
    fi


    # Move this CM to the end of file and select the next
    sed "${this_cmID}"'{H;d}; ${p;x;s/^\n//}' "${cmID_localfile}" > $ResultsDirectory/tmpIDs.txt
    mv $ResultsDirectory/tmpIDs.txt "${cmID_localfile}"

    # stop if this happens more than 50 times
    cm_misses_counter=$(echo " scale=0; $cm_misses_counter + 1" | bc)
    if [[ $cm_misses_counter -gt $max_allowable_cm_misses ]]; then
        echo "Stopped - too many misses." | tee $ResultsDirectory/errorlog${Effect}.txt
        exit
    fi

done

printf "\n+++ Activation centered at i,j,k = ($cm)."


# Calc standard deviation from betas
3dMean -stdev -prefix $ResultsDirectory/${this_perm}${Effect}_std ${Betas_allSubs[@]}  \
    &>> $ResultsDirectory/tmp.txt

# Add activation of specified effect size to each voxel
3dcalc -prefix $ResultsDirectory/${this_perm}${Effect}_activation   \
    -a "$ResultsDirectory/${this_perm}${Effect}_std+tlrc.BRIK" -exp "$EffectSize*a" &>> $ResultsDirectory/tmp.txt

# Create ROI mask around "activation"
3dcalc -prefix $ResultsDirectory/${this_perm}${Effect}_roi           \
    -a $ResultsDirectory/${this_perm}${Effect}_activation+tlrc.BRIK  \
    -expr "a*step($radius_sq-(i-$ivox)*(i-$ivox)-(j-$jvox)*(j-$jvox)-(k-$kvox)*(k-$kvox))"  \
    &>> $ResultsDirectory/tmp.txt

# this seems to save as BRIK.gz in this afni version
if [ -f $ResultsDirectory/${this_perm}${Effect}_roi+tlrc.BRIK.gz ]; then
    gunzip $ResultsDirectory/${this_perm}${Effect}_roi+tlrc.BRIK.gz
fi

# Blur if specified
if [ "$doBlur" = true ]; then
    echo "++ Average smoothness for blurring: $fwhm_avg."    
    3dmerge -quiet -1blur_fwhm $fwhm_avg -prefix $ResultsDirectory/${this_perm}${Effect}_roiblur     \
        $ResultsDirectory/${this_perm}${Effect}_roi+tlrc.BRIK                                        \
        &>> $ResultsDirectory/tmp.txt
else
    echo "No blurring."
    cp $ResultsDirectory/${this_perm}${Effect}_roi+tlrc.BRIK $ResultsDirectory/${this_perm}${Effect}_roiblur+tlrc.BRIK
    cp $ResultsDirectory/${this_perm}${Effect}_roi+tlrc.HEAD $ResultsDirectory/${this_perm}${Effect}_roiblur+tlrc.HEAD
    # Add activations
    echo "++ Adding activations to Group 1 (Subjects 1 through $GroupSize)."
    Betas_Group1_ActivationsAdded=()
    for i in $(seq 0 $(( $GroupSize - 1 )) ); do

        this_sub=${Subjects[$i]}

        if [ -e "$SubjectActivationsDirectory/stats.${this_sub}${Effect}_roiblur.nii.gz" ]; then
            rm "$SubjectActivationsDirectory/stats.${this_sub}${Effect}_roiblur"*
        fi

        3dcalc -prefix "$SubjectActivationsDirectory/stats.${this_sub}${Effect}_roiblur.nii.gz"   \
            -a "$GroupDirectory/${this_sub}.results/stats.${this_sub}+tlrc[1]"                      \
            -b "$ResultsDirectory/${this_perm}${Effect}_roiblur+tlrc.BRIK"     \
            -expr "a+b" &>> $ResultsDirectory/tmp.txt

        # note: there is only one sub-BRIK for the "experimental" group, which holds the betas (as opposed to control group, where sub-BRIK [1] holds betas)
        Betas_Group1_ActivationsAdded+="$SubjectActivationsDirectory/stats.${this_sub}${Effect}_roiblur.nii.gz "

    done
fi
