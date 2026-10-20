# Figure 2

# Run once if needed:
# install.packages(c("dplyr", "tidyr", "ggplot2", "patchwork", "acebayes", "lhs", "nls.multstart", "remotes"))
# remotes::install_github("lucasnell/TPCdesign")
library(TPCdesign)
library(dplyr)
library(tidyr)
library(ggplot2)
library(patchwork)
library(acebayes)
library(lhs)
library(nls.multstart)

# Run from the project root (TPCdesign-use/).
data_dir <- "data/factorial-test"
output_dir <- "figures"
summary_dir <- "data/figure-summaries"
dir.create(summary_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

# Read the results, keeping file names because combo IDs can repeat between files.
big_files <- list.files(data_dir, "^big-ace-test.*\\.csv$", full.names = TRUE) |> sort()
if (length(big_files) == 0) stop("No big-ace-test CSVs found. Check data_dir: ", data_dir)
ace <- bind_rows(lapply(big_files, function(f) {
  x <- read.csv(f)
  if (!"method" %in% names(x)) stop("Missing method column in ", f)
  x$source_file <- basename(f)
  x
}))

truth <- ace |> filter(method == "real") |>
  select(source_file, combo, true_ctmin = ctmin, true_ctmax = ctmax, true_Topt = Topt, true_b = b)
stopifnot(!anyDuplicated(truth[c("source_file", "combo")]))

# Function for selecting temperatures and fitting simulated observations

simulate_pair <- function(j, jobs) {
  z <- jobs[j, ]
  seed <- 20260929L + j * 100L
  set.seed(seed)
  shape <- ifelse(z$true_b == 2, "Near-symmetric", "Severe skew")
  tmin <- 5 + z$ctmin_eps
  tmax <- 40 + z$ctmax_eps
  pb <- z$true_b * exp(z$logb_eps)
  temps <- list(Optimized = design_temps(6L, tmin, tmax, 1, pb,
    min_temp = tmin - 5, max_temp = tmax + 5, min_sep = 2),
    `Equal-spaced` = round(seq(tmin - 5, tmax + 5, length.out = 6), 2))
  stopifnot(all(vapply(temps, length, integer(1)) == 6),
    min(diff(sort(temps$Optimized))) >= 1.99,
    all(unlist(temps) >= tmin - 5 - .0051), all(unlist(temps) <= tmax + 5 + .0051))
  fits <- list()
  designs <- list()
  observations <- list()
  for (m in names(temps)) {
    obs <- sim_gamma_data(temps[[m]], 5L, .2, 5, 40, 1, z$true_b)
    fit <- tryCatch(nls_multstart(y ~ exp(a) * temp * pmax(temp - ctmin, 0) * pmax(ctmax - temp, 0)^exp(b),
      data = obs, start_lower = c(a = log(1e-6), ctmin = -5, ctmax = 30, b = log(.01)),
      start_upper = c(a = log(2), ctmin = 15, ctmax = 50, b = log(3)), iter = 500, supp_errors = "Y",
      control = list(maxfev = 5e3, maxiter = 1e3)), error = function(e) NULL)
    co <- c(ctmin = NA, ctmax = NA, a = NA, b = NA)
    conv <- FALSE
    rmse <- NA_real_
    if (!is.null(fit)) {
      co <- coef(fit)
      co[c("a", "b")] <- exp(co[c("a", "b")])
      conv <- isTRUE(fit$convInfo$isConv)
      grid <- seq(5, 40, length.out = 101)
      rmse <- sqrt(mean((briere2_tpc(grid, co['ctmin'], co['ctmax'], co['a'], co['b'])-
      briere2_tpc(grid, 5, 40, 1, z$true_b))^2))
    }
    meta <- data.frame(run_id = j, shape = shape, b = z$true_b, method = m, simulation = z$rep, seed = seed,
      source_file = z$source_file, combo = z$combo, n_temps = 6, n_reps = 5, obs_cv = .2,
      ctmin_eps = z$ctmin_eps, ctmax_eps = z$ctmax_eps, logb_eps = z$logb_eps,
      min_sep = 2, window_min = tmin - 5, window_max = tmax + 5, err_mult = 1)
    fits[[m]] <- cbind(meta, data.frame(fit_ctmin = unname(co['ctmin']), fit_ctmax = unname(co['ctmax']),
      fit_a = unname(co['a']), fit_b = unname(co['b']), converged = conv, rmse = rmse))
    designs[[m]] <- cbind(meta[rep(1, 6), ], treatment = 1:6, temperature = temps[[m]])
    observations[[m]] <- cbind(meta[rep(1, nrow(obs)), ], obs)
  }
  list(fits = bind_rows(fits), designs = bind_rows(designs), observations = bind_rows(observations))
}

curve_max_height <- function(ctmin, ctmax, a, b) {
  if (!all(is.finite(c(ctmin, ctmax, a, b))) || ctmax <= ctmin) return(NA_real_)
  temp <- seq(ctmin, ctmax, length.out = 2001)
  max(briere2_tpc(temp, ctmin, ctmax, a, b, scale = FALSE), na.rm = TRUE)
}

height_normalized_rmse <- function(fit_ctmin, fit_ctmax, fit_a, fit_b,
  true_b) {
  test_temps <- seq(5, 40, length.out = 501)
  pred_max <- curve_max_height(fit_ctmin, fit_ctmax, fit_a, fit_b)
  truth_max <- curve_max_height(5, 40, 1, true_b)
  if (!is.finite(pred_max) || pred_max <= 0 ||
  !is.finite(truth_max) || truth_max <= 0) {
    return(NA_real_)
  }
  pred <- briere2_tpc(test_temps, fit_ctmin, fit_ctmax, fit_a, fit_b, scale = FALSE) / pred_max
  truth <- briere2_tpc(test_temps, 5, 40, 1, true_b, scale = FALSE) / truth_max
  sqrt(mean((pred - truth)^2))
}

# Simulations for panel A (slow; completed runs are saved so this can resume)
# Example curves use shared prior offsets; boxplots use varying prior offsets.

jobs <- ace |> filter(method == "design", n_temps == 6, n_reps == 5, obs_cv == .2) |>
  left_join(truth, by = c("source_file", "combo"), relationship = "many-to-one") |>
  filter(true_b %in% c(.2, 2)) |> arrange(desc(true_b), rep)
stopifnot(nrow(jobs) == 200, !anyDuplicated(jobs[c("source_file", "combo", "rep")]))
shared <- jobs |> distinct(ctmin_eps, ctmax_eps, logb_eps) |>
  mutate(distance = (ctmin_eps / 2.5)^2 + (ctmax_eps / 1.5)^2 + (logb_eps / .26)^2) |>
  arrange(distance, ctmin_eps, ctmax_eps, logb_eps) |> slice(1)
ensembles <- list()
for (mode in c("shared", "varying")) {
  inputs <- jobs
  if (mode == "shared")
  for (k in c("ctmin_eps", "ctmax_eps", "logb_eps")) inputs[[k]] <- shared[[k]]
  cache_dir <- file.path("data", "figure-2-cache", mode)
  dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  # Refuse stale caches after input or package changes.
  signature <- list(inputs = as.data.frame(inputs),
    design_fun = "TPCdesign::design_temps",
    versions = vapply(c("TPCdesign", "acebayes", "lhs", "nls.multstart"),
    function(p) as.character(packageVersion(p)), ""))
  manifest <- file.path(cache_dir, "inputs.rds")
  if (file.exists(manifest) && !identical(readRDS(manifest), signature))
  stop("Cache inputs or package versions changed. Remove ", cache_dir, " and rerun.")
  saveRDS(signature, manifest)
  runs <- lapply(seq_len(nrow(inputs)), function(j) {
    path <- file.path(cache_dir, sprintf("run_%03d.rds", j))
    if (!file.exists(path)) saveRDS(simulate_pair(j, inputs), path)
    if (j %% 10 == 0) message("Figure 2A: ", mode, " ", j, "/", nrow(inputs))
    readRDS(path)
  })
  ensembles[[mode]] <- lapply(c("fits", "designs"), function(nm)
  bind_rows(lapply(runs, `[[`, nm))) |> setNames(c("fits", "designs"))
}

# Plot Figure 2
# Example fits are selected near the 75th percentile of raw RMSE.
# Boxplots show height-normalized RMSE; panel B uses median absolute error.

set.seed(20260928)
shape_levels <- c("Near-symmetric", "Severe skew")
simulation_df <- ensembles$shared$fits
simulation_df$shape <- factor(simulation_df$shape, levels = shape_levels)
simulation_df$method <- factor(simulation_df$method, levels = c("Equal-spaced", "Optimized"))
simulation_df$raw_rmse <- simulation_df$rmse
simulation_df$rmse <- mapply(
  height_normalized_rmse,
  simulation_df$fit_ctmin,
  simulation_df$fit_ctmax,
  simulation_df$fit_a,
  simulation_df$fit_b,
  simulation_df$b
)


representative_fits <- do.call(rbind, lapply(shape_levels, function(s) {
  do.call(rbind, lapply(levels(simulation_df$method), function(m) {
    candidates <- simulation_df[as.character(simulation_df$shape) == s &
    as.character(simulation_df$method) == m &
    is.finite(simulation_df$rmse) & is.finite(simulation_df$raw_rmse), , drop = FALSE]
    target_rmse <- as.numeric(quantile(candidates$raw_rmse, probs = 0.75, na.rm = TRUE))
    candidates$q75_rmse <- target_rmse
    candidates$q75_distance <- abs(candidates$raw_rmse - target_rmse)
    candidates <- candidates[order(candidates$q75_distance, candidates$raw_rmse), , drop = FALSE]
    candidates[1L, , drop = FALSE]
  }))
}))
all_designs <- ensembles$shared$designs
selected_designs <- all_designs |>
  semi_join(representative_fits |> select(run_id, method), by = c("run_id", "method"))
plot_min_temp <- min(0, floor(min(selected_designs$temperature) - 5))
plot_max_temp <- max(43, ceiling(max(selected_designs$temperature) + 1))
curve_grid <- seq(plot_min_temp, plot_max_temp, length.out = 900)

curve_df <- do.call(rbind, lapply(shape_levels, function(s) {
  b <- unique(simulation_df$b[simulation_df$shape == s])
  temp <- curve_grid
  data.frame(shape = s, b = b, temp = temp,
    performance = briere2_tpc(temp, 5, 40, 1, b, scale = TRUE))
}))
fit_curve_df <- do.call(rbind, lapply(seq_len(nrow(representative_fits)), function(i) {
  z <- representative_fits[i, ]
  data.frame(shape = z$shape, b = z$b, method = z$method, temp = curve_grid,
    performance = briere2_tpc(curve_grid, z$fit_ctmin, z$fit_ctmax,
    z$fit_a, z$fit_b, scale = TRUE),
    simulation = z$simulation, rmse = z$rmse)
}))
performance_upper <- max(1.25, curve_df$performance, fit_curve_df$performance, na.rm = TRUE) * 1.06
design_df <- selected_designs
stopifnot(nrow(design_df) == 24, all(table(design_df$shape, design_df$method) == 6))
colors <- c("Equal-spaced" = "#0072B2", "Optimized" = "#D55E00")

# Boxplots use the separate varying-prior simulations, as in the manuscript.
boxplot_df <- ensembles$varying$fits
boxplot_df$shape <- factor(boxplot_df$shape, levels = shape_levels)
boxplot_df$method <- factor(boxplot_df$method, levels = c("Equal-spaced", "Optimized"))
boxplot_df$raw_rmse <- boxplot_df$rmse
boxplot_df$rmse <- mapply(height_normalized_rmse, boxplot_df$fit_ctmin,
  boxplot_df$fit_ctmax, boxplot_df$fit_a, boxplot_df$fit_b, boxplot_df$b)
stopifnot(nrow(boxplot_df) == 400)

row_plots <- lapply(shape_levels, function(s) {
  dd <- design_df[design_df$shape == s, ]
  cc <- curve_df[curve_df$shape == s, ]
  ff <- fit_curve_df[fit_curve_df$shape == s, ]
  ss <- boxplot_df[boxplot_df$shape == s &
  is.finite(boxplot_df$rmse) &
  boxplot_df$rmse > 0, ]
  right_ylim <- range(c(0, ss$rmse), finite = TRUE)
  b_lab <- unique(ss$b)
  left <- ggplot(cc, aes(temp, performance)) +
    geom_line(aes(color = "True", linetype = "True"), linewidth = 1) +
    geom_line(data = ff, aes(temp, performance, color = method, linetype = method),
    linewidth = 0.9) +
    geom_point(data = dd,
    aes(temperature, ifelse(method == "Optimized", -0.06, -0.14),
    color = method), size = 2.3, show.legend = FALSE) +
    scale_color_manual(values = c("True" = "black", colors),
    breaks = c("True", "Equal-spaced", "Optimized")) +
    scale_linetype_manual(values = c("True" = "solid", "Equal-spaced" = "dashed",
    "Optimized" = "longdash"),
    breaks = c("True", "Equal-spaced", "Optimized")) +
    guides(color = guide_legend(nrow = 1, byrow = TRUE),
    linetype = guide_legend(nrow = 1, byrow = TRUE)) +
    scale_x_continuous(breaks = seq(0, ceiling(plot_max_temp / 10) * 10, by = 10)) +
    coord_cartesian(xlim = c(plot_min_temp, plot_max_temp),
    ylim = c(-0.19, performance_upper), clip = "off") +
    labs(title = sprintf("%s (b = %s)", s, format(b_lab)),
    x = if (s == shape_levels[2]) "Temperature (°C)" else NULL, y = "Scaled performance") +
    theme_classic(base_size = 13) +
    theme(legend.position = if (s == shape_levels[1]) "inside" else "none",
    legend.position.inside = c(0.50, 0.92),
    legend.title = element_blank(),
    legend.background = element_rect(fill = "white", color = NA),
    legend.key.width = grid::unit(1.2, "lines"))
  right <- ggplot(ss, aes(method, rmse, fill = method)) +
    geom_boxplot(width = 0.62, outlier.shape = NA, linewidth = 0.45,
    alpha = 0.32) +
    geom_jitter(aes(color = method), width = 0.12, height = 0,
    size = 1.25, alpha = 0.62, show.legend = FALSE) +
    scale_fill_manual(values = colors) +
    scale_color_manual(values = colors) +
    coord_cartesian(ylim = right_ylim) +
    labs(x = NULL, y = "Whole-curve RMSE") +
    theme_classic(base_size = 13) +
    theme(legend.position = "none", axis.text.x = element_text(angle = 18, hjust = 1))
  if (s == shape_levels[1]) left <- left + labs(tag = "A") + theme(plot.tag = element_text(face = "bold", size = 20))
  left + right + plot_layout(widths = c(2.05, 0.72))
})


errors <- ace |> filter(method %in% c("design", "uniform"),
  obs_cv == 0.2, n_reps == 5) |>
  left_join(truth, by = c("source_file", "combo"), relationship = "many-to-one") |>
  mutate(CTmin = ctmin - true_ctmin, Topt = Topt - true_Topt,
  CTmax = ctmax - true_ctmax) |>
  pivot_longer(c(CTmin, Topt, CTmax), names_to = "metric", values_to = "error")
stopifnot(nrow(errors) > 0, !anyNA(errors$true_b))
median_summary <- errors |> filter(is.finite(error)) |>
  group_by(metric, n_temps, true_b, method) |>
  summarize(median_absolute_error = median(abs(error)), .groups = "drop")
median_ratios <- median_summary |>
  pivot_wider(names_from = method, values_from = median_absolute_error) |>
  mutate(log2_error_ratio = log2(design / uniform),
  metric = factor(metric, levels = c("CTmin", "Topt", "CTmax")),
  skew = factor(sprintf("b = %.1f", true_b), levels = sprintf("b = %.1f", sort(unique(true_b)))))
stopifnot(nrow(median_ratios) == 72, all(is.finite(median_ratios$log2_error_ratio)))
ylim <- max(abs(median_ratios$log2_error_ratio)) * 1.08
bottom <- ggplot(median_ratios, aes(n_temps, log2_error_ratio,
  color = skew, shape = skew, group = skew)) +
  geom_hline(yintercept = 0, color = "grey60", linewidth = 0.4) +
  geom_line(linewidth = 0.65) + geom_point(size = 2) +
  facet_wrap(~metric, nrow = 1) +
  scale_color_manual(values = c("#151515", "#555555", "#8C8C8C", "#B8B8B8"), name = "Skew") +
  scale_shape_manual(values = c(16, 17, 15, 18), name = "Skew") +
  scale_x_continuous(breaks = 5:10) +
  scale_y_continuous(limits = c(-ylim, ylim)) +
  labs(x = "Temperature treatments",
  y = expression(log[2](frac(Error[optimized], Error[equal])))) +
  theme_classic(base_size = 13) +
  theme(legend.position = "top", legend.text = element_text(size = 10),
  strip.background = element_blank(), strip.text = element_text(face = "bold"),
  panel.spacing.x = grid::unit(0.8, "lines"))
# A groups curves and boxplots; B shows parameter-error ratios.
bottom <- bottom + labs(tag = "B") + theme(plot.tag = element_text(face = "bold", size = 20))
fig <- wrap_plots(c(row_plots, list(bottom)), ncol = 1, heights = c(1, 1, 1))
fig <- fig + plot_annotation(theme = theme(plot.margin = margin(10, 10, 10, 10)))
ggsave(file.path(output_dir, "Figure_2.png"), fig,
       width = 7.5, height = 10, dpi = 350, bg = "white")
ggsave(file.path(output_dir, "Figure_2.pdf"), fig,
       width = 7.5, height = 10, bg = "white")
write.csv(median_ratios, file.path(summary_dir, "Figure_2B_summary.csv"), row.names = FALSE)
