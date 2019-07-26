#!/bin/bash
###################################################################### 
#
# This script is part of the Cluster Power Failure project 
#
# Details: Performs inference on resampled data
# Usage: run_hcp_cluster_failure.sh cfg.sh <first perm> <last perm>
#
######################################################################


############## SETUP ##############

clear
[[ ! -z $1 && -f $1 ]] && source $1 || { echo "Error: Config file needed." ; exit 1 ; }
[[ ! -z "$2" ]] && first_perm=$2 || first_perm=1
[[ ! -z "$3" ]] && last_perm=$3 || last_perm=${nPermutations}

. $scriptsDir/setup.sh


############## ANALYZE RESAMPLED DATA ##############

printf "\n+++ Processing data subsets +++\n"
for perm in $(seq $first_perm $last_perm); do

    printf "Permutation ${perm} " | tee -a $logfile
    subNames_subset=$subjectRandomizations/perm$perm

    # Get group results, then check accumulate positives
    . $scriptsDir/do_second_level__randomise.sh >> $logfile 
    . $scriptsDir/calc_true_positives.sh >> $logfile

    # Clean up
    #[[ -d "$permOutputsDir" ]] && rm -r "$permOutputsDir/*"
done

printf "\n+++ Finished - $perm permutations complete.\n"

