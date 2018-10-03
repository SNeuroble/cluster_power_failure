#!/bin/bash
# need to provide setpaths.sh
# make sure instance meets memory requirements

### Setup

clear
[[ ! -z $1 && -f $1 ]] && source $1 || { echo "Error: Config file needed." ; exit 1 ; }

# Set up - special for full dataset
nSubs_subset=$nSubs_total
subNames_subset="$subNamesWithInput"
permDir="$dataDir_localRepository"
permOutputsDir="${permDir}"
dataDir_lowerLevel="${dataDir_localRepository_lowerLevel}"
logfile="${permDir}/log"
templogfile="${permDir}/tmp"
emptyImg="${permOutputsDir}/emptyimg.nii.gz"

# ...additional things for FLAME setup
if [ "$doRandomise" == "false" ]; then
    designFile_Pos="$permDir/design.fsf"
    designFile_Neg="$permDir/design_Neg.fsf"
    outputFile_Pos="$permOutputsDir/${processedSuffix}_Pos"
    outputFile_Neg="$permOutputsDir/${processedSuffix}_Neg"
    resultImg_Pos="${outputFile_Pos}${resultImgSuffix}"
    resultImg_Neg="${outputFile_Neg}${resultImgSuffix}"
fi

mkdir -p $dataDir_lowerLevel 

# Get names of all HCP sub, if doesn't exist
printf "\nGetting subject data.\n"
if [[ -f $subNames ]]; then
    read -p "Subject names file $subNames exists - overwrite?"
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm $subNames
        s3cmd -c $hcpConfigFile ls $cloudDataDir > $subNames
        sed -e 's#                       DIR   '$cloudDataDir'##g' -i $subNames
        sed -e 's#/##g' -i $subNames
    else
        printf "Using existing subject names file.\n"
    fi  
fi

# Get names of all subs w data, if doesn't exist
skip='no'
if [[ -f $subNamesWithInput ]]; then
    read -p "File  $subNamesWithInput exists - overwrite?" 
    if [[ $REPLY =~ ^[Yy]$ ]]; then    
        rm $subNamesWithInput
    else skip='yes'
    fi
else
    touch $subNamesWithInput
fi

if [ $skip == 'no' ]; then
    while read subject; do
        s3cmd -c $hcpConfigFile ls $cloudDataDir/$subject/$cloudDataDir_contd/$inputFileSuffix >> $subNamesWithInput
    done < $subNames 
    sed -e 's#                       DIR   '$cloudDataDir/'##g' -i $subNamesWithInput
    sed -e 's#'/$cloudDataDir_contd/$inputFileSuffix/'##g' -i $subNamesWithInput
fi

# Download data if needed
if [ ! "$(ls -A ${dataDir_lowerLevel})" ] ; then # check whether empty
    get_data=true
else
    printf "Data exists in ${dataDir_lowerLevel}."
    read -rep $'\nEnter \"delete all previous data\" to delete all previously downloaded data and download again and any other character to return. Response?   ' response
    if [[ "$response" =~ "delete all previous data" ]]; then
        printf "Okay, deleting previously created data for these jobs.\n"
        rm -r ${dataDir_lowerLevel}
        mkdir ${dataDir_lowerLevel}
    # add functionality to resume downloading
    else
        printf "Okay, keeping previous data.\n"
        get_data=false
    fi
fi

if [ "$get_data" = true ] ; then
    printf "Getting data.\n"
    while read subject; do
        printf "Downloading subject $subject \n"
        mkdir -p $dataDir_lowerLevel/${subject}_$inputFileSuffix/
        s3cmd -c $hcpConfigFile get --recursive --skip-existing $cloudDataDir/$subject/$cloudDataDir_contd/$inputFileSuffix/ $dataDir_lowerLevel/${subject}_$inputFileSuffix/ || exit
    done < $subNamesWithInput
fi

### Process full dataset, if not done
if [ ! -f $groundTruthTstat ]; then
    echo $groundTruthTstat
    printf "Processing (second level)...\n"
    . $scriptsDir/do_second_level__randomise.sh 
    #. $scriptsDir/do_second_level__FLAME_pos_only.sh 
else
    printf "Result file $groundTruthTstat already exists, moving on.\n"
fi

#if [ ! -d $groundTruth ]
#    . make_TP_mask.sh
#fi

# ground truth map. t -> d: 2*t/sqrt(DOF) , where DOF ~=484 (TODO: will actually slightly vary)
if [ ! -f $groundTruthDcoeff ]; then
sqrt_DOF=$(echo "sqrt($nSubs_subset)" | bc)
#3dcalc -a $groundTruthTstat -expr '2*a/22' -prefix $groundTruthDcoeff 
#echo "WARNING: USING APPX DOF IN CALCULATION" # TODO: test fix w below
3dcalc -a $groundTruthTstat -expr '2*a/'"$sqrt_DOF" -prefix $groundTruthDcoeff # TODO
else
    printf "Using existing $groundTruthDcoeff .\n"
fi

# rename results folder
nSubs_total=$(wc -l < $subNamesWithInput)
dataDir_localRepository_new="$dataMasterDir/GroupSize$nSubs_total"
if [ ! -d $dataDir_localRepository_new ]; then
    mv $dataDir_localRepository $dataDir_localRepository_new
fi

printf "Finished.\n\n"

