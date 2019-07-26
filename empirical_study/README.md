# Cluster Power Failure Project

These scripts were used to estimate sensitivity using resampling of empirical data as described in
"Cluster failure or power failure? Evaluating sensitivity in cluster-level inference" (reference forthcoming).

## Getting Started

### Prerequisites

Linux/Unix
FSL: `https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FslInstallation`

### Overview

> Step 1. Check user-defined parameters in configuration file:

`clf_config_files/cfg.sh`

Parameters include: number of repetitions, task, number of subjects in resampled sample, etc.

> Step 2. Obtain task-relevant first level data and calculate ground truth effect size map.

```shell
$ get_data_and_ground_truth.sh clf_config_files/cfg.sh
```

> Step 3. Perform resampling across multiple jobs.

```shell
$ launch_parallel_processes.sh clf_config_files/cfg.sh
```

> Step 4. Combine resampling results across jobs.

```shell
$ combine_results.sh clf_config_files/cfg.sh
```

## Contact

Please send me a PM on GitHub if you have any questions about the materials provided here. 

