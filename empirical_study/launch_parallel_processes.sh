#!/bin/bash
######################################################################
#
# This script is part of the Cluster Power Failure project
#
# Details: Splits cluster failure analyses over multiple jobs
# Usage: launch_parallel_processes.sh cfg.sh
# Note: last job intended to handle leftovers (e.g., 17 iterations over 5 jobs -> 4 jobs x 4 its + 1 job x 1 it)
# Note: after complete, combine results with "combine_results.sh"
#
######################################################################


############## SETUP ############## 

[[ ! -z $1 && -f $1 ]] && setupfile=$1 || { echo "Error: Config file needed." ; exit 1; }
source $setupfile

# Check number of jobs
[[ $njobs > $(nproc --all) ]] && printf "** Warning: more jobs than CPUs.\n"

# Create file to keep track of jobs already completed (including partially complete)
mkdir -p $outputDir
[[ -e $outputDirRecord ]] && rm $outputDirRecord
touch $outputDirRecord

# Create pre-randomized files, if don't exist
mkdir -p $subjectRandomizations
for perm in $(seq 1 $nPermutations); do
    subNames_subset=$subjectRandomizations/perm$perm
    if [[ -z $subNames_subset ]]; then
        shuf -n $nSubs_subset $subNamesWithInput > ${subNames_subset}
    fi
done

############## LAUNCH JOBS ############## 

for this_job in $(seq $first_job_to_launch $last_job_to_launch); do
    first_perm=$(echo "($this_job-1) * $nperms_per_job + 1" | bc)
    last_perm=$(echo "$this_job * $nperms_per_job" | bc)
    if [ $this_job == $njobs ]; then
        last_perm=$nPermutations
        nperm_lastjob=$(( $last_perm - $first_perm + 1 ))
        if [ $nperm_lastjob == 0 ]; then
            last_job_to_launch=$(( $last_job_to_launch-1 ))
            njobs=$(( $njobs - 1 ))
            njobs_in_subset=$(( $last_job_to_launch - $first_job_to_launch ))
            lastjobtext=" - no extra jobs needed"
            break
        else
            lastjobtext=", except final job $this_job running $nperm_lastjob permutations"
        fi
    fi
    
    screen -mdS "clpf${this_job}${task}" sh -c "${scriptsDir}/run_hcp_cluster_failure.sh ${setupfile} ${first_perm} ${last_perm} " #; exec bash" # uncomment "exec bash" to keep screen open after completion

done

printf "Processes started. \n Permutations to be run across $njobs jobs. \n Currently running this subset of jobs: $first_job_to_launch to $last_job_to_launch ($nperms_per_job Permutations per job$lastjobtext) \n"  
printf "Saving to output directory $outputDir . \n"

# Wait for all jobs to start running
printf "Waiting..."
while (( $( wc -l < $outputDirRecord ) < "$njobs_in_subset" )); do
    printf "..."
    sleep 1
done

############## CHECK STATUS ############## 
### Check whether any jobs had already been partially run or completed - if so, delete, resume, or stop

if [ $( grep "In progress or completed" $outputDirRecord | wc -l ) -gt 0 ]; then

    printf "\n\n--- The following directories are already in progress or completed: --- \n"
    grep "In progress or completed" $outputDirRecord | cut -d\  -f5

    read -rep $'\nEnter \"delete all previous data\" to delete all previously created data for these jobs and start again, \"resume from previous\" to resume these jobs from previous states, and any other character to stop these jobs.\n? ' response

    # Parse user response
    if [[ "$response" =~ "delete all previous data" ]]; then
        printf "Okay, deleting previously created data for these jobs.\n" 
        cmd_for_exists="y"
    elif [[ "$response" =~ "resume from previous" ]]; then
        printf "Okay, resuming these jobs from previous states.\n" 
        cmd_for_exists="r"
    else
        printf "Okay, stopping these jobs.\n"
        cmd_for_exists="n"
    fi

    # Send user command to each session
    for this_job in $(seq $first_job_to_launch $last_job_to_launch); do
        screen -S "clpf${this_job}${task}" -p 0 -X stuff "${cmd_for_exists}"
    done

else # run normally

    printf "All specified jobs are safely running. \n"

fi







