context("model eligibility")
library(covidEnsembles)
library(dplyr)

test_that("get_candidate_models works: all models", {
  actual <- get_candidate_models(
    submissions_root = "test-data/data-processed-test-get_candidate_models",
    include_designations = c("primary", "secondary", "proposed", "other"),
    include_COVIDhub_ensemble = TRUE,
    include_COVIDhub_baseline = TRUE)

  expected <- c("COVIDhub-baseline", "COVIDhub-ensemble", "teamA-modelA",
    "teamB-modelB", "teamC-modelC", "teamD-modelD")
  
  expect_equal(actual, expected)
})


test_that("get_candidate_models works: not 'other' models", {
  actual <- get_candidate_models(
    submissions_root = "test-data/data-processed-test-get_candidate_models",
    include_designations = c("primary", "secondary", "proposed"),
    include_COVIDhub_ensemble = TRUE,
    include_COVIDhub_baseline = TRUE)

  expected <- c("COVIDhub-baseline", "COVIDhub-ensemble", "teamA-modelA",
    "teamB-modelB", "teamC-modelC")
  
  expect_equal(actual, expected)
})


test_that("get_candidate_models works: not 'other' models or baseline", {
  actual <- get_candidate_models(
    submissions_root = "test-data/data-processed-test-get_candidate_models",
    include_designations = c("primary", "secondary", "proposed"),
    include_COVIDhub_ensemble = TRUE,
    include_COVIDhub_baseline = FALSE)

  expected <- c("COVIDhub-ensemble", "teamA-modelA", "teamB-modelB",
    "teamC-modelC")
  
  expect_equal(actual, expected)
})


test_that("get_candidate_models works: not 'other' or 'proposed' models, drop ensemble and baseline", {
  actual <- get_candidate_models(
    submissions_root = "test-data/data-processed-test-get_candidate_models",
    include_designations = c("primary", "secondary"),
    include_COVIDhub_ensemble = FALSE,
    include_COVIDhub_baseline = FALSE)

  expected <- c("teamA-modelA", "teamB-modelB")
  
  expect_equal(actual, expected)
})


test_that("calc_forecast_missingness works: window_size 0, none missing", {
  forecast_df <- expand.grid(
    location = letters[1:4],
    forecast_week_end_date = c('2020-04-18', '2020-04-25', '2020-05-02'),
    model = paste0('m', 1:3),
    q_prob = c(0.025, 0.5, 0.975),
    stringsAsFactors = FALSE
  )
  forecast_df$q_val <- rnorm(nrow(forecast_df))
  forecast_df$q_val[
    forecast_df$location == 'b' &
    forecast_df$forecast_week_end_date == '2020-04-18' &
    forecast_df$model == 'm2' &
    forecast_df$q_prob == 0.975
  ] <- NA_real_

  forecast_matrix <- new_QuantileForecastMatrix_from_df(
    forecast_df %>% filter(forecast_week_end_date >= '2020-05-02'),
    model_col = 'model',
    id_cols = c('location', 'forecast_week_end_date'),
    quantile_name_col = 'q_prob',
    quantile_value_col = 'q_val'
  )

  actual <- calc_forecast_missingness(
    qfm=forecast_matrix
  )

  expected <- tidyr::expand_grid(
    location = letters[1:4],
    model = paste0('m', 1:3),
    missingness_eligibility = 'eligible'
  )

  expect_equal(
    actual,
    expected
  )
})


test_that("calc_forecast_missingness works: window_size 1, none missing", {
  forecast_df <- expand.grid(
    location = letters[1:4],
    forecast_week_end_date = c('2020-04-18', '2020-04-25', '2020-05-02'),
    model = paste0('m', 1:3),
    q_prob = c(0.025, 0.5, 0.975),
    stringsAsFactors = FALSE
  )
  forecast_df$q_val <- rnorm(nrow(forecast_df))
  forecast_df$q_val[
    forecast_df$location == 'b' &
      forecast_df$forecast_week_end_date == '2020-04-18' &
      forecast_df$model == 'm2' &
      forecast_df$q_prob == 0.975
    ] <- NA_real_

  forecast_matrix <- new_QuantileForecastMatrix_from_df(
    forecast_df %>% filter(forecast_week_end_date >= '2020-04-25'),
    model_col = 'model',
    id_cols = c('location', 'forecast_week_end_date'),
    quantile_name_col = 'q_prob',
    quantile_value_col = 'q_val'
  )

  actual <- calc_forecast_missingness(
    qfm=forecast_matrix
  )

  expected <- tidyr::expand_grid(
    location = letters[1:4],
    model = paste0('m', 1:3),
    missingness_eligibility = 'eligible'
  )

  expect_equal(
    actual,
    expected
  )
})


