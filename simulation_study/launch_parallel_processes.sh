#!/bin/bash
#########################################################
# Splits cluster failure analyses over multiple jobs
# Usage: launch_parallel_processes.sh cfg.sh
#
# Details: A full test comprises results from all CMs for that study. Multiple repeated 
# whole-brain (WB) tests are performed for each study, e.g., 10 tests may be performed 
# for each CM in the whole brain. Each job is responsible for a fraction of the brain and a single test.
# Note: last job handles leftovers (e.g., 17 iterations over 5 jobs -> 4 jobs x 4 its + 1 job x 1 it)
# Scripts, input data, and masks should be added to their respective folder
#
# To combine all results: combine_and_normalize.sh (TODO: fix)
# To visualize: dospatialsimilarity (laptop)
#    
#########################################################

[[ ! -z $1 && -f $1 ]] && setupfile=$1 || { echo "Error: Config file needed." ; exit 1; }
source $setupfile

[[ ! "$Software" = "FSL" ]] && ( echo "Error: only FSL supported" ; exit 1; )
[[ ! "$Procedure" = "Perm" ]] && ( echo "Error: only FSL randomise (Perm) supported" ; exit 1; )

### Setup

# Check number of jobs
[[ $njobs > $(nproc --all) ]] && printf "** Warning: more jobs than CPUs.\n"

# Create file to keep track of jobs already completed (incl partially complete)
tracking_file=~/existing_dirs.txt
[[ -e "$tracking_file" ]] && rm $tracking_file
touch $tracking_file

# If TPR, get or create center-of-mass (CM) file
if [ "$doTPR" = "true" ]; then
    if [ ! -f $cmID_file ]; then
        printf "Selecting centers of mass from grey matter mask\n"
        # TODO: check that display/java set up; rewrite in python so don't need matlab
        matlab -nosplash -nodesktop -r "cd('${ScriptsDirectory}/matlab/clusterfailure/'); getvoxinmask('${cmID_referencefile}','${cmID_file}'); exit"
    fi
ncmIDs=$(wc -l < $cmID_file )
else # otherwise just get num perms and only one WBtest relevant
    ncmIDs=$maxFPRPerms
    first_WBtest=1
    last_WBtest=1
    nWBtests=$(( $last_WBtest - $first_WBtest + 1 ))
fi
cm_interval=$(echo "$ncmIDs / ($njobs-1)" | bc) # divy up CMs across jobs; output "floor"-ed 

### Start jobs
for this_WBtest in $(seq $first_WBtest $last_WBtest); do
    for this_job in $(seq $first_job_to_launch $last_job_to_launch); do
        cmID_start=$(echo "($this_job-1) * $cm_interval + 1" | bc)
        cmID_end=$(echo "$this_job * $cm_interval" | bc)
        if [ $this_job == $njobs ]; then
            cmID_end=$ncmIDs
            ncmIDs_lastjob=$(( $cmID_end - $cmID_start + 1 ))
            if [ $ncmIDs_lastjob == 0 ]; then
                last_job_to_launch=$(( $last_job_to_launch-1 ))
                njobs=$(( $njobs - 1 ))
                njobs_in_subset=$(( $last_job_to_launch - $first_job_to_launch ))
                lastjobtext=", no extra jobs needed"
                break
            else
                lastjobtext=", except final job $this_job running $ncmIDs_lastjob CMs"
            fi
        fi

        screen -mdS "clf${this_job}_WBtest${this_WBtest}" sh -c "${ScriptsDirectory}/run_cluster_failure_sim.sh ${setupfile} ${cmID_start} ${cmID_end} ${this_WBtest} " #; exec bash"

    done
done

printf "Processes started. \n Whole-brain tests $first_WBtest to $last_WBtest launched \n Simulations to be run across $njobs jobs. \n Currently running this subset of jobs: $first_job_to_launch to $last_job_to_launch ($cm_interval CMs per job$lastjobtext) \n"  

# Wait for all jobs to start running
printf "Waiting..."
while (( $( wc -l < $tracking_file ) < $(echo "$njobs_in_subset * $nWBtests" | bc) )); do
    printf "..."
    sleep 1
done

# Check whether any jobs already in progress or completed; if so, delete, resume, or stop
# corresponds w line 188 of fsl perm script
if [ $( grep "In progress or completed" "$tracking_file" | wc -l ) -gt 0 ]; then

    printf "\n\n--- The following directories are already in progress or completed: --- \n"
    grep "In progress or completed" "$tracking_file" | cut -d\  -f5

    read -rep $'\nEnter \"delete all previous data\" to delete all previously created data for these jobs and start again, \"resume from previous process\" to resume these jobs from previous states, and any other character to stop these jobs.\n? ' response

    # parse user response
    if [[ "$response" =~ "delete all previous data" ]]; then
        printf "Okay, deleting previously created data for these jobs.\n" 
        cmd_for_exists="y"
    elif [[ "$response" =~ "resume from previous process" ]]; then
        printf "Okay, resuming these jobs from their previous states.\n" 
        cmd_for_exists="r"
    else
        printf "Okay, stopping these jobs.\n"
        cmd_for_exists="n"
    fi

    # send user command to each session
    for this_WBtest in $(seq $first_WBtest $last_WBtest); do
        for this_job in $(seq $first_job_to_launch $last_job_to_launch); do
            screen -S "clf${this_job}_WBtest${this_WBtest}" -p 0 -X stuff "${cmd_for_exists}"
        done
    done

else # only a subset or none already exist

    printf "All specified jobs are safely running. \n"
    head -n 1 "$tracking_file"
fi

#rm "$tracking_file"
