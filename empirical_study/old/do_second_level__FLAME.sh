#!/bin/bash

# Set up design template
# TODO: some of these edits only need to be done once and never again
cp $designTemplate $designFile_Pos

sed -i "s#Xoutput_file#${outputFile_Pos}#g" $designFile_Pos  
sed -i "s#Xnum_inputs#${nSubs_subset}#g" $designFile_Pos

for ((subject=1; subject<=$nSubs_subset; subject++)); do  # multiline edits
    subID=$(sed "${subject}q;d" $subNames_subset)
    sed -i "s#Xinput_files#set feat_files($subject) \"${dataDir_localRepository_lowerLevel}/${subID}_${inputFileSuffix}\"\nXinput_files#g" $designFile_Pos
    sed -i 's#XEV_vals#set fmri(evg'"${subject}"'.1) 1\nXEV_vals#g' $designFile_Pos
    sed -i "s#Xgroup_membership#set fmri(groupmem.$subject) 1\nXgroup_membership#g" $designFile_Pos
done

sed -i "s#Xinput_files##g" $designFile_Pos
sed -i "s#XEV_vals##g" $designFile_Pos
sed -i "s#Xgroup_membership##g" $designFile_Pos

# Copy and change for negative contrast
cp $designFile_Pos $designFile_Neg
sed -i 's#set fmri(evg\(.*\).1) 1#set fmri(evg\1.1) -1#g' $designFile_Neg
sed -i "s#${outputFile_Pos}#${outputFile_Neg}#g" $designFile_Neg

# Process data and clean up
printf "\n++ Processing data - positive and negative contrasts... "
# TODO: reinstate
feat $designFile_Pos
feat $designFile_Neg
printf "Done.\n"

