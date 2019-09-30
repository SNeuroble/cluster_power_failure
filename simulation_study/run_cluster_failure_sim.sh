#!/bin/bash
#set +x
#########################################################################################
# Usage: run_cluster_failure_sim.sh cfg.sh <first_cmID> <last_cmID> <WB_test_number>
# Randomly permute subjects into two groups and perform group contrast test (FPR).
# Optionally add activation to one group before testing (TPR).
#########################################################################################

# Setup
clear
[[ ! -z $1 && -f $1 ]] && source $1 || { echo "Error: Config file needed." ; exit 1 ; }
[[ ! -z "$2" ]] && cmID_start__reffile=$2 || cmID_start__reffile=1
[ "$doTPR" = "true" ] && ncmIDs=$(wc -l < $cmID_file ) || ncmIDs=$maxFPRPerms
[[ ! -z "$3" ]] && cmID_end__reffile=$3 || cmID_end__reffile=${ncmIDs}
[[ ! -z "$4" ]] && WBtest_number=$4 || WBtest_number=1

. $ScriptsDirectory/setup.sh

# Process - random subsets
printf "\n+++ Processing data subsets +++\n"
for this_cmID in $(seq $cmID_start__locfile $cmID_end__locfile); do

    this_perm=$(echo " scale=0; $this_perm + 1" | bc)
    this_cmID__reffile=$(echo "$this_cmID + $cmID_start__reffile - 1 " | bc)

    printf "\n_____________________________________________________________________" >> ${logfile} 
    printf "\nStarting random group permutation $this_perm (CM $this_cmID__reffile (line $this_cmID), WB Test ($WBtest_number)!" | tee -a ${logfile}
    printf "\n${effectdescrip}\n" | tee -a ${logfile}

    Randomized=`cat ${PermutationsDirectory}/permutation${this_perm}.txt`

    # get group results, then check whether found stuff
    . $ScriptsDirectory/do_second_level__randomise.sh >> $logfile
    . $ScriptsDirectory/get_activations.sh >> $logfile

    # summarize and clean up
    . $ScriptsDirectory/report_results.sh

    if [ -f $ResultsDirectory/${this_perm}${Effect}_tstat1.nii.gz ]; then
        rm $ResultsDirectory/${this_perm}${Effect}*
    fi
    if [ ! -z "$(ls -A ${SubjectActivationsDirectory})" ]; then
        rm ${SubjectActivationsDirectory}/*
    fi
done

printf "\n+++ Finished - $this_perm permutations complete.\n"
