#!/bin/bash
#########################################################################################
# Usage: ./hcpTask/run_hcp_cluster_power_failure.sh ~/hcpTask/cfg.sh <1> <2>
# Must provide config file (e.g., cfg.sh)
# Make sure instance meets memory requirements
# Run combine_results.sh when finished to combine across perms
#########################################################################################

# Setup
clear
[[ ! -z $1 && -f $1 ]] && source $1 || { echo "Error: Config file needed." ; exit 1 ; }
[[ ! -z "$2" ]] && first_perm=$2 || first_perm=1
[[ ! -z "$3" ]] && last_perm=$3 || last_perm=${nPermutations}

. $scriptsDir/setup.sh

# Process - random subsets
printf "\n+++ Processing data subsets +++\n"
for perm in $(seq $first_perm $last_perm); do

    printf "Permutation ${perm} " | tee -a $logfile
    subNames_subset=$subjectRandomizations/perm$perm

    # get group results, then check whether found stuff
    . $scriptsDir/do_second_level__randomise.sh >> $logfile 
    . $scriptsDir/calc_true_positives.sh >> $logfile

    # clean up
    [[ -d "$permOutputsDir" ]] && rm -r "$permOutputsDir/*"
done

printf "\n+++ Finished - $perm permutations complete.\n"

