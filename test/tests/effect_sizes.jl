@testset "Effect sizes" begin
    @testset "Eta squared (:es)" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_between_2.csv"), DataFrame)
        result = anova(data, :dv, :subject; between = [:BF1], effect_size = :es)

        @test result isa AnovaResult
        @test "η²" in names(result.table)
        # Eta squared should be between 0 and 1
        eta2_values = result.table[!, "η²"]
        @test all(0.0 .<= eta2_values .<= 1.0)
        @test all(.!isnan.(eta2_values))
    end

    @testset "Omega squared (:os)" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_between_2.csv"), DataFrame)
        result = anova(data, :dv, :subject; between = [:BF1], effect_size = :os)

        @test result isa AnovaResult
        @test "ω²" in names(result.table)
        # Omega squared should be between 0 and 1 (clamped to 0 if negative)
        omega2_values = result.table[!, "ω²"]
        @test all(0.0 .<= omega2_values .<= 1.0)
        @test all(.!isnan.(omega2_values))
    end

    @testset "Eta squared within-subjects" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_within_3.csv"), DataFrame)
        result = anova(data, :dv, :subject; within = [:WF1], effect_size = :es)

        @test result isa AnovaResult
        @test "η²" in names(result.table)
        eta2_values = result.table[!, "η²"]
        @test all(0.0 .<= eta2_values .<= 1.0)
        @test all(.!isnan.(eta2_values))
    end

    @testset "Omega squared within-subjects" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_within_3.csv"), DataFrame)
        result = anova(data, :dv, :subject; within = [:WF1], effect_size = :os)

        @test result isa AnovaResult
        @test "ω²" in names(result.table)
        omega2_values = result.table[!, "ω²"]
        @test all(0.0 .<= omega2_values .<= 1.0)
        @test all(.!isnan.(omega2_values))
    end

    @testset "Eta squared mixed design" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_mixed_WB_2x2.csv"), DataFrame)
        result =
            anova(data, :dv, :subject; within = [:WF1], between = [:BF1], effect_size = :es)

        @test result isa AnovaResult
        @test "η²" in names(result.table)
        eta2_values = result.table[!, "η²"]
        @test all(0.0 .<= eta2_values .<= 1.0)
        @test all(.!isnan.(eta2_values))
    end

    @testset "Omega squared mixed design" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_mixed_WB_2x2.csv"), DataFrame)
        result =
            anova(data, :dv, :subject; within = [:WF1], between = [:BF1], effect_size = :os)

        @test result isa AnovaResult
        @test "ω²" in names(result.table)
        omega2_values = result.table[!, "ω²"]
        @test all(0.0 .<= omega2_values .<= 1.0)
        @test all(.!isnan.(omega2_values))
    end

    @testset "Eta squared 2x2 between" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_between_2x2.csv"), DataFrame)
        result = anova(data, :dv, :subject; between = [:BF1, :BF2], effect_size = :es)

        @test result isa AnovaResult
        @test "η²" in names(result.table)
        # Should have eta squared for all effects
        effects_with_eta2 = filter(row -> row.Effect != "Intercept", result.table)
        @test all(.!isnan.(effects_with_eta2[!, "η²"]))
    end

    @testset "Omega squared 2x2 between" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_between_2x2.csv"), DataFrame)
        result = anova(data, :dv, :subject; between = [:BF1, :BF2], effect_size = :os)

        @test result isa AnovaResult
        @test "ω²" in names(result.table)
        # Should have omega squared for all effects
        effects_with_omega2 = filter(row -> row.Effect != "Intercept", result.table)
        @test all(.!isnan.(effects_with_omega2[!, "ω²"]))
    end

    @testset "Within×within interaction multivariate path" begin
        # Test the path where there are no between factors in a within×within interaction
        # This triggers the else branch in _compute_within_within_error_multivariate
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_within_2x2.csv"), DataFrame)
        result = anova(data, :dv, :subject; within = [:WF1, :WF2])

        @test result isa AnovaResult
        # Should have WF1 × WF2 interaction
        interaction_row = filter(row -> row.Effect == "WF1 × WF2", result.table)
        @test nrow(interaction_row) == 1
        @test interaction_row[1, :F] >= 0
        @test interaction_row[1, :p] >= 0
    end

    @testset "Empty between factors error calculation" begin
        # Test the path where between is empty in _compute_between_error_ss
        # This happens in within-subjects designs
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_within_3.csv"), DataFrame)
        result = anova(data, :dv, :subject; within = [:WF1])

        @test result isa AnovaResult
        # Should have valid results
        @test nrow(result.table) > 0
        @test all(.!isnan.(result.table.F))
    end
end
