data {
  int<lower=1> N;                             // number of participants
  array[N] int<lower=0, upper=1> treat;       // treatment assignment (0=control, 1=treatment)
  vector[N] tmt_base;                         // baseline TMT B/A Ratio
  vector[N] mfis_base;                        // baseline MFIS
  vector[N] tmt_3m;                           // 3-month TMT B/A Ratio
  vector[N] mfis_3m;                          // 3-month MFIS
}

transformed data {
  vector[N] tmt_base_c;
  vector[N] mfis_base_c;
  
  // Center baseline measurements
  tmt_base_c = tmt_base - mean(tmt_base);
  mfis_base_c = mfis_base - mean(mfis_base);
}

parameters {
  vector[3] beta_tmt;    // [intercept, baseline, treatment]
  vector[3] beta_mfis;   // [intercept, baseline, treatment]
  vector<lower=0>[2] sigma;
  cholesky_factor_corr[2] L_Omega;
}

transformed parameters {
  matrix[2,2] L_Sigma = diag_pre_multiply(sigma, L_Omega);
}

model {
  // Priors for intercepts and treatment effects (weakly informative)
  beta_tmt[1] ~ normal(0, 5);
  beta_tmt[3] ~ normal(0, 1);
  beta_mfis[1] ~ normal(0, 5);
  beta_mfis[3] ~ normal(0, 10);

  // Informative priors for baseline effects
  beta_tmt[2] ~ normal(2.22, 1.07);
  beta_mfis[2] ~ normal(23.7, 21.1);

  // Priors for variance and correlation
  sigma ~ student_t(3, 0, 2.5);
  L_Omega ~ lkj_corr_cholesky(4);
  
  // Likelihood
  {
    vector[N] mu_tmt = beta_tmt[1] + beta_tmt[2] * tmt_base_c + beta_tmt[3] * to_vector(treat);
    vector[N] mu_mfis = beta_mfis[1] + beta_mfis[2] * mfis_base_c + beta_mfis[3] * to_vector(treat);
    
    for (n in 1:N) {
      vector[2] y_n = [tmt_3m[n], mfis_3m[n]]';
      vector[2] mu_n = [mu_tmt[n], mu_mfis[n]]';
      target += multi_normal_cholesky_lpdf(y_n | mu_n, L_Sigma);
    }
  }
}

generated quantities {
  // Recover correlation matrix
  matrix[2,2] Omega = multiply_lower_tri_self_transpose(L_Omega);
  
  // Treatment effects
  real tmt_effect = beta_tmt[3];
  real mfis_effect = beta_mfis[3];
  
  // Model predictions
  vector[N] tmt_pred = beta_tmt[1] + beta_tmt[2] * tmt_base_c + beta_tmt[3] * to_vector(treat);
  vector[N] mfis_pred = beta_mfis[1] + beta_mfis[2] * mfis_base_c + beta_mfis[3] * to_vector(treat);
}
