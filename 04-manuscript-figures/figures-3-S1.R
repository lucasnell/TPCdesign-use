# Figures 3 and S1

# Run once if these packages are not installed:
# install.packages(c("dplyr", "tidyr", "ggplot2", "patchwork", "scico"))
library(dplyr)
library(tidyr)
library(ggplot2)
library(patchwork)
library(scico)

# Run from the project root (TPCdesign-use/).
data_dir <- "data/factorial-test"
target_dir <- "data/prior-sensitivity"
output_dir <- "figures"
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
  select(source_file, combo, true_ctmin = ctmin, true_ctmax = ctmax, true_b = b)
stopifnot(!anyDuplicated(truth[c("source_file", "combo")]))

# Figure 3: error across temperature treatments and replicates

ace <- ace |> filter(method %in% c("uniform", "design")) |>
  left_join(truth, by = c("source_file", "combo"), relationship = "many-to-one")
target_b <- 0.5
target_cv <- 0.2
selected <- ace |>
  filter(
  near(true_ctmin, 5), near(true_ctmax, 40),
  near(true_b, target_b, tol = 1e-10),
  near(obs_cv, target_cv, tol = 1e-10)
)
cell_summary <- selected |>
  group_by(method, n_temps, n_reps) |>
  summarize(
  n_fits = sum(is.finite(rmse)),
  n_excluded = sum(!is.finite(rmse)),
  rmse = mean(rmse[is.finite(rmse)]),
  .groups = "drop"
)

stopifnot(nrow(cell_summary) == 96L, all(cell_summary$n_fits > 0), all(is.finite(cell_summary$rmse)))

ratio_summary <- cell_summary |>
  select(method, n_temps, n_reps, rmse) |>
  pivot_wider(names_from = method, values_from = rmse) |>
  mutate(log2_rmse_ratio = log2(design / uniform))

abs_limits <- range(cell_summary$rmse, na.rm = TRUE)
# Shared absolute scale for the two methods; negative ratios favor optimization.
base_theme <- theme_minimal(base_size = 18) +
  theme(axis.ticks = element_blank(), axis.line = element_blank(),
  panel.grid = element_blank(),
  panel.background = element_rect(fill = "white", color = NA),
  plot.background = element_rect(fill = "white", color = NA),
  strip.text = element_text(face = "bold"),
  legend.position = "right", legend.title = element_text(size = 20),
  legend.text = element_text(size = 18), axis.title = element_text(size = 20),
  axis.text = element_text(size = 18))
make_absolute_panel <- function(method_name, panel_title, show_y = TRUE, show_legend = TRUE) {
  ggplot(filter(cell_summary, method == method_name),
    aes(factor(n_temps), factor(n_reps), fill = rmse)) +
    geom_raster() +
    scale_fill_viridis_c(name = "Mean RMSE", option = "magma", begin = 0.2,
    limits = abs_limits) +
    labs(x = "Temperature treatments", y = if (show_y) "Replicates per temperature" else NULL,
    title = panel_title) + base_theme +
    theme(plot.title = element_text(face = "bold", hjust = 0.5, size = 24),
    legend.position = if (show_legend) "right" else "none")
}
panel_a <- make_absolute_panel("design", "Optimized", TRUE, FALSE)
panel_b <- make_absolute_panel("uniform", "Equal-spaced", FALSE, TRUE)
stopifnot(all(ratio_summary$log2_rmse_ratio <= 0))
panel_c <- ggplot(ratio_summary,
  aes(factor(n_temps), factor(n_reps), fill = log2_rmse_ratio)) +
  geom_raster() +
  scale_fill_gradientn(
  name = expression(log[2](frac(RMSE[optimized], RMSE[equal]))),
  colours = scico(128, palette = "vik", begin = 0, end = 0.5),
  limits = c(min(ratio_summary$log2_rmse_ratio), 0)) +
  labs(x = "Temperature treatments", y = NULL) + base_theme
figure <- panel_a | panel_b | panel_c

ggsave(file.path(output_dir, "Figure_3.png"), figure,
       width = 15.5, height = 5.8, dpi = 350, bg = "white")
ggsave(file.path(output_dir, "Figure_3.pdf"), figure,
       width = 15.5, height = 5.8, bg = "white")
write.csv(cell_summary, file.path(output_dir, "Figure_3_summary.csv"), row.names = FALSE)

# Figure S1: sensitivity to prior bias and uncertainty

target_files <- list.files(target_dir, "^target-ace-test.*\\.csv$", full.names = TRUE) |> sort()
if (length(target_files) == 0) stop("No target-ace-test CSVs found. Check target_dir: ", target_dir)
target <- bind_rows(lapply(target_files, function(f) {
  x <- read.csv(f)
  if (!"method" %in% names(x)) stop("Missing method column in ", f)
  x$source_file <- basename(f)
  x
}))

