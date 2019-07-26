#!/bin/bash
######################################################################
#
# This script is part of the Cluster Power Failure project
#
# Details: Runs second level parametric inference
# Usage: Called from get_data_and_ground_truth.sh
# Note: Check memory requirements for large datasets 
#
######################################################################

############# SETUP #############

# Set up design template
cp $designTemplate $designFile_Pos

sed -i "s#Xoutput_file#${outputFile_Pos}#g" $designFile_Pos  
sed -i "s#Xnum_inputs#${nSubs_subset}#g" $designFile_Pos

# ...continuing with multi-line edits
for ((subject=1; subject<=$nSubs_subset; subject++)); do
    subID=$(sed "${subject}q;d" $subNames_subset)
    sed -i "s#Xinput_files#set feat_files($subject) \"${dataDir_localRepository_lowerLevel}/${subID}_${inputFileSuffix}\"\nXinput_files#g" $designFile_Pos
    sed -i 's#XEV_vals#set fmri(evg'"${subject}"'.1) 1\nXEV_vals#g' $designFile_Pos
    sed -i "s#Xgroup_membership#set fmri(groupmem.$subject) 1\nXgroup_membership#g" $designFile_Pos
done

sed -i "s#Xinput_files##g" $designFile_Pos
sed -i "s#XEV_vals##g" $designFile_Pos
sed -i "s#Xgroup_membership##g" $designFile_Pos

# Copy and change design template for negative contrast
cp $designFile_Pos $designFile_Neg
sed -i 's#set fmri(evg\(.*\).1) 1#set fmri(evg\1.1) -1#g' $designFile_Neg
sed -i "s#${outputFile_Pos}#${outputFile_Neg}#g" $designFile_Neg


############# ANALYSIS #############

# Run analysis and clean up
printf "\n++ Processing data - positive and negative contrasts... "
feat $designFile_Pos
feat $designFile_Neg
printf "Done second level.\n"

