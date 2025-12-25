@testset "Homogeneity tests" begin
    @testset "Between-subjects homogeneity" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_between_2.csv"), DataFrame)
        result = anova(data, :dv, :subject; between = [:BF1])

        # Test that check_homogeneity works
        homogeneity_result = check_homogeneity(result)

        @test homogeneity_result isa AnovaResult
        @test design_type(homogeneity_result) == :between
        @test "group" in homogeneity_result.table.Effect

        # Test with median center
        homogeneity_result_median = check_homogeneity(result, center = median)
        @test homogeneity_result_median isa AnovaResult
    end

    @testset "Between-subjects 2x2 homogeneity" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_between_2x2.csv"), DataFrame)
        result = anova(data, :dv, :subject; between = [:BF1, :BF2])

        homogeneity_result = check_homogeneity(result)

        @test homogeneity_result isa AnovaResult
        @test "group" in homogeneity_result.table.Effect
    end

    @testset "Mixed design homogeneity" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_mixed_WB_2x2.csv"), DataFrame)
        result = anova(data, :dv, :subject; within = [:WF1], between = [:BF1])

        homogeneity_result = check_homogeneity(result)

        @test homogeneity_result isa AnovaResult
        @test "group" in homogeneity_result.table.Effect
    end

    @testset "Homogeneity error cases" begin
        # Test that within-subjects only design throws error
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_within_2.csv"), DataFrame)
        result = anova(data, :dv, :subject; within = [:WF1])

        @test_throws ArgumentError check_homogeneity(result)
    end
end
