# 03-prior-sensitivity

How much does optimized design depend on prior bias and prior width?
Its output feeds Figure S1 (`04-manuscript-figures/figures-3-S1.R`); there is
no separate plotting script.

| File | Role |
|---|---|
| `prior-functions.R` | `one_test_fit()` (same as in `02-factorial-test/`) and `one_combo_fits()` (100 paired fits for one input row) |
| `prior-cluster.sh` | SLURM array (9 jobs × 15 rows, 4 cores, < 90 min each); writes `target-ace-test-XX.csv` |

## Design

- Fixed truth: *b* = 0.5, `n_temps = 7`, `n_reps = 5`, `obs_cv = 0.2`.
- Grid (135 combinations):
  - `err_mult` (0.5, 1, 1.5, 2, 3) multiplies the default prior half-widths
    passed to `design_temps()` (`ctmin_err` 2.5, `ctmax_err` 1.5,
    `logb_err` 0.26).
  - Prior offsets: CTmin −2.5, 0, or +2.5; CTmax −1.5, 0, or +1.5; log *b*
    −0.26, 0, or +0.26 (each = −1, 0, or +1 × the default half-width).
- 100 fits per method per combination; `design_temps()` re-runs for each fit.
- Window for both methods: offset CTmin − 5 to offset CTmax + 5.

## Output

`data/prior-sensitivity/target-ace-test-01.csv` … `-09.csv`.
Columns: `combo`, `rep`, `method`, `err_mult`, `ctmin_eps`, `ctmax_eps`,
`logb_eps`, `ctmin`, `ctmax`, `a`, `b`, `Topt`, `converged`, `rmse`.
`method` values are as in `02-factorial-test/`.
