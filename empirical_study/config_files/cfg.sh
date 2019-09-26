# Paths and parameters for Cluster Power Failure scripts

################### PARAMETERS (USER-SPECIFIED) ###################

testing=false

# Number of repetitions (not used for ground truth calculation)
nPermutations=500 

# Data
task="SOCIAL"
hcpReleaseNo="1200"
nSubs_subset=20 # (not used for ground truth calculation)

# Software + thresholds (much of these are not used for ground truth calculation) 
Software="FSL" # NOTE: currently FSL is the only choice
doRandomise=true
doTFCE=false
CDT="3.1" #z-val
CDTp="0.001" #p-val
FWEthreshold="0.95"
nPerms_forRandomise=1000 #1000 is recommended to resolve within p+/-0.01

# Parallelization parameters 
njobs=17 # divy repetitions across njobs - recommended one more job than CPUs - will put leftover repetitions in last job
first_job_to_launch=1 # for running a subset of jobs
last_job_to_launch=17 # for running  a subset of jobs

# Reference directories
scriptsDir="/home/ec2-user/scripts/empirical_study"
dataDir="/home/ec2-user/data/hcpTask"


################# DIRECTORIES AND OTHER SETUP #################

# Task/cope pairs: SOCIAL_cope6; WM_cope20; GAMBLING_cope6; RELATIONAL_cope4; EMOTION_cope3
case $task in
    'SOCIAL')
        copeNum="6" ;;
    'WM')
        copeNum="20" ;;
    'GAMBLING')
        copeNum="6" ;;
    'RELATIONAL')
        copeNum="4" ;;
    'EMOTION')
        copeNum="3" ;;
    *)
        echo "Error: must specify task."
        exit
esac

# More setup
maskThresh=$CDT
one_minus_CDTp=$(echo "1 - $CDTp" | bc)
nperms_per_job=$(echo "$nPermutations / ($njobs-1)" | bc) # divy up repetitions across njobs; output floored
njobs_in_subset=$(( $last_job_to_launch - $first_job_to_launch + 1 ))

# Directories and key files
dataMasterDir="${dataDir}/${task}_cope${copeNum}"
subNamesWithInput="$dataMasterDir/hcp_file_names_S${hcpReleaseNo}_with_cope${copeNum}.txt"
nSubs_total=$(wc -l < $subNamesWithInput)

# Full dataset repository
dataDir_localRepository="$dataMasterDir/GroupSize$nSubs_total"
dataDir_localRepository_lowerLevel="$dataDir_localRepository/lower_level"

# Processing files, settings, &c
if [ "$doTFCE" = true ]; then
    RandomiseOptions_WithThresholds="-T -1"
    RandomiseOptions_NoThresholds="${RandomiseOptions_WithThresholds} -R"
    UncorrectedTstat="tfce_tstat1"
    ClusterTstat="tfce_corrp_tstat1"
else
    RandomiseOptions_WithThresholds="-c ${maskThresh} -1"
    RandomiseOptions_NoThresholds="${RandomiseOptions_WithThresholds} -x"
    UncorrectedTstat="tstat1"
    ClusterTstat="clustere_corrp_tstat1"
fi
processedSuffix="processed"
designTemplate="$scriptsDir/design_templates/design_template.fsf" #FLAME

# Ground truth data folders and mask
#cloudDataDir="s3://hcp-openaccess-temp/HCP_${hcpReleaseNo}" # used during HCP migration 
cloudDataDir="s3://hcp-openaccess/HCP_${hcpReleaseNo}"
cloudDataDir_contd="MNINonLinear/Results/tfMRI_$task/tfMRI_${task}_hp200_s4_level2vol.feat"
hcpConfigFile="$scriptsDir/s3cmd_config_files/hcp_access_S$hcpReleaseNo"
inputFileSuffix="cope${copeNum}.feat"
subNames="$scriptsDir/hcp_file_names_S${hcpReleaseNo}.txt"
groundTruthFolder="$dataDir_localRepository"
maskDir="${groundTruthFolder}/mask"

if [ "$doRandomise" = true ]; then
    groundTruthTstat="${groundTruthFolder}/${processedSuffix}_tstat1.nii.gz"
    groundTruthMask="${groundTruthFolder}/${processedSuffix}_clustere_corrp_tstat1.nii.gz"
else
    tstatSuffix=".gfeat/cope1.feat/stats/tstat1.nii.gz"
    groundTruthTstat="${groundTruthFolder}/${processedSuffix}_Pos${tstatSuffix}"
    # mask TBD
fi
groundTruthDcoeff="${groundTruthFolder}/dcoeff.nii.gz"

# Output directories
outputDirSuffix=$( [ $doRandomise = "true" ] && echo "randomise" || echo "FLAME" )
outputDirSuffix=$( [ $doTFCE = "true" ] && echo "${outputDirSuffix}TFCE" || echo "$outputDirSuffix" )
outputDirSuffix=$( [ $testing = "true" ] && echo "${outputDirSuffix}TESTING" || echo "$outputDirSuffix" )
outputDir="$dataMasterDir/GroupSize${nSubs_subset}__${outputDirSuffix}"
subjectRandomizations="$outputDir/subIDs"
outputDirRecord="$outputDir/existing_dirs.txt"
resultImgSuffix=".gfeat/cope1.feat/cluster_mask_zstat1.nii.gz"
combinedSummaryDir="$outputDir/Summary" 
