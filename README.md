# TPCdesign-use

Simulations testing whether temperatures chosen by the R package
[TPCdesign](https://github.com/lucasnell/TPCdesign) estimate thermal performance
curves (TPCs) better than equally spaced temperatures.

Authors: Lucas A. Nell and Kelsey Lyberger.

## Shared setup

Every simulation uses the Brière-2 TPC,
`y = a · T · (T − CTmin) · (CTmax − T)^b` (zero outside CTmin < T < CTmax), with
true `CTmin = 5`, `CTmax = 40`, and `a = 1`.
One simulated experiment proceeds as follows:

1. Choose temperatures, either with `TPCdesign::design_temps()` ("design" or
   "optimized") or as an equally spaced sequence over the same window
   ("uniform" or "equal-spaced").
   `design_temps()` is given CTmin, CTmax, and *b* values that can be offset
   from the truth, to mimic imperfect prior knowledge.
2. Simulate `n_reps` observations per temperature with
   `TPCdesign::sim_gamma_data()` (gamma-distributed noise with coefficient of
   variation `obs_cv`).
3. Fit the Brière-2 curve with `nls.multstart::nls_multstart()` (500 starts;
   `a` and `b` fit on the log scale).
4. Score the fit by RMSE between fitted and true curves on 101 temperatures
   from true CTmin to true CTmax.

## Layout

| Folder | Contents | Output |
|---|---|---|
| `R/` | `preamble.R`: packages, ggplot theme, and device options for local scripts | — |
| `01-tuning/` | Tuning `design_temps()` arguments (`min_sep`, `n_filler`, `n_draws`, `n_starts`) | `data/tuning/` |
| `02-factorial-test/` | Optimized vs. equal-spaced across number of temperatures, replicates, *b*, and noise | `data/factorial-test/` |
| `03-prior-sensitivity/` | Optimized vs. equal-spaced when priors are biased or too narrow/wide | `data/prior-sensitivity/` |
| `04-manuscript-figures/` | Figures 2, 3, and S1 | `figures/`, `data/figure-summaries/`, `data/figure-2-cache/` |
| `data/` | Simulation output, figure summary tables, and the Figure 2 run cache (not in git) | — |
| `figures/` | Saved plots only (PDFs and PNGs not in git) | — |

Each numbered folder has its own README.

## Running

Simulations in `01`–`03` run as SLURM array jobs on Cornell BioHPC.
Each folder has a `*-functions.R` file and a `*-cluster.sh` script that sources
it; copy both to the cluster, `sbatch` the shell script, and copy the CSVs back
into `data/`.
The exact `scp` and `sbatch` commands are in comments at the top of each
`*-cluster.sh`.
Cluster scripts run from their own remote directory.

All local scripts (`*-plots.R` and `04-manuscript-figures/*.R`) run from the
project root (open `TPCdesign-use.Rproj`, or `setwd()` to this folder).

`.gitignore` excludes `*.csv`, `*.rds`, `*.pdf`, and `figures/*.png`, so
`data/` contents and figures exist only locally; regenerate them with the
cluster and figure scripts.

## Packages

Local: tidyverse, patchwork, nls.multstart, TPCdesign, ggtext, scico,
acebayes, lhs.
Cluster: additionally future.apply, progressr, and rTPC (loaded but not called).
