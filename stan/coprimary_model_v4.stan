data {
    int<lower=1> N;
    array[N] int<lower=0, upper=1> treat;  // Updated array syntax
    vector[N] tmt_base;
    vector[N] mfis_base;
    vector[N] tmt_3m;
    vector[N] mfis_3m;
  }
  
  transformed data {
    // Option 1: standardize outcomes. 
    vector[N] tmt_base_z;
    vector[N] mfis_base_z;
    real mean_tmt_base = mean(tmt_base);
    real sd_tmt_base   = sd(tmt_base);
    real mean_mfis_base = mean(mfis_base);
    real sd_mfis_base   = sd(mfis_base);
    
    for (n in 1:N) {
      tmt_base_z[n] = (tmt_base[n] - mean_tmt_base) / sd_tmt_base;
      mfis_base_z[n] = (mfis_base[n] - mean_mfis_base) / sd_mfis_base;
    }
  }
  
  parameters {
    vector[3] beta_tmt;  // [intercept, baseline, treatment]
    vector[3] beta_mfis; // [intercept, baseline, treatment]
    vector<lower=0>[2] sigma;
    cholesky_factor_corr[2] L_Omega;
  }
  
  transformed parameters {
    matrix[2,2] L_Sigma = diag_pre_multiply(sigma, L_Omega);
  }
  
  model {
    // Priors - use appropriate scales for each outcome
    // TMT B/A ratio: values typically 1-5, effects ~0.1-0.2
    beta_tmt[1] ~ normal(2.5, 2);      // intercept
    beta_tmt[2] ~ normal(0.5, 1);      // baseline effect (positive, strong)
    beta_tmt[3] ~ normal(0, 0.5);      // treatment effect (small, centered)

    // MFIS: values 0-84, typically 20-50, effects ~3-10
    beta_mfis[1] ~ normal(30, 20);     // intercept
    beta_mfis[2] ~ normal(15, 10);     // baseline effect (positive, strong)
    beta_mfis[3] ~ normal(0, 10);      // treatment effect

    sigma ~ student_t(3, 0, 10);
    L_Omega ~ lkj_corr_cholesky(2);
  
    {
      vector[N] mu_tmt;
      vector[N] mu_mfis;
      
      // Use standardized baseline in the linear predictors
      for (n in 1:N) {
        mu_tmt[n] = beta_tmt[1] 
                    + beta_tmt[2] * tmt_base_z[n]
                    + beta_tmt[3] * treat[n];
        mu_mfis[n] = beta_mfis[1] 
                     + beta_mfis[2] * mfis_base_z[n]
                     + beta_mfis[3] * treat[n];
      }
      
      for (n in 1:N) {
        vector[2] y_n = [tmt_3m[n], mfis_3m[n]]';
        vector[2] mu_n = [mu_tmt[n], mu_mfis[n]]';
        target += multi_normal_cholesky_lpdf(y_n | mu_n, L_Sigma);
      }
    }
  }
  
  generated quantities {
    matrix[2,2] Omega = multiply_lower_tri_self_transpose(L_Omega);
  }
