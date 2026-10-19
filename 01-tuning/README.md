# 01-tuning

Which `design_temps()` settings give the lowest RMSE?

| File | Role |
|---|---|
| `tuning-functions.R` | `one_fit_rmse()` (one design → simulate → fit → RMSE) and `one_combo_fits()` (one input row) |
| `tuning-cluster.sh` | SLURM array (40 jobs, 6 cores, ~2 h each); builds the input grid and writes `ace-tuning-XX.csv` |
| `tuning-plots.R` | Local; reads `data/tuning/`, plots RMSE against `n_filler` by *b* and `n_temps` |

## Design

- 1,000 combinations from a maximin Latin hypercube over
  `n_temps` (5–10), true *b* (0.2, 0.5, 1, 2), `min_sep` (0.5–2),
  `n_filler` (0–3), `n_draws` (50–500), and `n_starts` (5–10).
- Fixed: `n_reps = 6`, `obs_cv = 0.2`.
- 10 prior-offset sets per combination (optimum Latin hypercube):
  CTmin offset in [−5, 5], CTmax offset in [−3, 3], log *b* offset in
  [−0.52, 0.52].
- 10 replicate fits per offset set → 100,000 rows.
- Temperature window: `design_temps()` default (no `min_temp`/`max_temp` passed).

## Output

`data/tuning/ace-tuning-01.csv` … `-40.csv`; one row per fit.
Columns: `combo`, `rep`, the inputs above, true `ctmin`/`ctmax`/`a`,
`ctmin_eps`/`ctmax_eps`/`logb_eps` (prior offsets), and `rmse` (`NA` if the
fit failed).

`tuning-plots.R` saves nothing; its conclusions are in comments in the script.

The CSVs are dated 2026-07-28, before the temperature-window change to the
factorial test (commit `0321bc5`, 2026-09-27).
