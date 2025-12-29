@testset "Between-subjects designs" begin
    @testset "Between 2 levels" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_between_2.csv"), DataFrame)
        result = anova(data, :dv, :subject; between = [:BF1])
        emmeans_result = emmeans(result)

        expected = Dict(
            "BF1" => Dict(
                :DFn => 1,
                :DFd => 98,
                :SSn => 0.6752778,
                :SSd => 85.01327,
                :F => 0.778434,
                :p => 0.3797795,
            ),
        )
        check_anova_result(result, expected, emmeans_result; print_tables = true)
    end

    @testset "Between 3 levels" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_between_3.csv"), DataFrame)
        result = anova(data, :dv, :subject; between = [:BF1])
        emmeans_result = emmeans(result)

        expected = Dict(
            "BF1" => Dict(
                :DFn => 2,
                :DFd => 97,
                :SSn => 4.001749,
                :SSd => 104.4999,
                :F => 1.857273,
                :p => 0.161606,
            ),
        )
        check_anova_result(result, expected, emmeans_result; print_tables = true)
    end

    @testset "Between 2x2 design" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_between_2x2.csv"), DataFrame)
        result = anova(data, :dv, :subject; between = [:BF1, :BF2])
        emmeans_result = emmeans(result)
        pairwise_result = pairwise(emmeans_result, adjust = :bonferroni)

        expected = Dict(
            "BF1" => Dict(
                :DFn => 1,
                :DFd => 96,
                :SSn => 3.804603342,
                :SSd => 82.4514,
                :F => 4.42978423,
                :p => 0.03792888,
            ),
            "BF2" => Dict(
                :DFn => 1,
                :DFd => 96,
                :SSn => 1.869554906,
                :SSd => 82.4514,
                :F => 2.17676433,
                :p => 0.14338108,
            ),
            "BF1 × BF2" => Dict(
                :DFn => 1,
                :DFd => 96,
                :SSn => 0.008874487,
                :SSd => 82.4514,
                :F => 0.01033276,
                :p => 0.91924635,
            ),
        )
        check_anova_result(
            result,
            expected,
            emmeans_result,
            pairwise_result;
            print_tables = true,
        )
    end

    @testset "Between 2 levels: BF1 marginal means" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_between_2.csv"), DataFrame)
        result = anova(data, :dv, :subject, between = [:BF1])
        em = emmeans(result)

        # Filter for BF1 main effect
        bf1_means = filter(row -> row.Effect == "BF1", em.means)

        # Expected values from R: emmeans(res_between_2_afex, ~ BF1)
        @test nrow(bf1_means) == 2

        # G1_L1: R values: emmean=-0.1304524, SE=0.1317181, df=98, CI=[-0.3918426, 0.1309378]
        g1_l1 = filter(row -> row.Level == "G1_L1", bf1_means)[1, :]
        @test isapprox(g1_l1.Mean, -0.1304524, rtol = RTOL_EMMEANS)
        @test isapprox(g1_l1.SE, 0.1317181, rtol = RTOL_EMMEANS)
        @test g1_l1.N > 0
        @test isapprox(g1_l1.Lower, -0.3918426, rtol = RTOL_EMMEANS)
        @test isapprox(g1_l1.Upper, 0.1309378, rtol = RTOL_EMMEANS)

        # G1_L2: R values: emmean=0.03389814, SE=0.1317181, df=98, CI=[-0.2274921, 0.2952883]
        g1_l2 = filter(row -> row.Level == "G1_L2", bf1_means)[1, :]
        @test isapprox(g1_l2.Mean, 0.03389814, rtol = RTOL_EMMEANS)
        @test isapprox(g1_l2.SE, 0.1317181, rtol = RTOL_EMMEANS)
        @test g1_l2.N > 0
        @test isapprox(g1_l2.Lower, -0.2274921, rtol = RTOL_EMMEANS)
        @test isapprox(g1_l2.Upper, 0.2952883, rtol = RTOL_EMMEANS)
    end
end
