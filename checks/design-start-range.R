#'
#' Does the ACE starting range in TPCdesign::design_temps() change the final
#' design or its utility?
#'
#' Compares starting temperatures drawn from [ctmin + min_sep, ctmax - min_sep]
#' (package, "conservative") with starts drawn from the whole
#' [min_temp, max_temp] window ("window"), using identical prior draws.
#' Setup matches Figure 2A (shared offsets): n_temps = 6, n_filler = 1,
#' min_sep = 2, window = prior CTmin - 5 to prior CTmax + 5.
#' Run from the project root; writes data/checks/design-start-range.csv.
#'

suppressPackageStartupMessages({
    library(tidyverse)
    library(TPCdesign)
})

one_design <- function(ctmin, ctmax, b, start_range, seed,
                       n_optimal = 5L, min_sep = 2, n_draws = 250L,
                       n_starts = 7L, ctmin_err = 2.5, ctmax_err = 1.5,
                       logb_err = 0.26) {
    set.seed(seed)
    min_temp <- ctmin - 5
    max_temp <- ctmax + 5
    theta <- cbind(ctmin = runif(n_draws, ctmin - ctmin_err, ctmin + ctmin_err),
                   ctmax = runif(n_draws, ctmax - ctmax_err, ctmax + ctmax_err),
                   b = exp(runif(n_draws, log(b) - logb_err, log(b) + logb_err)),
                   a = rep(1, n_draws))
    lims <- switch(start_range,
                   conservative = c(ctmin + min_sep, ctmax - min_sep),
                   window = c(min_temp, max_temp))
    starts <- lapply(1:n_starts, \(i) {
        d <- lhs::randomLHS(n = n_optimal, k = 1) * diff(lims) + lims[1]
        d <- d[order(d), , drop = FALSE]
        colnames(d) <- "temp"
        d
    })
    start_utils <- map_dbl(starts, \(d) TPCdesign:::utility_briere2(d, theta))
    limits_minsep <- function(d, i, j) {
        grid <- seq(from = min_temp, to = max_temp, length.out = 2000)
        for (s in as.vector(d)[-i]) {
            grid <- grid[(grid < (s - min_sep)) | (grid > (s + min_sep))]
        }
        grid
    }
    out <- tryCatch(TPCdesign:::tpc_pace(utility = TPCdesign:::utility_briere2,
                                         start.d = starts,
                                         B = rep(list(theta = theta), 2),
                                         lower = min_temp, upper = max_temp,
                                         limits = limits_minsep),
                    error = \(e) NULL)
    if (is.null(out)) {
        return(tibble(start_range, seed, b, error = TRUE, utility = NA_real_,
                      n_start_nonfinite = sum(!is.finite(start_utils)),
                      temps = NA_character_, lowest = NA_real_))
    }
    d <- sort(as.vector(out$d))
    tibble(start_range, seed, b, error = FALSE,
           utility = TPCdesign:::utility_briere2(matrix(d, ncol = 1,
                                                        dimnames = list(NULL, "temp")),
                                                 theta),
           n_start_nonfinite = sum(!is.finite(start_utils)),
           temps = paste(round(d, 2), collapse = " "), lowest = min(d))
}

grid <- crossing(b = c(0.2, 2), start_range = c("conservative", "window"),
                 seed = 1:10)
res <- pmap(grid, \(b, start_range, seed) one_design(5, 40, b, start_range, seed)) |>
    list_rbind()

dir.create("data/checks", showWarnings = FALSE, recursive = TRUE)
write_csv(res, "data/checks/design-start-range.csv")

res |>
    group_by(b, start_range) |>
    summarize(n = n(), n_error = sum(error),
              n_start_nonfinite = sum(n_start_nonfinite),
              median_utility = median(utility, na.rm = TRUE),
              max_utility = max(utility, na.rm = TRUE),
              median_lowest = median(lowest, na.rm = TRUE),
              .groups = "drop") |>
    print(width = Inf)
