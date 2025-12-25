@testset "Sphericity tests" begin
    @testset "Within-subjects 3 levels sphericity" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_within_3.csv"), DataFrame)
        result = anova(data, :dv, :subject; within = [:WF1])

        # Test sphericity check
        sphericity_result = sphericity_check(result)

        @test sphericity_result isa DataFrame
        @test "Effect" in names(sphericity_result)
        @test "W" in names(sphericity_result)
        @test "p" in names(sphericity_result)
        @test "WF1" in sphericity_result.Effect
        @test all(0.0 .<= sphericity_result.W .<= 1.0)
        @test all(0.0 .<= sphericity_result.p .<= 1.0)
    end

    @testset "Within-subjects 2x2 sphericity" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_within_2x2.csv"), DataFrame)
        result = anova(data, :dv, :subject; within = [:WF1, :WF2])

        sphericity_result = sphericity_check(result)

        @test sphericity_result isa DataFrame
        # Should have sphericity tests for WF1, WF2, and WF1 × WF2
        # Note: WF1 and WF2 have 2 levels each, so they return W=1.0, p=1.0 (sphericity automatically satisfied)
        # WF1 × WF2 (4 cells) should have a meaningful test
        @test nrow(sphericity_result) >= 1
        # Filter out NaN values (shouldn't occur, but be safe)
        valid_rows = .!isnan.(sphericity_result.W) .& .!isnan.(sphericity_result.p)
        if any(valid_rows)
            @test all(0.0 .<= sphericity_result.W[valid_rows] .<= 1.0)
            @test all(0.0 .<= sphericity_result.p[valid_rows] .<= 1.0)
        end
    end

    @testset "Sphericity error cases" begin
        # Test that between-subjects only design throws error
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_between_2.csv"), DataFrame)
        result = anova(data, :dv, :subject; between = [:BF1])

        @test_throws ArgumentError sphericity_check(result)
    end

    @testset "Sphericity with 2 levels (should return W=1.0, p=1.0)" begin
        # Sphericity test with 2 levels returns W=1.0, p=1.0 (sphericity automatically satisfied)
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_within_2.csv"), DataFrame)
        result = anova(data, :dv, :subject; within = [:WF1])

        # Should return results with W=1.0, p=1.0 for 2-level factors
        sphericity_result = sphericity_check(result)
        @test sphericity_result isa DataFrame
        @test nrow(sphericity_result) > 0  # Should have at least one effect
        # For 2-level factors, sphericity is automatically satisfied
        # Use approximate equality for floating point comparison
        @test all(isapprox.(sphericity_result.W, 1.0, atol = 1e-10))
        @test all(isapprox.(sphericity_result.p, 1.0, atol = 1e-10))
    end

    @testset "Sphericity correction GG" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_within_3.csv"), DataFrame)
        result_gg = anova(data, :dv, :subject; within = [:WF1], correction = :GG)

        @test result_gg isa AnovaResult
        @test "ε" in names(result_gg.table)
        # Check that epsilon values are present for within-subjects effects
        within_rows = filter(row -> row.Effect != "Intercept", result_gg.table)
        if nrow(within_rows) > 0
            # Epsilon should be present (not NaN) and between 0 and 1
            epsilons = within_rows.ε
            @test all(.!isnan.(epsilons))
            @test all(0.0 .<= epsilons .<= 1.0)
        end
    end

    @testset "Sphericity correction HF" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_within_3.csv"), DataFrame)
        result_hf = anova(data, :dv, :subject; within = [:WF1], correction = :HF)

        @test result_hf isa AnovaResult
        @test "ε" in names(result_hf.table)
        # Check that epsilon values are present for within-subjects effects
        within_rows = filter(row -> row.Effect != "Intercept", result_hf.table)
        if nrow(within_rows) > 0
            # Epsilon should be present (not NaN) and between 0 and 1
            epsilons = within_rows.ε
            @test all(.!isnan.(epsilons))
            @test all(0.0 .<= epsilons .<= 1.0)
        end
    end

    @testset "Sphericity correction 2x2x2" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_within_2x2x2.csv"), DataFrame)
        result = anova(data, :dv, :subject; within = [:WF1, :WF2, :WF3], correction = :GG)

        @test result isa AnovaResult
        @test "ε" in names(result.table)
        # Some effects might have epsilon = 1.0 (2-level factors)
        within_rows = filter(row -> row.Effect != "Intercept", result.table)
        if nrow(within_rows) > 0
            epsilons = within_rows.ε
            @test all(.!isnan.(epsilons))
            @test all(0.0 .<= epsilons .<= 1.0)
        end
    end

    @testset "Sphericity correction mixed design" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_mixed_WB_2x2.csv"), DataFrame)
        result =
            anova(data, :dv, :subject; within = [:WF1], between = [:BF1], correction = :HF)

        @test result isa AnovaResult
        @test "ε" in names(result.table)
        # Within-subjects effects should have epsilon
        # Filter out Intercept and between-subjects effects
        within_rows = filter(
            row ->
                row.Effect != "Intercept" &&
                    row.Effect != "BF1" &&
                    !occursin("BF1", string(row.Effect)),
            result.table,
        )
        if nrow(within_rows) > 0
            epsilons = within_rows.ε
            @test all(.!isnan.(epsilons))
            @test all(0.0 .<= epsilons .<= 1.0)
        end
    end

    @testset "_is_within_effect_in_table edge cases" begin
        # Test with Intercept
        @test !AnovaFun._is_within_effect_in_table("Intercept", [:WF1])

        # Test with empty within_factors
        @test !AnovaFun._is_within_effect_in_table("WF1", Symbol[])

        # Test with within-subjects effect
        @test AnovaFun._is_within_effect_in_table("WF1", [:WF1])

        # Test with interaction
        @test AnovaFun._is_within_effect_in_table("WF1 × WF2", [:WF1, :WF2])

        # Test with mixed (should return false)
        @test !AnovaFun._is_within_effect_in_table("BF1 × WF1", [:WF1])
    end
end
