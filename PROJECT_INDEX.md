# Use and testing of TPCdesign — index

**Status as of 2026-10-20:** Both simulation sets (factorial test and prior sensitivity)
have run, and Figures 2, 3, and S1 were regenerated from the current code on
2026-10-19 and 2026-10-20. Figure 2A now uses the package's `design_temps()`, so it differs
from the earlier version made with a local copy.

<!-- PROJECT_INDEX.md is the page you hand someone who asks "what is this project and where
is it at". Date the status line every time you touch it; an undated status is worse than
none, because it reads as current. -->

## The question

Does choosing sample temperatures with the R package TPCdesign estimate thermal performance
curves (TPCs) more accurately than equally spaced temperatures, and how robust is that to
experiment size, curve shape, noise, and wrong prior knowledge of the curve?

## Approach

Simulation only. The true curve is Brière-2 (CTmin 5, CTmax 40, a 1). Each simulated
experiment picks temperatures either with `TPCdesign::design_temps()` (ACE optimization under
uniform priors on CTmin, CTmax, and log *b*, possibly offset from the truth) or as an equally
spaced sequence over the same window, simulates gamma-noise data, fits Brière-2 with
`nls.multstart`, and scores whole-curve RMSE. Details per experiment are in each folder's
README.

## Current state

| Workstream | State |
|---|---|
| Factorial test (`01-factorial-test/`) | Output CSVs dated 2026-09-28 |
| Prior sensitivity (`02-prior-sensitivity/`) | Output CSVs dated 2026-09-28 |
| Manuscript figures (`03-manuscript-figures/`) | Figures 2, 3, S1 regenerated 2026-10-19/20 |

## Key links

- Repo: https://github.com/lucasnell/TPCdesign-use
- Package: https://github.com/lucasnell/TPCdesign
- Data: `data/` (local only; regenerated from cluster runs)

## Decision log

<!-- Append-only. Date, decision, reason. Never delete a line; supersede it with a new one,
so the reasoning chain stays readable. -->

| Date | Decision | Why |
|---|---|---|
| 2026-10-19 | One folder per experiment, README in each | Scripts and outputs were hard to map to experiments |
| 2026-10-19 | Figure 2A uses `TPCdesign::design_temps()` and `briere2_tpc()` (TPCdesign ≥ 1.0.1) | All figures from one implementation |
| 2026-10-19 | Tables and caches in `data/`; `figures/` holds plots only, untracked | Keep data out of the figures folder |
| 2026-10-20 | Remove tuning simulations (former `01-tuning/`, last in `7e701d8`) | Out of date; not cited in the paper |
| 2026-10-20 | Keep ACE starts in [CTmin + `min_sep`, CTmax − `min_sep`] | Whole-window starts give non-finite utilities; same final designs either way (`checks/design-start-range.R`, removed; last in `7e701d8`) |