d <- target |> filter(method %in% c("design", "uniform"), is.finite(rmse))
cases <- tibble::tribble(~bias, ~ctmin_eps, ~ctmax_eps, ~logb_eps,
  "Unbiased estimates", 0, 0, 0,
  "Limits too cold", -2.5, -1.5, 0,
  "Limits too warm", 2.5, 1.5, 0,
  "Thermal range too wide", -2.5, 1.5, 0,
  "Thermal range too narrow", 2.5, -1.5, 0,
  "b underestimated", 0, 0, -.26,
  "b overestimated", 0, 0, .26)
r <- d |> group_by(source_file, combo, err_mult, ctmin_eps, ctmax_eps, logb_eps, method) |>
  summarize(mean_rmse = mean(rmse), .groups = "drop") |>
  pivot_wider(names_from = method, values_from = mean_rmse) |>
  inner_join(cases, by = c("ctmin_eps", "ctmax_eps", "logb_eps"), relationship = "many-to-one") |>
  mutate(mean_ratio = design / uniform,
  bias = factor(bias, levels = rev(cases$bias)),
  uncertainty = factor(err_mult, levels = c(.5, 1, 1.5, 2, 3)))
s <- d |> group_by(err_mult, method) |>
  summarize(mean_rmse = mean(rmse), n = n(), .groups = "drop") |>
  mutate(method_label = factor(ifelse(method == "design", "Optimized", "Equal-spaced"),
  levels = c("Optimized", "Equal-spaced")))
stopifnot(nrow(r) == 35, nrow(s) == 10, all(s$n == 2700), all(r$mean_ratio > 0))
write.csv(r, file.path(output_dir, "Figure_S1A_summary.csv"), row.names = FALSE)
write.csv(s, file.path(output_dir, "Figure_S1B_summary.csv"), row.names = FALSE)
fill_scale <- scale_fill_gradient2(low = "#125C8A", mid = "#F7F7F7", high = "#C5704C",
  midpoint = 0, limits = log2(c(.3, 1.1)), breaks = c(-1.5, -1, -.5, 0),
  name = expression(log[2](frac(RMSE[optimized], RMSE[equal]))))
theme_supp <- theme_classic(base_size = 15) +
  theme(axis.text = element_text(color = "black"), axis.line = element_blank(), axis.ticks = element_blank(),
  plot.margin = margin(8, 12, 8, 8), plot.tag = element_text(face = "bold", size = 20),
  legend.position = "bottom", legend.key.width = grid::unit(1.5, "cm"),
  legend.key.height = grid::unit(.4, "cm"), legend.title = element_text(size = 14), legend.text = element_text(size = 13))
a <- ggplot(r, aes(uncertainty, bias, fill = log2(mean_ratio))) +
  geom_tile(color = "white", linewidth = .8) +
  fill_scale +
  guides(fill = guide_colorbar(title.position = "top", title.hjust = .5,
  barwidth = grid::unit(4, "cm"), barheight = grid::unit(.35, "cm"))) +
  scale_x_discrete(expand = c(0, 0)) +
  scale_y_discrete(expand = c(0, 0)) +
  labs(tag = "A", x = "Prior-uncertainty multiplier", y = NULL) +
  theme_supp
b <- ggplot(s, aes(err_mult, mean_rmse, color = method_label, shape = method_label)) +
  geom_line(linewidth = .9) +
  geom_point(size = 3) +
  guides(color = guide_legend(ncol = 1), shape = guide_legend(ncol = 1)) +
  scale_color_manual(values = c("Optimized" = "#D55E00", "Equal-spaced" = "#0072B2"), name = NULL) +
  scale_shape_manual(values = c("Optimized" = 16, "Equal-spaced" = 17), name = NULL) +
  scale_x_continuous(breaks = c(.5, 1, 1.5, 2, 3)) +
  scale_y_continuous(limits = c(0, 300), breaks = seq(0, 300, 50), expand = expansion(mult = c(0, .03))) +
  labs(tag = "B", x = "Prior-uncertainty multiplier", y = "Whole-curve RMSE") +
  theme_supp +
  theme(axis.line = element_line(color = "black", linewidth = .4), axis.ticks = element_line(color = "black"),
  legend.key.width = grid::unit(.7, "cm"))
fig <- a + b + plot_layout(widths = c(1, 1))
ggsave(file.path(output_dir, "Figure_S1.png"), fig,
       width = 8.5, height = 4.8, dpi = 400, bg = "white")
ggsave(file.path(output_dir, "Figure_S1.pdf"), fig,
       width = 8.5, height = 4.8, bg = "white")
