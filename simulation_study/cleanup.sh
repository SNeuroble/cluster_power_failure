#!/bin/bash

#[[ ! -z $1 && -f $1 ]] && source $1 || { echo "Error: Config file needed." ; exit 1 ; }
#cd ${ResultsDirectory}
#cd ..

cd $1
find . -name "all_subjects*.nii.gz" -exec sh -c 'rm {}' \;
printf "Done cleaning up $1 . \n"