test_that("calc_forecast_missingness works: window_size 2, missing", {
  forecast_df <- expand.grid(
    location = letters[1:4],
    forecast_week_end_date = c('2020-04-18', '2020-04-25', '2020-05-02'),
    model = paste0('m', 1:3),
    q_prob = c(0.025, 0.5, 0.975),
    stringsAsFactors = FALSE
  )
  forecast_df$q_val <- rnorm(nrow(forecast_df))
  forecast_df$q_val[
    forecast_df$location == 'b' &
      forecast_df$forecast_week_end_date == '2020-04-18' &
      forecast_df$model == 'm2' &
      forecast_df$q_prob == 0.975
    ] <- NA_real_

  forecast_matrix <- new_QuantileForecastMatrix_from_df(
    forecast_df,
    model_col = 'model',
    id_cols = c('location', 'forecast_week_end_date'),
    quantile_name_col = 'q_prob',
    quantile_value_col = 'q_val'
  )

  actual <- calc_forecast_missingness(
    qfm=forecast_matrix
  )

  expected <- tidyr::expand_grid(
    location = letters[1:4],
    model = paste0('m', 1:3),
    missingness_eligibility = 'eligible'
  )
  expected$missingness_eligibility[
    expected$location == 'b' &
    expected$model == 'm2'
  ] <- 'missing required forecasts'

  expect_equal(
    actual,
    expected
  )
})


test_that("calc_q10_check works", {
  forecast_df <- expand.grid(
    location = letters[1:4],
    forecast_week_end_date =
      lubridate::ymd(c("2020-04-18", "2020-04-25", "2020-05-02")),
    target = paste0(1:4, " wk ahead cum death"),
    model = paste0('m', 1:3),
    q_prob = c(0.025, 0.1, 0.5, 0.9, 0.975),
    stringsAsFactors = FALSE
  )

  forecast_df$q_val <- 5
  forecast_df$q_val[
    forecast_df$location %in% c('b', 'c') &
      forecast_df$forecast_week_end_date == '2020-05-02' &
      forecast_df$model == 'm2' &
      forecast_df$q_prob == 0.1
    ] <- 0
  forecast_df$q_val[
    forecast_df$location %in% c('a') &
      forecast_df$forecast_week_end_date == '2020-04-25' &
      forecast_df$model == 'm1' &
      forecast_df$q_prob == 0.1
    ] <- 0

  observed_by_location_target_end_date <- expand.grid(
    location = letters[1:4],
    target_end_date = c('2020-04-18', '2020-04-25', '2020-05-02'),
    observed = 2,
    stringsAsFactors = FALSE
  )

  forecast_matrix <- new_QuantileForecastMatrix_from_df(
    forecast_df,
    model_col = 'model',
    id_cols = c('location', 'forecast_week_end_date', 'target'),
    quantile_name_col = 'q_prob',
    quantile_value_col = 'q_val'
  )

  actual <- calc_q10_check(
    qfm=forecast_matrix,
    observed_by_location_target_end_date=observed_by_location_target_end_date
  )

  expected <- tidyr::expand_grid(
    location = letters[1:4],
    model = paste0('m', 1:3),
    q10_eligibility = 'eligible'
  ) %>%
    arrange(location, model)

  expected$q10_eligibility[
    expected$location %in% c('a') &
      expected$model == 'm1'
    ] <- 'quantile 0.1 of forecast for horizon 1 is less than most recent observed'
  expected$q10_eligibility[
    expected$location %in% c('b', 'c') &
      expected$model == 'm2'
    ] <- 'quantile 0.1 of forecast for horizon 1 is less than most recent observed'


  expect_equal(
    actual,
    expected
  )
})



test_that("calc_nondecreasing_quantile_check works", {
  forecast_df <- expand.grid(
    location = letters[1:4],
    forecast_week_end_date = c('2020-04-18', '2020-04-25', '2020-05-02'),
    target = paste0(1:4, ' wk ahead cum death'),
    model = paste0('m', 1:3),
    q_prob = c(0.025, 0.1, 0.5, 0.9, 0.975),
    stringsAsFactors = FALSE
  )

  forecast_df$q_val <- 5
  forecast_df$q_val[
    forecast_df$location %in% c('b', 'c') &
      forecast_df$forecast_week_end_date == '2020-05-02' &
      forecast_df$model == 'm2' &
      forecast_df$q_prob == 0.1 &
      forecast_df$target == '3 wk ahead cum death'
    ] <- 0
  forecast_df$q_val[
    forecast_df$location %in% c('a') &
      forecast_df$forecast_week_end_date == '2020-04-25' &
      forecast_df$model == 'm1' &
      forecast_df$q_prob == 0.1
    ] <- 0

  forecast_matrix <- new_QuantileForecastMatrix_from_df(
    forecast_df,
    model_col = 'model',
    id_cols = c('location', 'forecast_week_end_date', 'target'),
    quantile_name_col = 'q_prob',
    quantile_value_col = 'q_val'
  )

  actual <- calc_nondecreasing_quantile_check(
    qfm=forecast_matrix
  )

  expected <- tidyr::expand_grid(
    location = letters[1:4],
    model = paste0('m', 1:3),
    nondecreasing_quantiles_eligibility = 'eligible'
  ) %>%
    arrange(location, model)

  expected$nondecreasing_quantiles_eligibility[
    expected$location %in% c('b', 'c') &
      expected$model == 'm2'
    ] <- 'decreasing quantiles over time'

  expect_equal(
    actual,
    expected
  )
})


