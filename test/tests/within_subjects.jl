@testset "Within-subjects designs" begin
    @testset "Within 2 levels" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_within_2.csv"), DataFrame)
        result = anova(data, :dv, :subject; within = [:WF1])
        emmeans_result = emmeans(result)

        expected = Dict(
            "Intercept" => Dict(
                :DFn => 1,
                :DFd => 99,
                :SSn => 0.0008359615,
                :SSd => 96.33472,
                :F => 0.0008590899,
                :p => 0.9766762,
            ),
            "WF1" => Dict(
                :DFn => 1,
                :DFd => 99,
                :SSn => 0.1456354178,
                :SSd => 113.88293,
                :F => 0.1266028713,
                :p => 0.7227377,
            ),
        )
        check_anova_result(result, expected, emmeans_result; print_tables = true)
    end

    @testset "Within 3 levels" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_within_3.csv"), DataFrame)
        result = anova(data, :dv, :subject; within = [:WF1])
        emmeans_result = emmeans(result)

        expected = Dict(
            "Intercept" => Dict(
                :DFn => 1,
                :DFd => 99,
                :SSn => 0.3534723,
                :SSd => 100.4348,
                :F => 0.3484226,
                :p => 0.5563524,
            ),
            "WF1" => Dict(
                :DFn => 2,
                :DFd => 198,
                :SSn => 1.0853158,
                :SSd => 187.1930,
                :F => 0.5739867,
                :p => 0.5642098,
            ),
        )
        check_anova_result(result, expected, emmeans_result; print_tables = true)
    end

    @testset "Within 2x2 design" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_within_2x2.csv"), DataFrame)
        result = anova(data, :dv, :subject; within = [:WF1, :WF2])
        emmeans_result = emmeans(result)
        pairwise_result = pairwise(emmeans_result, adjust = :none)

        expected = Dict(
            "Intercept" => Dict(
                :DFn => 1,
                :DFd => 99,
                :SSn => 0.001329571,
                :SSd => 132.00702,
                :F => 0.0009971253,
                :p => 0.9748727,
            ),
            "WF1" => Dict(
                :DFn => 1,
                :DFd => 99,
                :SSn => 0.058005057,
                :SSd => 106.73237,
                :F => 0.0538028030,
                :p => 0.8170523,
            ),
            "WF2" => Dict(
                :DFn => 1,
                :DFd => 99,
                :SSn => 0.182800595,
                :SSd => 95.43917,
                :F => 0.1896208843,
                :p => 0.6641803,
            ),
            "WF1 × WF2" => Dict(
                :DFn => 1,
                :DFd => 99,
                :SSn => 0.001368326,
                :SSd => 72.21077,
                :F => 0.0018759559,
                :p => 0.9655398,
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

    @testset "Within 2x3 design" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_within_2x3.csv"), DataFrame)
        result = anova(data, :dv, :subject; within = [:WF1, :WF2])
        emmeans_result = emmeans(result)
        pairwise_result = pairwise(emmeans_result, adjust = :bonferroni)

        expected = Dict(
            "Intercept" => Dict(
                :DFn => 1,
                :DFd => 99,
                :SSn => 0.03493393,
                :SSd => 108.4575,
                :F => 0.03188768,
                :p => 0.8586393,
            ),
            "WF1" => Dict(
                :DFn => 1,
                :DFd => 99,
                :SSn => 0.07144803,
                :SSd => 100.9430,
                :F => 0.07007279,
                :p => 0.7917812,
            ),
            "WF2" => Dict(
                :DFn => 2,
                :DFd => 198,
                :SSn => 2.24157940,
                :SSd => 225.7170,
                :F => 0.98316191,
                :p => 0.3759451,
            ),
            "WF1 × WF2" => Dict(
                :DFn => 2,
                :DFd => 198,
                :SSn => 0.45663694,
                :SSd => 198.0305,
                :F => 0.22828325,
                :p => 0.7961080,
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

    @testset "Within 2x2x2 design" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_within_2x2x2.csv"), DataFrame)
        result = anova(data, :dv, :subject; within = [:WF1, :WF2, :WF3])
        emmeans_result = emmeans(result)

        expected = Dict(
            "Intercept" => Dict(
                :DFn => 1,
                :DFd => 99,
                :SSn => 0.89491175,
                :SSd => 105.33656,
                :F => 0.84107802,
                :p => 0.36131740,
            ),
            "WF1" => Dict(
                :DFn => 1,
                :DFd => 99,
                :SSn => 0.12658738,
                :SSd => 103.20680,
                :F => 0.12142757,
                :p => 0.72823124,
            ),
            "WF2" => Dict(
                :DFn => 1,
                :DFd => 99,
                :SSn => 7.44173854,
                :SSd => 116.30539,
                :F => 6.33446246,
                :p => 0.01344734,
            ),
            "WF3" => Dict(
                :DFn => 1,
                :DFd => 99,
                :SSn => 1.33904474,
                :SSd => 121.09795,
                :F => 1.09469593,
                :p => 0.29798092,
            ),
            "WF1 × WF2" => Dict(
                :DFn => 1,
                :DFd => 99,
                :SSn => 1.12722458,
                :SSd => 117.39287,
                :F => 0.95061335,
                :p => 0.33193959,
            ),
            "WF1 × WF3" => Dict(
                :DFn => 1,
                :DFd => 99,
                :SSn => 0.91143470,
                :SSd => 91.27970,
                :F => 0.98852245,
                :p => 0.32252769,
            ),
            "WF2 × WF3" => Dict(
                :DFn => 1,
                :DFd => 99,
                :SSn => 0.98294718,
                :SSd => 92.83782,
                :F => 1.04819104,
                :p => 0.30841929,
            ),
            "WF1 × WF2 × WF3" => Dict(
                :DFn => 1,
                :DFd => 99,
                :SSn => 0.07851792,
                :SSd => 94.01236,
                :F => 0.08268353,
                :p => 0.77429424,
            ),
        )
        check_anova_result(result, expected, emmeans_result; print_tables = true)
    end
end
