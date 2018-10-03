#!/bin/bash

Filename=$1
nComparisons=$2
nSubs=$3
outputdir=$4

if [ ! -d $outputdir ]; then
    mkdir $outputdir
fi
# Loop over many random group comparisons
for Comparison in $(seq 1 $nComparisons); do
    (($Comparison % 200 == 0)) && echo "Making random permutation $Comparison !"
    shuf -n $nSubs ${Filename} > $outputdir/permutation${Comparison}.txt
done












