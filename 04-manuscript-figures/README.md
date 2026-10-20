# 04-manuscript-figures

Run from the project root.
Both scripts check row counts with `stopifnot()` and stop if the input CSVs
are incomplete.

## `figure-2.R` → Figure 2

Inputs: `data/factorial-test/`.
Outputs: `figures/Figure_2.{png,pdf}`,
`data/figure-summaries/Figure_2B_summary.csv`, and a run cache in
`data/figure-2-cache/`.

- **Panel A** (example fits and RMSE boxplots) re-simulates rather than
  reading stored fits.
  It takes the 200 `design` rows with `n_temps = 6`, `n_reps = 5`,
  `obs_cv = 0.2`, and *b* = 0.2 or 2, and reruns each with a fresh design,
  `min_sep = 2`, and `n_filler = 1`.
  - Example curves use one shared prior offset (the set closest to zero
    offset); boxplots use each row's own offsets.
  - Example fits are the ones nearest the 75th percentile of raw RMSE;
    boxplots show RMSE after scaling each curve to a peak of 1.
  - Slow. Each run is cached as `data/figure-2-cache/{shared,varying}/run_XXX.rds`;
    the script stops if the cached inputs or package versions differ from
    the current ones. Delete the cache folder to rerun.
- **Panel B**: log₂(optimized / equal-spaced) median absolute error in CTmin,
  T<sub>opt</sub>, and CTmax, at `obs_cv = 0.2` and `n_reps = 5`, by
  `n_temps` and *b*, from the stored factorial-test fits.

Panel A designs come from `TPCdesign::design_temps()` with
`min_temp = CTmin − 5` and `max_temp = CTmax + 5` (offset priors), which needs
TPCdesign ≥ 1.0.1.

## `figures-3-S1.R` → Figures 3 and S1

Inputs: `data/factorial-test/` and `data/prior-sensitivity/`.
Outputs: `figures/Figure_3.{png,pdf}` and `figures/Figure_S1.{png,pdf}`;
`Figure_3_summary.csv`, `Figure_S1A_summary.csv`, and
`Figure_S1B_summary.csv` in `data/figure-summaries/`.
Runs in a few seconds.

- **Figure 3**: mean RMSE over `n_temps` × `n_reps` for each method, plus
  log₂(optimized / equal-spaced), at *b* = 0.5 and `obs_cv = 0.2`.
  The script stops if any cell's ratio is above 0.
- **Figure S1A**: log₂ mean-RMSE ratio for 7 of the 27 prior-offset
  combinations (unbiased; limits too cold, too warm, too wide, or too narrow;
  *b* under- or overestimated) × `err_mult`.
- **Figure S1B**: mean RMSE by method against `err_mult`, pooled over all
  offsets.
