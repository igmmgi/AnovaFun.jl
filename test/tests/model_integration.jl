@testset "Model Integration (Phase 2)" begin
    @testset "Between-subjects: Model Fitting and Accessors" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_between_2.csv"), DataFrame)

        # Model is always fitted
        result = anova(data, :dv, :subject, between = [:BF1])
        @test !isnothing(model(result))

        # Test residuals
        res = GLM.residuals(model(result))
        @test length(res) == nrow(data)
        @test sum(res) ≈ 0.0 atol = 1e-10  # Residuals sum to ~0

        # Test fitted values
        fit_vals = GLM.fitted(model(result))
        @test length(fit_vals) == nrow(data)
        @test all(isfinite.(fit_vals))

        # Test that residuals + fitted = observed
        @test all(isapprox.(fit_vals .+ res, data.dv, atol = 1e-10))

        # Test coefficients
        cf = GLM.coef(model(result))
        @test length(cf) >= 1  # At least intercept
        @test all(isfinite.(cf))

        # Test vcov
        vc = GLM.vcov(model(result))
        @test size(vc, 1) == size(vc, 2) == length(cf)
        @test issymmetric(vc)

        # Test stderror
        se = GLM.stderror(model(result))
        @test length(se) == length(cf)
        @test all(se .> 0)  # All SEs should be positive

        # Test R²
        r_squared = GLM.r2(model(result))
        @test 0 <= r_squared <= 1

        # Test adjusted R²
        adj_r_squared = GLM.adjr2(model(result))
        @test adj_r_squared <= r_squared  # Adjusted R² ≤ R²
    end

    @testset "Model Coefficients: Match R's afex" begin
        # Between-subjects: 2 levels
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_between_2.csv"), DataFrame)
        result = anova(data, :dv, :subject, between = [:BF1])
        cf = GLM.coef(model(result))
        # R output: (Intercept) = -0.04827715, BF11 = -0.08217529
        @test cf[1] ≈ -0.04827715 atol = 1e-5  # (Intercept)
        @test cf[2] ≈ -0.08217529 atol = 1e-5  # BF11

        # Between-subjects: 3 levels
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_between_3.csv"), DataFrame)
        result = anova(data, :dv, :subject, between = [:BF1])
        cf = GLM.coef(model(result))
        # R output: (Intercept) = -0.04114429, BF11 = -0.26014640, BF12 = 0.22420237
        @test cf[1] ≈ -0.04114429 atol = 1e-5  # (Intercept)
        @test cf[2] ≈ -0.26014640 atol = 1e-5  # BF11
        @test cf[3] ≈ 0.22420237 atol = 1e-5  # BF12

        # Between-subjects: 2x2
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_between_2x2.csv"), DataFrame)
        result = anova(data, :dv, :subject, between = [:BF1, :BF2])
        cf = GLM.coef(model(result))
        # R output: (Intercept) = -0.146313133, BF11 = -0.195053924, BF21 = 0.136731668, BF11:BF21 = 0.009420449
        @test cf[1] ≈ -0.146313133 atol = 1e-5  # (Intercept)
        @test cf[2] ≈ -0.195053924 atol = 1e-5  # BF11
        @test cf[3] ≈ 0.136731668 atol = 1e-5  # BF21
        @test cf[4] ≈ 0.009420449 atol = 1e-5  # BF11:BF21

        # Within-subjects: 2 levels
        # Note: We use univariate model, so coefficients are in contrast form
        # R's multivariate model shows level means, but our univariate model shows intercept + contrasts
        # The actual ANOVA calculations are the same (univariate)
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_within_2.csv"), DataFrame)
        result = anova(data, :dv, :subject, within = [:WF1])
        m = model(result)
        # Univariate model coefficients (intercept + contrast)
        cf = GLM.coef(model(result))
        @test length(cf) == 2  # Intercept + one contrast
        @test all(isfinite.(values(cf)))

        # Within-subjects: 3 levels
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_within_3.csv"), DataFrame)
        result = anova(data, :dv, :subject, within = [:WF1])
        m = model(result)
        # Univariate model coefficients (intercept + two contrasts)
        cf = GLM.coef(model(result))
        @test length(cf) == 3  # Intercept + two contrasts
        @test all(isfinite.(values(cf)))
    end

    @testset "Model Diagnostics: Match R's afex" begin
        # Between-subjects: 2 levels - R², Adj R², Std Errors
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_between_2.csv"), DataFrame)
        result = anova(data, :dv, :subject, between = [:BF1])
        # R output: R² = 0.007880607, Adj R² = -0.00224306
        @test GLM.r2(model(result)) ≈ 0.007880607 atol = 1e-6
        @test GLM.adjr2(model(result)) ≈ -0.00224306 atol = 1e-6
        # R output: Std Errors = 0.09313873 for both coefficients
        se = GLM.stderror(model(result))
        @test se[1] ≈ 0.09313873 atol = 1e-6  # (Intercept)
        @test se[2] ≈ 0.09313873 atol = 1e-6  # BF11
        # R output: VCoV diagonal = 0.008674823 for both
        vc = GLM.vcov(model(result))
        @test vc[1, 1] ≈ 0.008674823 atol = 1e-6  # (Intercept)
        @test vc[2, 2] ≈ 0.008674823 atol = 1e-6  # BF11
        # R output: Residuals sum ≈ 0 (1.235123e-15)
        res = GLM.residuals(model(result))
        @test abs(sum(res)) < 1e-13
        # R output: First 5 residuals = [0.9387404, -1.1559706, -0.9741837, -0.4508908, 0.4180404]
        @test res[1] ≈ 0.9387404 atol = 1e-5
        @test res[2] ≈ -1.1559706 atol = 1e-5
        @test res[3] ≈ -0.9741837 atol = 1e-5
        @test res[4] ≈ -0.4508908 atol = 1e-5
        @test res[5] ≈ 0.4180404 atol = 1e-5
        # R output: First 5 fitted = [-0.13045243, 0.03389814, -0.13045243, 0.03389814, -0.13045243]
        fit_vals = GLM.fitted(model(result))
        @test fit_vals[1] ≈ -0.13045243 atol = 1e-6
        @test fit_vals[2] ≈ 0.03389814 atol = 1e-6
        @test fit_vals[3] ≈ -0.13045243 atol = 1e-6
        @test fit_vals[4] ≈ 0.03389814 atol = 1e-6
        @test fit_vals[5] ≈ -0.13045243 atol = 1e-6

        # Between-subjects: 3 levels - R², Adj R², Std Errors
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_between_3.csv"), DataFrame)
        result = anova(data, :dv, :subject, between = [:BF1])
        # R output: R² = 0.03688192, Adj R² = 0.01702381
        @test GLM.r2(model(result)) ≈ 0.03688192 atol = 1e-6
        @test GLM.adjr2(model(result)) ≈ 0.01702381 atol = 1e-6
        # R output: Std Errors = [0.1038042, 0.1460728, 0.1471643]
        se = GLM.stderror(model(result))
        @test se[1] ≈ 0.1038042 atol = 1e-6  # (Intercept)
        @test se[2] ≈ 0.1460728 atol = 1e-6  # BF11
        @test se[3] ≈ 0.1471643 atol = 1e-6  # BF12

        # Between-subjects: 2x2 - R², Adj R², Std Errors
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_between_2x2.csv"), DataFrame)
        result = anova(data, :dv, :subject, between = [:BF1, :BF2])
        # R output: R² = 0.06448141, Adj R² = 0.03524646
        @test GLM.r2(model(result)) ≈ 0.06448141 atol = 1e-6
        @test GLM.adjr2(model(result)) ≈ 0.03524646 atol = 1e-6
        # R output: Std Errors = 0.09267517 for all coefficients
        se = GLM.stderror(model(result))
        @test all(isapprox.(se, 0.09267517, atol = 1e-6))

        # Within-subjects: 2 levels - Residuals and Fitted (R returns NULL for R²)
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_within_2.csv"), DataFrame)
        result = anova(data, :dv, :subject, within = [:WF1])
        # R returns residuals as matrix (100 subjects × 2 levels), Julia returns long format vector
        # R output: First 5 residuals for F1_L1 = [-0.93777825, 0.94454728, 0.28000287, -0.02978133, -0.30356320]
        # R output: First 5 residuals for F1_L2 = [0.87901506, -0.62073914, 0.22915926, 0.34528951, 0.02888475]
        res = GLM.residuals(model(result))
        @test length(res) == nrow(data)
        @test abs(sum(res)) < 1e-13
        # Test residuals: Julia's long format alternates F1_L1, F1_L2, F1_L1, F1_L2, ...
        # So indices 1,3,5,7,9 are F1_L1 and 2,4,6,8,10 are F1_L2
        @test res[1] ≈ -0.93777825 atol = 1e-6  # Subject 1, F1_L1
        @test res[2] ≈ 0.87901506 atol = 1e-6   # Subject 1, F1_L2
        @test res[3] ≈ 0.94454728 atol = 1e-6   # Subject 2, F1_L1
        @test res[4] ≈ -0.62073914 atol = 1e-6  # Subject 2, F1_L2
        @test res[5] ≈ 0.28000287 atol = 1e-6   # Subject 3, F1_L1
        @test res[6] ≈ 0.22915926 atol = 1e-6   # Subject 3, F1_L2
        @test res[7] ≈ -0.02978133 atol = 1e-6   # Subject 4, F1_L1
        @test res[8] ≈ 0.34528951 atol = 1e-6   # Subject 4, F1_L2
        @test res[9] ≈ -0.30356320 atol = 1e-6   # Subject 5, F1_L1
        @test res[10] ≈ 0.02888475 atol = 1e-6   # Subject 5, F1_L2
        # R output: Fitted values are constant per level (0.0249403 for F1_L1, -0.02902921 for F1_L2)
        fit_vals = GLM.fitted(model(result))
        @test length(fit_vals) == nrow(data)
        @test fit_vals[1] ≈ 0.0249403 atol = 1e-6   # Subject 1, F1_L1
        @test fit_vals[2] ≈ -0.02902921 atol = 1e-6 # Subject 1, F1_L2
        @test fit_vals[3] ≈ 0.0249403 atol = 1e-6   # Subject 2, F1_L1
        @test fit_vals[4] ≈ -0.02902921 atol = 1e-6 # Subject 2, F1_L2
    end

    @testset "Within-subjects: Model Fitting" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_within_2x2.csv"), DataFrame)

        result = anova(data, :dv, :subject, within = [:WF1, :WF2])
        @test !isnothing(model(result))

        res = GLM.residuals(model(result))
        @test length(res) == nrow(data)
        @test sum(res) ≈ 0.0 atol = 1e-10

        # Test R² exists
        @test 0 <= GLM.r2(model(result)) <= 1
    end

    @testset "Mixed design: Model Fitting" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_mixed_WB_2x2.csv"), DataFrame)

        result = anova(data, :dv, :subject, within = [:WF1], between = [:BF1])
        @test !isnothing(model(result))

        res = GLM.residuals(model(result))
        fit_vals = GLM.fitted(model(result))
        @test all(isapprox.(fit_vals .+ res, data.dv, atol = 1e-10))

        # Test coefficients exist
        cf = GLM.coef(model(result))
        @test length(cf) >= 1
    end
end
