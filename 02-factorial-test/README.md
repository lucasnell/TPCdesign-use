# 02-factorial-test

Optimized vs. equal-spaced temperatures across a full factorial of experiment
sizes, curve shapes, and noise levels.
Its output feeds Figures 2 and 3 (`04-manuscript-figures/`).

| File | Role |
|---|---|
| `factorial-functions.R` | `one_test_fit()` (simulate → fit → estimates and RMSE) and `one_combo_fits()` (100 paired fits for one input row) |
| `factorial-cluster.sh` | SLURM array (36 jobs × 16 rows, 4 cores, < 90 min each); writes `big-ace-test-XX.csv` |
| `factorial-plots.R` | Local, exploratory; reads `data/factorial-test/` |

## Design

- Grid: `n_temps` 5–10 × `n_reps` 3–10 × true *b* (0.2, 0.5, 1, 2) ×
  `obs_cv` (0.1, 0.2, 0.4) = 576 combinations.
- Per combination: 10 prior-offset sets (optimum Latin hypercube; CTmin
  offset in [−5, 5], CTmax offset in [−3, 3], log *b* offset in
  [−0.52, 0.52]) × 10 fits = 100 fits per method.
- Each fit re-runs `design_temps()` with the offset priors and package
  defaults for all other arguments.
- Window for both methods: offset CTmin − 5 to offset CTmax + 5.

## Output

`data/factorial-test/big-ace-test-01.csv` … `-36.csv`.
Columns: `combo`, `rep`, `method`, `n_temps`, `n_reps`, `obs_cv`, `ctmin`,
`ctmax`, `a`, `b`, `Topt`, `converged`, `rmse`, `ctmin_eps`, `ctmax_eps`,
`logb_eps`.

- `method = "design"` or `"uniform"`: parameter columns are fitted estimates.
- `method = "real"`: one row per `combo` holding the true parameters (`rep` is
  `NA`).

## Plots

`factorial-plots.R` prints the share of grid cells where optimized RMSE is
below equal-spaced RMSE, overall and by *b*, and builds:

- `rel_p`: log₂(optimized / equal-spaced mean RMSE) over `n_temps` ×
  `n_reps`, faceted by *b* and `obs_cv`.
- `val_p`: mean RMSE for each method at *b* = 1, `obs_cv` = 0.1.

The commented-out `ggsave()` calls write `figures/rel-ace.pdf` and
`figures/rel-val-ace.pdf`.
