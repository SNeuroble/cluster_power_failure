# Paths and parameters for Cluster Power Failure - Simulation Test

### PARAMETERS (SPECIFY)

Testing=false # change when tests complete
resume_previous_process=false

# Data
Study=Beijing
Study_Filename=Beijing_Zang
GroupSize=20
NumberOfSubjects=$(( $GroupSize * 2 )) # Don't modify - 2-sample t-test assumed

# Software + thresholds 
Software=FSL
Procedure=Perm
doTFCE=false # only relevant to FSL
thisCDT=3
Cluster=${thisCDT}
DesignNum=4 # Don't modify
SmoothingLevel=2 # Don't modify
ttestType=Two # Don't modify
FWEthreshold=0.95
nperms_forRandomise=1000 # if testing, use 5

# Simulation parameters
doTPR=true
EffectSize=0.5 # only relevant if doTPR=true
radius_sq=9 # only relevant if doTPR=true; in voxels, incl center (vox size=3mm); r=3vox=9mm -> r^2=9vox^2=81mm^2
doBlur=false # only relevant if doTPR=true
maxFPRPerms=5000 # only relevant if doTPR=false

# Parallelization
# Note: a full WBtest comprises results from all CMs in mask; slow so recommend running one at a time
first_job_to_launch=1
last_job_to_launch=8 #17 # 19
njobs=8 #17 #19 # used to divy CMs # 2133 to get 2 CM each for subsampled mask
njobs_in_subset=$(( $last_job_to_launch - $first_job_to_launch + 1 ))
first_WBtest=1
last_WBtest=10
nWBtests=$(( $last_WBtest - $first_WBtest + 1 ))

# Base directories
ScriptsDirectory="/home/ec2-user/scripts/cluster_failure"
InputDataDirectory="/home/ec2-user/data/cluster_failure"
OutputDataDirectory="/home/ec2-user/data/cluster_failure"
MaskFolder="/home/ec2-user/data/misc/talairachmask/cmIDs"
DesignsDirectory="/home/ec2-user/data/misc/designs/${Software}"
CMDirectory="$MaskFolder" # only relevant if doTPR=true
cmID_referencefile="$CMDirectory/cmID_TT_N27_3mm_seg_1__dilated_remasked_subsampled__reorientLPS.txt" # only relevant if doTPR=true
cmID_file="${cmID_referencefile}" # only relevant if doTPR=true
# TODO: consider logfile="${OutputDataDirectory}/log"

# Environment variables
export FSLOUTPUTTYPE=NIFTI_GZ
export AFNI_DONT_LOGFILE=YES

