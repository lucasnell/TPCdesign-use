# Use and testing of TPCdesign — project context

<!--
CLAUDE.md is loaded automatically at the start of every session in this folder. It is the
single highest-leverage file in the whole setup, and the most common way to get it wrong is
to let it drift into a status report.

What belongs here: things that stay true. The system, the data, the people, the constraints,
the conventions, the decisions you do not want relitigated.

What does not belong here: what you are doing this week (TODO.md), what happened last session
(handoff.md), or anything you will have to remember to delete.

Keep it under roughly two pages. Past that, the parts that matter compete with the parts that
do not, and you stop reading it yourself.
-->

## Project

- **Code:** TPCdesign-use
- **Full name:** Lucas A. Nell
- **My role:** co-author and analyst
- **Question:** How does R package TPCdesign work to more generate more effective sample temperatures for estimating thermal performance curves (TPCs)?

## People

| Who | Role | What they own |
|---|---|---|
| Lucas A. Nell | co-author, analyst | Code |
| Kelsey Lyberger | co-author, analyst | Code |

## Where things live

- **Data:** `data/` — all derived (simulation output, figure summary tables,
  Figure 2 run cache). Only `data/README.md` and `data/.gitignore` are
  in git; `data/README.md` lists every expected file; regenerate with
  the cluster scripts and `03-manuscript-figures/`.
- **Code:** this repo, https://github.com/lucasnell/TPCdesign-use (branch
  `main`). The package under test is https://github.com/lucasnell/TPCdesign.
- **Figures:** `figures/` — plots only (PDF, PNG; not in git).

## How this project works

- One folder per experiment: `01-factorial-test/` and
  `02-prior-sensitivity/`, plus `03-manuscript-figures/`.
  Each has a README; the top-level `README.md` gives the shared simulation
  setup and layout. Update the relevant README whenever a script's inputs,
  outputs, or design changes.
- Experiment folders pair `*-functions.R` (sourced) with `*-cluster.sh`
  (SLURM array job on Cornell BioHPC; runs from its own remote directory).
  CSVs are copied back into `data/<experiment>/`. Output file names
  (`big-ace-test-XX`, `target-ace-test-XX`) predate the
  folder names and are kept so they match what the cluster writes.
- Local scripts run from the project root. `R/preamble.R` is sourced by the
  `*-plots.R` scripts.
- Data files never go in `figures/`; tables and caches go in `data/`.
- `figure-2.R` Panel A re-simulates (~400 runs, ~4 s each when the machine
  stays awake) and caches to `data/figure-2-cache/`; it refuses a cache built
  from different inputs, package versions, or design function.
- `figure-2.R` and `figures-3-S1.R` were written by a co-author in a different
  style (base R, 2-space indent); keep edits to them minimal.


## Decisions that are settled

<!-- The highest-value section, and the one most often skipped. When a choice gets made,
record it with the date and the reason. A year later the reason is the only part that
matters, and it is always the part nobody wrote down.

Keep settled decisions here so they stop being reopened; keep open questions in TODO.md. -->

- **2026-10-19 —** Repo organised one folder per experiment, with a README in each.
- **2026-10-19 —** Figure 2A uses `TPCdesign::design_temps()` (needs ≥ 1.0.1,
  for `min_temp`/`max_temp`) and `TPCdesign::briere2_tpc()`, not local
  copies. So all figures come from one implementation.
- **2026-10-19 —** Figure summary CSVs and caches live in `data/`; `figures/`
  holds plots only. PDFs and PNGs in `figures/` are not tracked.
- **2026-10-20 —** `design_temps()` keeps drawing ACE starting temperatures
  from [CTmin + `min_sep`, CTmax − `min_sep`], not the whole window. Starts
  across the whole window give non-finite utilities; ACE can still move to
  any temperature in the window, and `checks/design-start-range.R`
  (removed; last in commit `7e701d8`) found the same final designs and
  utilities from both start ranges. The lack of optimized temperatures near
  CTmin comes from the utility, not the starts.
- **2026-10-20 —** Removed the `design_temps()` tuning simulations (former
  `01-tuning/`; last in commit `7e701d8`). They predated the temperature-window
  change and the paper does not cite them.
- **2026-10-20 —** Figures use TPCdesign 1.0.2; the cluster simulations
  (2026-09-28) used 1.0.1. 1.0.2 differs from 1.0.1
  only in documentation, comments, tests, and an unreachable branch
  commented out in `tpc_pace()`, so results are identical.

## Working notes

- Current status: `PROJECT_INDEX.md`
- Live work: `TODO.md`
