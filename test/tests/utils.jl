@testset "Utils helper functions" begin
    @testset "_adjust_ci" begin
        se = 1.0
        df = 10
        n = 5
        alpha = 0.05

        # Test :none method
        margin_none = AnovaFun._adjust_ci(se, df, :none, n, alpha)
        @test margin_none > 0

        # Test :bonferroni method
        margin_bonf = AnovaFun._adjust_ci(se, df, :bonferroni, n, alpha)
        @test margin_bonf > margin_none  # Bonferroni should be more conservative

        # Test :sidak method
        margin_sidak = AnovaFun._adjust_ci(se, df, :sidak, n, alpha)
        @test margin_sidak > margin_none  # Sidak should be more conservative
        @test margin_sidak < margin_bonf  # Sidak is less conservative than Bonferroni
    end

    @testset "_get_anova_row_info" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_between_2.csv"), DataFrame)
        result = anova(data, :dv, :subject; between = [:BF1])

        # Test with AnovaResult
        info = AnovaFun._get_anova_row_info(result, "BF1")
        @test !isnothing(info)
        @test hasproperty(info, :dfn)
        @test hasproperty(info, :dfd)
        @test hasproperty(info, :mse)

        # Test with DataFrame
        info2 = AnovaFun._get_anova_row_info(result.table, "BF1")
        @test !isnothing(info2)

        # Test with nonexistent effect
        info3 = AnovaFun._get_anova_row_info(result, "Nonexistent")
        @test isnothing(info3)
    end

    @testset "_combinations" begin
        arr = [:A, :B, :C]

        # Test k=0
        @test AnovaFun._combinations(arr, 0) == [Symbol[]]

        # Test k=1
        combos1 = AnovaFun._combinations(arr, 1)
        @test length(combos1) == 3
        @test [:A] in combos1

        # Test k=2
        combos2 = AnovaFun._combinations(arr, 2)
        @test length(combos2) == 3
        @test [:A, :B] in combos2

        # Test k > length
        @test isempty(AnovaFun._combinations(arr, 4))
    end

    @testset "_effect_name and _parse_effect_name" begin
        # Single factor
        @test AnovaFun._effect_name([:A]) == "A"

        # Multiple factors
        effect_str = AnovaFun._effect_name([:A, :B, :C])
        @test occursin("A", effect_str)
        @test occursin("B", effect_str)
        @test occursin("C", effect_str)
        @test occursin("×", effect_str)

        # Parse back
        parsed = AnovaFun._parse_effect_name(effect_str)
        @test :A in parsed
        @test :B in parsed
        @test :C in parsed

        # Round trip
        @test sort(AnovaFun._parse_effect_name(AnovaFun._effect_name([:A, :B]))) == [:A, :B]
    end

    @testset "_subject_condition_matrix" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_within_2x2.csv"), DataFrame)

        # Test with aggregate=true (default)
        Y1 = AnovaFun._subject_condition_matrix(
            data,
            :dv,
            :subject,
            [:WF1, :WF2];
            aggregate = true,
        )
        @test Y1 isa Matrix{Float64}
        @test size(Y1, 1) == length(unique(data.subject))
        @test size(Y1, 2) == 4  # 2x2 = 4 conditions

        # Test with aggregate=false
        # First aggregate the data to ensure one value per cell
        data_agg = AnovaFun.aggregate(data, :dv, :subject, [:WF1, :WF2], nothing)
        Y2 = AnovaFun._subject_condition_matrix(
            data_agg,
            :dv,
            :subject,
            [:WF1, :WF2];
            aggregate = false,
        )
        @test Y2 isa Matrix{Float64}
        @test size(Y2, 1) == size(Y1, 1)
        @test size(Y2, 2) == size(Y1, 2)
    end

    @testset "aggregate function" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_mixed_WB_2x2.csv"), DataFrame)

        # Test aggregation
        agg_data = AnovaFun.aggregate(data, :dv, :subject, [:WF1], [:BF1])
        @test agg_data isa DataFrame
        @test "dv" in names(agg_data) || :dv in names(agg_data)
        @test nrow(agg_data) <= nrow(data)

        # Test with no factors
        agg_data2 = AnovaFun.aggregate(data, :dv, :subject, nothing, nothing)
        @test agg_data2 isa DataFrame
    end
end