test_that("calc_sd_check works to downside", {

  # lookback window length for sd
  n_back_sd <- 14
  # lookback window length for mean
  n_back_mean <- 7
  # total observations per setting
  n_obs <- 17
  extra <-  n_obs - max(n_back_sd, n_back_mean)
  # base level of obs
  lev_back <- 100
  sd <- 10
  # constant upto time zero and has given sd over lookback window
  obs <- c(rep(lev_back,n_obs-1),lev_back-sd*(n_back_sd)^.5)


  A <- diag(1:10)
  for (i in 1:9) {A[i+1,i] <- -A[i,i]}
  # A converts a mean series back to series producing those means
  # i.e., inverts x -> cumsum(x)/seq_along(x)
  # or almost... e.g.,
  # x <- rnorm(10)
  # (A%*%(cumsum(x)/seq_along(x)))-x
  # Let's consider this noise the test should be robust against...

  # current cutoff for exclusion
  cut <- mean(tail(obs, n_back_mean)) - 4*sd

  eps <- 1e-6
  # a mean series whose producing series' model should be excluded
  m010 <- c(rep(cut,5),cut+eps, cut-eps, cut+eps, rep(cut,2))
  # and 2 for which models should be included
  m001 <- c(rep(cut,5),cut+eps, cut+eps, cut-eps, rep(cut,2))
  m100 <- c(rep(cut,5),cut-eps, cut+eps, cut+eps, rep(cut,2))

  v010 <- A%*%m010
  v001 <- A%*%m001
  v100 <- A%*%m100
  # Note: eps_up > 0 deals with error from A

  observed_by_location_target_end_date <- expand.grid(
    location = letters[1:4],
    target_end_date = as.character(lubridate::ymd("2021-01-11") - (n_obs-1):0),
    stringsAsFactors = FALSE
  ) %>% 
  arrange(location) %>% 
  mutate(observed = rep(obs, 4))

  forecast_df <- tidyr::expand_grid(
    location = letters[1:4],
    model = paste0('m', 1:3),
    q_prob = c(0.1, 0.5, 0.9),
    forecast_week_end_date = lubridate::ymd("2021-01-11"),
    target = paste0(1:10, ' day ahead inc hosp')
  )

  forecast_df <- forecast_df %>% 
  mutate(target_end_date = calc_target_string_end_date(forecast_week_end_date, target)) %>% 
  arrange(location, model, q_prob) 

  forecast_df$val <- 0

  forecast_df <- within(forecast_df, {
  val[q_prob == 0.1] <- lev_back - 5*sd
  val[q_prob == 0.9] <- lev_back + sd
  # in a and b exclude m1
  val[q_prob == 0.5 & location %in% c("a","b") & model == "m1"] <- v010
  val[q_prob == 0.5 & location %in% c("a","b") & model == "m2"] <- v100  
  val[q_prob == 0.5 & location %in% c("a","b") & model == "m3"] <- v001  
  # in c exclude m3
  val[q_prob == 0.5 & location == "c" & model %in% c("m1", "m2")] <- lev_back - sd
  val[q_prob == 0.5 & location == "c" & model == "m3"] <- v010
  # in d include all
  val[q_prob == 0.5 & location == "d"] <- lev_back - sd
  })

  forecast_matrix <- new_QuantileForecastMatrix_from_df(
    forecast_df,
    model_col = 'model',
    id_cols = c('location', 'forecast_week_end_date', 'target'),
    quantile_name_col = 'q_prob',
    quantile_value_col = 'val'
  )

  actual <- calc_sd_check(
    qfm = forecast_matrix,
    observed_by_location_target_end_date = observed_by_location_target_end_date
  )

  expected <- tidyr::expand_grid(
    location = letters[1:4],
    model = paste0('m', 1:3),
    sd_eligibility = 'eligible'
  ) %>%
    arrange(location, model)

  # To do: parametrize msg
  msg <- 'mean of next 7 forecasted medians more than 4 times 14day SD below mean of last 7 observations'
  expected <- within(expected, {
    sd_eligibility[location %in% c('a', 'b') & model == 'm1'] <- msg
    sd_eligibility[location %in% c('c') & model == 'm3'] <- msg
  })

  expect_equal(
    actual,
    expected
  )
})

