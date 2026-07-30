

source("00-testing-tuning/00-preamble.R")



ace_df <- list.files("interm-data/ace-tuning", "ace-tuning.*.csv",
                     full.names = TRUE) |>
    read_csv(col_types = "iiiddiiiidddddddd")


# Columns that I varied across sims:
# ace_df |>
#     select(-combo, -rep, -rmse) |>
#     select(where(\(x) n_distinct(x) > 1)) |>
#     colnames()
# # [1] "n_temps"   "b"         "ctmin_eps" "ctmax_eps" "logb_eps"  "min_sep"
# # [7] "n_filler"  "n_draws"   "n_starts"


ace_summ_df <- ace_df |>
    group_by(across(n_temps:n_starts)) |>
    summarize(sd_rmse = sd(rmse, na.rm = TRUE),
              log_rmse = mean(log10(rmse), na.rm = TRUE),
              rmse = mean(rmse, na.rm = TRUE),
              .groups = "drop")





# Takeaways:
# - n_draws has little effect
# - n_starts has little effect
# - min_sep = 2 is mildly better for b >= 0.5 and n_temps >= 9 and for
#   b >= 1 and n_temps >= 8
# - n_filler:
#     * n_filler = 0 is often best, but can do REALLY bad sometimes
#     * n_filler = 1 is generally best when b <= 0.5
#     * n_filler = 1 or 2 is about the same when b == 1
#     * n_filler = 3 is generally best when b == 2
#


# m <- lm(rmse ~ min_sep * factor(b) * factor(n_temps), ace_summ_df |> filter(n_filler == 1))
# pred <- ace_summ_df |> distinct(b, n_temps) |>
#     crossing(min_sep = seq(0.5, 2, 0.05)) |>
#     (\(x) mutate(x, rmse = predict(m, newdata = x)))()



# This is just `Hmisc::smean.cl.boot` with output cleaned as in
# `ggplot2::mean_cl_boot`
# Hmisc is breaking my computer for some reason.
booter <- function(x, conf.int = 0.95, B = 1000, na.rm = TRUE, reps = FALSE) {
    if (na.rm)
        x <- x[!is.na(x)]
    n <- length(x)
    xbar <- mean(x)
    if (n < 2L)
        return(c(Mean = xbar, Lower = NA, Upper = NA))
    z <- unlist(lapply(seq_len(B), function(i, x, N) sum(x[sample.int(N,
        N, TRUE, NULL)]), x = x, N = n))/n
    quant <- quantile(z, c((1 - conf.int)/2, (1 + conf.int)/2))
    names(quant) <- NULL
    res <- c(Mean = xbar, Lower = quant[1L], Upper = quant[2L])
    out <- res |> as.list() |> as.data.frame() |>
        rename(y = Mean, ymin = Lower, ymax = Upper)
    return(out)
}



ace_summ_df |>
    # filter(b == 0.2, n_temps == 5) |>
    filter(n_filler >= 1) |>
    ggplot(aes(n_filler, rmse)) +
    geom_point(color = "gray70", size = 2, shape = 1) +
    # stat_smooth(formula = y ~ s(x, bs = "cs", k=3), method = "gam", se = TRUE, linewidth = 1.5) +
    # stat_smooth(formula = y ~ x, method = "lm", se = TRUE, linewidth = 1.5) +
    stat_summary(fun.data = "booter", size = 1, shape = 5, stroke = 1,
                 linewidth = 1) +
    # stat_summary(fun = "mean", size = 1, shape = 5, stroke = 1) +
    stat_summary(fun = "mean", linewidth = 1, geom = "line") +
    facet_wrap(~ interaction(b, n_temps, sep = " - "), scales = "free_y",
               ncol = length(unique(ace_summ_df$b))) +
    # facet_wrap(~ factor(b), scales = "free_y",
    #            ncol = length(unique(ace_summ_df$b))) +
    # facet_wrap(~ factor(n_temps)) +
    scale_color_viridis_c(option = "plasma", begin = 0.2, end = 0.95) +
    theme(panel.spacing = unit(0, "lines"),
          strip.text = element_text())



ace_summ_df |>
    # filter(abs(ctmin_eps) < 5, abs(ctmax_eps) < 3, abs(logb_eps) < 0.5) |>
    ggplot(aes(n_filler, rmse)) +
    geom_point(color = "gray70", size = 2, shape = 1) +
    # stat_summary(fun.data = "mean_cl_boot", size = 1, shape = 5, stroke = 1,
    #              linewidth = 1) +
    facet_wrap(~ interaction(b, n_temps, sep = " - "), scales = "free_y",
               ncol = length(unique(ace_summ_df$b))) +
    theme(panel.spacing = unit(0, "lines"),
          strip.text = element_text())






