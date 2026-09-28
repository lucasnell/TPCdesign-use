#'
#' Preamble for targeted ACE test
#' Meant to be run on cluster
#'
#'





# Coefficients from one fit for one combo of parameters
# (same as in 03a-big-ace-test.R)
one_test_fit <- function(i, temps, n_reps, obs_cv, ctmin, ctmax, a, b) {


    obs <- sim_gamma_data(temps, n_reps, obs_cv, ctmin, ctmax, a, b)

    starts_lo <- c(a = log(1e-6),  ctmin = -5,  ctmax = 30, b = log(0.01))
    starts_up <- c(a = log(2),  ctmin = 15, ctmax = 50, b = log(3))

    fit <- nls_multstart(
        formula     = y ~ exp(a) * temp * pmax(temp - ctmin, 0) *
            pmax(ctmax - temp, 0)^exp(b),
        data        = obs,
        start_lower = starts_lo,
        start_upper = starts_up,
        supp_errors = "Y",
        control = list(maxfev = 5e3, maxiter = 1e3),
        iter        = 500)

    if (is.null(fit)) {
        fitted <- tibble(ctmin = NA_real_, ctmax = NA_real_,
                         a = NA_real_, b = NA_real_, Topt = NA_real_,
                         converged = FALSE, rmse = NA_real_)
    } else {
        fitted <- as_tibble(as.list(coef(fit))[c("ctmin", "ctmax", "a", "b")])
        for (x in c("a", "b")) fitted[[x]] <- exp(fitted[[x]])
        fitted[["Topt"]] <- briere2_tpc_Topt(fitted[["ctmin"]], fitted[["ctmax"]],
                                             fitted[["b"]])
        fitted[["converged"]] <- fit$convInfo$isConv
        # Add RMSE
        test_temps <- seq(ctmin, ctmax, length.out = 101)
        obs_y <- briere2_tpc(test_temps, fitted[["ctmin"]], fitted[["ctmax"]],
                             fitted[["a"]], fitted[["b"]])
        tru_y <- briere2_tpc(test_temps, ctmin, ctmax, a, b)
        fitted[["rmse"]] <- sqrt(mean((obs_y - tru_y)^2))
    }

    fitted[["rep"]] <- i
    return(fitted)
}




# Do all fits for a single combination of parameters
one_combo_fits <- function(j, input_df,
                           .n_test_fits = 100L,
                           .parent_prog = function(...) NULL,
                           .parallel = FALSE,
                           .parallel_seed = TRUE) {

    # j = 7L; .n_test_fits = 30L
    # rm(j, input_df, .n_test_fits)
    # rm(ace_args, x, .n_par_fits, par_lhs_list, temps, Topt, fit_df)

    err_mult <- input_df[["err_mult"]][[j]]
    ctmin_eps <- input_df[["ctmin_eps"]][[j]]
    ctmax_eps <- input_df[["ctmax_eps"]][[j]]
    logb_eps <- input_df[["logb_eps"]][[j]]


    # True values:
    truth <- list(ctmin = 5,
                  ctmax = 40,
                  a = 1,
                  b = 0.5,
                  # Used for simulating data (not `design_temps`):
                  n_reps = 5,
                  obs_cv = 0.2)

    # Values used for fitting:
    ace_args <- list(ctmin = truth$ctmin + ctmin_eps,
                     ctmax = truth$ctmax + ctmax_eps,
                     a = truth$a,
                     b = exp(log(truth$b) + logb_eps),
                     n_temps = 7,
                     ctmin_err = formals(design_temps)[["ctmin_err"]] * err_mult,
                     ctmax_err = formals(design_temps)[["ctmax_err"]] * err_mult,
                     logb_err = formals(design_temps)[["logb_err"]] * err_mult,
                     min_temp = truth$ctmin + ctmin_eps - 5,
                     max_temp = truth$ctmax + ctmax_eps + 5)


    # used in output:
    truth[["Topt"]] <- briere2_tpc_Topt(truth$ctmin, truth$ctmax, truth$b)

    one_temp_fun <- function(i) {
        dtemps <- do.call(design_temps, ace_args)
        utemps <- seq(ace_args$min_temp, ace_args$max_temp,
                      length.out = ace_args$n_temps) |>
            round(2)

        dfit <- one_test_fit(i = i, temps = dtemps,
                             n_reps = truth$n_reps, obs_cv = truth$obs_cv,
                             ctmin = truth$ctmin, ctmax = truth$ctmax,
                             a = truth$a, b = truth$b) |>
            mutate(method = "design")
        ufit <- one_test_fit(i = i, temps = utemps,
                             n_reps = truth$n_reps, obs_cv = truth$obs_cv,
                             ctmin = truth$ctmin, ctmax = truth$ctmax,
                             a = truth$a, b = truth$b) |>
            mutate(method = "uniform")

        out <- bind_rows(dfit, ufit) |>
            select(rep, method, everything())

        return(out)
    }

    if (.parallel) {
        fit_df <- future_lapply(1:.n_test_fits, one_temp_fun,
                               future.seed = .parallel_seed,
                               future.globals = c("ace_args", "truth",
                                                  "ctmin", "ctmax", "a", "b",
                                                  "one_test_fit"),
                               future.packages = c("TPCdesign", "dplyr",
                                                   "nls.multstart", "tibble"))
    } else {
        fit_df <- map(1:.n_test_fits, one_temp_fun)
    }

    fit_df <- fit_df |>
        list_rbind() |>
        add_row(rep = NA, method  = "real",
                ctmin = truth$ctmin, ctmax = truth$ctmax,
                a = truth$a, b = truth$b, Topt = truth$Topt) |>
        mutate(err_mult = .env$err_mult,
               ctmin_eps = .env$ctmin_eps,
               ctmax_eps = .env$ctmax_eps,
               logb_eps = .env$logb_eps) |>
        mutate(combo = j) |>
        select(combo, rep, method, err_mult:logb_eps, everything())

    .parent_prog()

    return(fit_df)

}





