

source("00-testing-tuning/00-preamble.R")



ace_df <- list.files("interm-data/ace-test", "big-ace-test.*.csv", full.names = TRUE) |>
    map(\(x) {
        read_csv(x, col_types = "iiciiddddddld")
    }) |>
    list_rbind()



# ============================================================================*
# ============================================================================*
# Plots ----
# ============================================================================*
# ============================================================================*


ace_df |>
    # make `b` all the real version:
    group_by(combo) |>
    mutate(b = b[method == "real"]) |>
    ungroup() |>
    filter(method != "real") |>
    select(method, combo, n_temps, n_reps, b, obs_cv, converged) |>
    group_by(method, combo, n_temps, n_reps, b, obs_cv) |>
    summarize(conv = mean(converged), .groups = "drop") |>
    group_by(n_temps, n_reps, b, obs_cv) |>
    # Values > 1 are good!
    summarize(diff_conv = conv[method == "design"] / conv[method == "uniform"], .groups = "drop") |>
    getElement("diff_conv") |>
    (\(x) {print(mean(x > 1)); return(x)})() |>
    hist(xlab = "Optimized-based converged / uniform converged", main = NULL)


ace_df |>
    # make `b` all the real version:
    group_by(combo) |>
    mutate(b = b[method == "real"]) |>
    ungroup() |>
    filter(method != "real") |>
    select(method, combo, n_temps, n_reps, b, obs_cv, rmse) |>
    group_by(method, combo, n_temps, n_reps, b, obs_cv) |>
    summarize(rmse = mean(rmse, na.rm = TRUE), .groups = "drop") |>
    group_by(n_temps, n_reps, b, obs_cv) |>
    # Values < 1 are good!
    summarize(diff_rmse = rmse[method == "design"] / rmse[method == "uniform"], .groups = "drop") |>
    getElement("diff_rmse") |>
    (\(x) {print(mean(x < 1)); return(x)})() |>
    # (\(x) sign(x) * log10(abs(x)))() |>
    hist(xlab = "Optimized-based RMSE / uniform RMSE", main = NULL)



ace_df |>
    # make `b` all the real version:
    group_by(combo) |>
    mutate(b = b[method == "real"]) |>
    ungroup() |>
    filter(method != "real") |>
    select(method, combo, n_temps, n_reps, b, obs_cv, rmse) |>
    group_by(method, combo, n_temps, n_reps, b, obs_cv) |>
    summarize(rmse = mean(rmse, na.rm = TRUE), .groups = "drop") |>
    group_by(n_temps, n_reps, b, obs_cv) |>
    # Values < 1 are good!
    summarize(diff_rmse = rmse[method == "design"] / rmse[method == "uniform"],
              .groups = "drop") |>
    group_by(b) |>
    summarize(prob_better = mean(diff_rmse < 1))



rel_p <- ace_df |>
    # make `b` all the real version:
    group_by(combo) |>
    mutate(b = b[method == "real"]) |>
    ungroup() |>
    filter(method != "real") |>
    select(method, combo, n_temps, n_reps, b, obs_cv, rmse) |>
    group_by(method, combo, n_temps, n_reps, b, obs_cv) |>
    summarize(rmse = mean(rmse, na.rm = TRUE), .groups = "drop") |>
    group_by(n_temps, n_reps, b, obs_cv) |>
    # Values < 1 are good!
    summarize(diff_rmse = rmse[method == "design"] / rmse[method == "uniform"], .groups = "drop") |>
    mutate(across(n_temps:n_reps, factor),
           b = factor(b, labels = sprintf("<i>b</i> = %.1f", sort(unique(b)))),
           obs_cv = factor(obs_cv, labels = sprintf("<i>CV</i> = %.1f", sort(unique(obs_cv))))) |>
    ggplot(aes(n_temps, n_reps, fill = log2(diff_rmse))) +
    geom_raster() +
    facet_grid(b ~ obs_cv) +
    # scale_fill_scico("log<sub>2</sub>(RMSE<sub>deriv.</sub> / RMSE<sub>unif.</sub>)",
    scale_fill_scico(expression(log[2](frac(RMSE[optim], RMSE[unif]))),
                     palette = "vik", midpoint = 0) +
    labs(x = "Number of temperature treatments",
         y = "Replicates per temperature") +
    theme(# legend.title = element_markdown(),
        strip.text.y = element_markdown(angle = 0),
        strip.text.x = element_markdown(),
        axis.ticks = element_blank(),
        axis.line = element_blank())



val_p <- ace_df |>
    # make `b` all the real version:
    group_by(combo) |>
    mutate(b = b[method == "real"]) |>
    ungroup() |>
    filter(method != "real") |>
    filter(b == 1) |>
    filter(obs_cv == 0.1) |>
    select(method, combo, n_temps, n_reps, b, obs_cv, rmse) |>
    group_by(method, combo, n_temps, n_reps, b, obs_cv) |>
    summarize(rmse = mean((rmse), na.rm = TRUE), .groups = "drop") |>
    mutate(across(n_temps:n_reps, factor),
           b = factor(b, labels = sprintf("<i>b</i> = %.1f", sort(unique(b)))),
           obs_cv = factor(obs_cv, labels = sprintf("<i>CV</i> = %.1f", sort(unique(obs_cv)))),
           method = factor(method, levels = c("uniform", "design"),
                           labels = c("uniform", "optimized"))) |>
    ggplot(aes(n_temps, n_reps, fill = rmse)) +
    geom_raster() +
    facet_grid(b ~ method) +
    scale_fill_viridis_c(option = "magma", begin = 0.2) +
    labs(x = "Number of temperature treatments",
         y = "Replicates per temperature",
         subtitle = "*CV* = 0.1") +
    theme(strip.text.y = element_markdown(family = "serif", angle = 0),
          strip.text.x = element_markdown(family = "serif"),
          plot.subtitle = element_markdown())


rel_val_p <- rel_p + val_p + plot_layout(ncol = 1, heights = c(1, 0.8))
# rel_val_p

ggsave("_plots/rel-val-optim1.pdf", rel_val_p, width = 6, height = 6)
ggsave("_plots/rel-ace-optim.pdf", rel_p, width = 6, height = 6)