test_that("calc_sd_check works to upside", {

  # lookback window length for sd
  n_back_sd <- 14
  # lookback window length for mean
  n_back_mean <- 7
  # total observations per setting
  n_obs <- 17
  extra <-  n_obs - max(n_back_sd, n_back_mean)
  # base level of obs
  lev_back <- 100
  sd <- 10
  # constant upto time zero and has given sd over lookback window
  obs <- c(rep(lev_back,n_obs-1),lev_back-sd*(n_back_sd)^.5)


  A <- diag(1:10)
  for (i in 1:9) {A[i+1,i] <- -A[i,i]}
  # A converts a mean series back to series producing those means
  # i.e., inverts x -> cumsum(x)/seq_along(x)
  # or almost... e.g.,
  # x <- rnorm(10)
  # (A%*%(cumsum(x)/seq_along(x)))-x
  # Let's consider this noise the test should be robust against...

  # current cutoff for exclusion
  cut <- mean(tail(obs, n_back_mean)) + 4*sd

  eps <- 1e-6
  # a mean series whose producing series' model should be excluded
  m010 <- c(rep(cut,5),cut-eps, cut+eps, cut-eps, rep(cut,2))
  # and 2 for which models should be included
  m001 <- c(rep(cut,5),cut-eps, cut-eps, cut+eps, rep(cut,2))
  m100 <- c(rep(cut,5),cut+eps, cut-eps, cut-eps, rep(cut,2))

  v010 <- A%*%m010
  v001 <- A%*%m001
  v100 <- A%*%m100
  # Note: eps_up > 0 deals with error from A

  observed_by_location_target_end_date <- expand.grid(
    location = letters[1:4],
    target_end_date = as.character(lubridate::ymd("2021-01-11") - (n_obs-1):0),
    stringsAsFactors = FALSE
  ) %>% 
  arrange(location) %>% 
  mutate(observed = rep(obs, 4))

  forecast_df <- tidyr::expand_grid(
    location = letters[1:4],
    model = paste0('m', 1:3),
    q_prob = c(0.1, 0.5, 0.9),
    forecast_week_end_date = lubridate::ymd("2021-01-11"),
    target = paste0(1:10, ' day ahead inc hosp')
  )

  forecast_df <- forecast_df %>% 
  mutate(target_end_date = calc_target_string_end_date(forecast_week_end_date, target)) %>% 
  arrange(location, model, q_prob) 

  forecast_df$val <- 0

  forecast_df <- within(forecast_df, {
  val[q_prob == 0.1] <- lev_back - 5*sd
  val[q_prob == 0.9] <- lev_back + sd
  # in a and b exclude m1
  val[q_prob == 0.5 & location %in% c("a","b") & model == "m1"] <- v010
  val[q_prob == 0.5 & location %in% c("a","b") & model == "m2"] <- v100  
  val[q_prob == 0.5 & location %in% c("a","b") & model == "m3"] <- v001  
  # in c exclude m3
  val[q_prob == 0.5 & location == "c" & model %in% c("m1", "m2")] <- lev_back - sd
  val[q_prob == 0.5 & location == "c" & model == "m3"] <- v010
  # in d include all
  val[q_prob == 0.5 & location == "d"] <- lev_back - sd
  })

  forecast_matrix <- new_QuantileForecastMatrix_from_df(
    forecast_df,
    model_col = 'model',
    id_cols = c('location', 'forecast_week_end_date', 'target'),
    quantile_name_col = 'q_prob',
    quantile_value_col = 'val'
  )

  actual <- calc_sd_check(
    qfm = forecast_matrix,
    observed_by_location_target_end_date = observed_by_location_target_end_date,
    exclude_above = TRUE
  )

  expected <- tidyr::expand_grid(
    location = letters[1:4],
    model = paste0('m', 1:3),
    sd_eligibility = 'eligible'
  ) %>%
    arrange(location, model)

  # To do: parametrize msg
  msg <- 'mean of next 7 forecasted medians more than 4 times 14day SD above mean of last 7 observations'
  expected <- within(expected, {
    sd_eligibility[location %in% c('a', 'b') & model == 'm1'] <- msg
    sd_eligibility[location %in% c('c') & model == 'm3'] <- msg
  })

  expect_equal(
    actual,
    expected
  )
})

