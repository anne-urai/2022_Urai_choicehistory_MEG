#!/bin/bash

# https://wiki.alice.universiteitleiden.nl/index.php?title=Your_first_GPU_job
#SBATCH --output /home/uraiae/jobs/hddmnn_fit-%A_%a.out
#SBATCH --mail-user=a.e.urai@fsw.leidenuniv.nl # mail when done
#SBATCH --mail-type=END,FAIL # mail when done
#SBATCH --time=5-00:00:00 # one day to fit
#SBATCH --partition=gpu-long
#SBATCH --ntasks=1 # submit one job per task
#SBATCH --gpus=1
#SBATCH --cpus-per-gpu=6
#SBATCH --mem-per-gpu=90G

# load necessary modules
module load Miniconda3/4.9.2
source activate hddmnn_env2  # for all installed packages (hddm_env gives a kabuki bug for some reason)
# export PYTHONUNBUFFERED=TRUE # use -u to continually show output in logfile (unbuffered, bad when writing to home or data)
# conda list # check that MPL is there

# are we using the GPU?
echo "[$SHELL] Starting at "$(date)
echo "[$SHELL] Using GPU: "$CUDA_VISIBLE_DEVICES
echo "[$SHELL] Conda env: "$CONDA_DEFAULT_ENV

# Actually run the file with input args, only one trace_id for now
python /home/uraiae/code/MEG/hddmnn_fit.py -d $1 -m $2 -i 0

# Wrap up
echo "[$SHELL] Finished at "$(date)
