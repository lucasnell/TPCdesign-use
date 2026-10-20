#!/bin/bash -l



#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --array=1-9
#SBATCH --cpus-per-task=4
#SBATCH --mem=20G
#SBATCH --time=04:00:00
#SBATCH --job-name=tpc-target
#SBATCH --output=logs/tpc-%a.out
#SBATCH --error=logs/tpc-%a.err
#SBATCH --mail-type=END,FAIL


# IMPORTANT -- SET THIS FOR THE MAX ARRAY NUMBER ABOVE:
# (I'm doing it this way--instead of using existing SLURM_ARRAY_TASK_MAX object--
# so that I can restart a job with just one array index--
# e.g., `sbatch --array=X prior-cluster.sh`--if one job fails for a weird reason)
export MAX_ARRAY_INDEX=9


# IMPORTANT -- SET SEEDS FOR RUNS
# Use `paste(sample.int(.Machine$integer.max, N), collapse = " ")`,
# where N is MAX_ARRAY_INDEX above
export RNG_SEEDS="1379370478 879595397 1778284081 1677274749 477758270 1050856010 1902370391 1475704916 2116279401"


# I first moved this script and its functions file over to bioHPC using the following:
# (replace <BIOHPC_USER> with your BioHPC username in the scp commands below;
# these run on your local machine, where $USER is not your BioHPC username)
#
# cd ~/GitHub/Stanford/TPCdesign-use/02-prior-sensitivity
# scp prior-functions.R prior-cluster.sh biohpc:/home2/<BIOHPC_USER>/tpc/target/
#
# This was then run on BioHPC in a non-interactive batch job started with the following:
#
# cd /home2/$USER/tpc/target/
# mkdir -p logs
# sbatch prior-cluster.sh
#
# Then, when the jobs are done (assuming you're back on your desktop in
# directory `~/GitHub/Stanford/TPCdesign-use/02-prior-sensitivity`):
#
# scp biohpc:/home2/<BIOHPC_USER>/tpc/target/target-ace-test*.csv ../data/prior-sensitivity/
#
#
# To test:
# cd /home2/$USER/tpc/target/
# srun -N 1 -n 1 -c 4 --mem=20G --array=1 --time=2:00:00 --job-name="tpc-target" --pty bash -i
# export MAX_ARRAY_INDEX=9
# export OMP_NUM_THREADS=1
# R --vanilla
#
#


# I don't need OpenMP multithreading:
export OMP_NUM_THREADS=1




Rscript - << EOF

.libPaths("/home/$USER/R/x86_64-pc-linux-gnu-library/4.6")

suppressPackageStartupMessages({
    library(tidyverse)
    library(nls.multstart)
    library(rTPC)
    library(TPCdesign)
    library(acebayes)
    library(lhs)
    library(future.apply)
    library(progressr)
})

n_threads <- as.integer(Sys.getenv("SLURM_CPUS_PER_TASK"))
if (is.na(n_threads)) stop("n_threads cannot be NA")

options("readr.num_threads" = n_threads)
plan(multisession, workers = n_threads)
handlers(handler_cli(format = paste("{cli::pb_bar} {cli::pb_percent} |",
                                        "{cli::pb_elapsed} | ETA: {cli::pb_eta}"),
                         clear = FALSE))


# Contains functions one_combo_fits and one_test_fit
source("prior-functions.R")



input_df <- crossing(err_mult = c(0.5, 1, 1.5, 2, 3),
                     ctmin_eps = formals(design_temps)[["ctmin_err"]] * -1:1,
                     ctmax_eps = formals(design_temps)[["ctmax_err"]] * -1:1,
                     logb_eps = formals(design_temps)[["logb_err"]] * -1:1)




# --------------*
# Read inputs from job manager:

get_inds_seed <- function() {

    curr_idx <- suppressWarnings(as.integer(Sys.getenv("SLURM_ARRAY_TASK_ID")))
    if (is.na(curr_idx)) stop("SLURM_ARRAY_TASK_ID must be an integer")

    max_idx <- suppressWarnings(as.integer(Sys.getenv("MAX_ARRAY_INDEX")))
    if (is.na(max_idx)) stop("MAX_ARRAY_INDEX must be an integer")
    if (curr_idx > max_idx) stop("SLURM_ARRAY_TASK_ID cannot exceed MAX_ARRAY_INDEX")

    # Verify that indices align with 'input_df':
    stopifnot(nrow(input_df) %% max_idx == 0L)

    # number of rows to simulate per job:
    n_rows_pj <- nrow(input_df) %/% max_idx

    # Get indices for this set of simulations:
    curr_start <- (curr_idx - 1L) * n_rows_pj + 1L
    curr_stop <- curr_idx * n_rows_pj
    indices <- curr_start:curr_stop

    # Get seed for this set of simulations:
    seed <- as.integer(strsplit(Sys.getenv("RNG_SEEDS"), " ")[[1]])[curr_idx]

    return(list("curr_idx" = curr_idx, "indices" = indices, "seed" = seed))
}



inds_seed <- get_inds_seed()
curr_idx <- inds_seed[["curr_idx"]]
indices <- inds_seed[["indices"]]
seed <- inds_seed[["seed"]]




# --------------*
# Main simulator function:


all_combo_fits <- function(indices, input_df, .seed) {


    with_progress({
            p <- progressor(length(indices))
            out <- future_lapply(indices,
                         one_combo_fits,
                         input_df = input_df,
                         .parent_prog = p,
                         future.seed = .seed,
                         future.globals = c("one_combo_fits",
                                            "one_test_fit"),
                         future.packages = c("tidyverse",
                                             "nls.multstart",
                                             "TPCdesign",
                                             "acebayes",
                                             "lhs")) |>
                list_rbind()
    })


    return(out)
}


# Took < 90 min per job, where each job processed 15 rows using 4 threads

cat("Starting simulations...\n")
t0 <- Sys.time()
out_df <- all_combo_fits(indices, input_df, seed)
t1 <- Sys.time()
difftime(t1, t0, units = "min")

# --------------*


cat("Writing output...\n")


write_csv(out_df, sprintf("target-ace-test-%02i.csv", curr_idx))



cat("\nFINISHED!!\n\n")



EOF
