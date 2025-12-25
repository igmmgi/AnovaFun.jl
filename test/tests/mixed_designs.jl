@testset "Mixed designs" begin
    @testset "Mixed WB 2x2" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_mixed_WB_2x2.csv"), DataFrame)
        result = anova(data, :dv, :subject; within = [:WF1], between = [:BF1])
        emmeans_result = emmeans(result)
        pairwise_result = pairwise(emmeans_result, adjust = :bonferroni)

        expected = Dict(
            "Intercept" => Dict(
                :DFn => 1,
                :DFd => 98,
                :SSn => 0.0003246079,
                :SSd => 114.9733,
                :F => 0.0002766867,
                :p => 0.9867625,
            ),
            "BF1" => Dict(
                :DFn => 1,
                :DFd => 98,
                :SSn => 0.6958567069,
                :SSd => 114.9733,
                :F => 0.5931287906,
                :p => 0.4430643,
            ),
            "WF1" => Dict(
                :DFn => 1,
                :DFd => 98,
                :SSn => 0.7763841670,
                :SSd => 127.7157,
                :F => 0.5957422358,
                :p => 0.4420644,
            ),
            "BF1 × WF1" => Dict(
                :DFn => 1,
                :DFd => 98,
                :SSn => 0.0080313979,
                :SSd => 127.7157,
                :F => 0.0061627261,
                :p => 0.9375880,
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

    @testset "Mixed WB 3x2" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_mixed_WB_3x2.csv"), DataFrame)
        result = anova(data, :dv, :subject; within = [:WF1], between = [:BF1])
        emmeans_result = emmeans(result)

        expected = Dict(
            "Intercept" => Dict(
                :DFn => 1,
                :DFd => 98,
                :SSn => 3.1841937,
                :SSd => 97.70191,
                :F => 3.1939088,
                :p => 0.07700462,
            ),
            "BF1" => Dict(
                :DFn => 1,
                :DFd => 98,
                :SSn => 1.7866190,
                :SSd => 97.70191,
                :F => 1.7920701,
                :p => 0.18377139,
            ),
            "WF1" => Dict(
                :DFn => 2,
                :DFd => 196,
                :SSn => 0.3924324,
                :SSd => 219.48967,
                :F => 0.1752172,
                :p => 0.83940600,
            ),
            "BF1 × WF1" => Dict(
                :DFn => 2,
                :DFd => 196,
                :SSn => 2.0724035,
                :SSd => 219.48967,
                :F => 0.9253080,
                :p => 0.39813389,
            ),
        )
        check_anova_result(result, expected, emmeans_result; print_tables = true)
    end

    @testset "Mixed WWB 2x2x3" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_mixed_WWB_2x2x3.csv"), DataFrame)
        result = anova(data, :dv, :subject; within = [:WF1, :WF2], between = [:BF1])
        emmeans_result = emmeans(result)

        expected = Dict(
            "Intercept" => Dict(
                :DFn => 1,
                :DFd => 98,
                :SSn => 0.004638188,
                :SSd => 104.00940,
                :F => 0.004370206,
                :p => 0.94742689,
            ),
            "BF1" => Dict(
                :DFn => 1,
                :DFd => 98,
                :SSn => 0.753498057,
                :SSd => 104.00940,
                :F => 0.709962877,
                :p => 0.40150784,
            ),
            "WF1" => Dict(
                :DFn => 1,
                :DFd => 98,
                :SSn => 1.717935604,
                :SSd => 89.47482,
                :F => 1.881620884,
                :p => 0.17328232,
            ),
            "WF2" => Dict(
                :DFn => 1,
                :DFd => 98,
                :SSn => 0.812787934,
                :SSd => 109.43652,
                :F => 0.727848580,
                :p => 0.39566182,
            ),
            "BF1 × WF1" => Dict(
                :DFn => 1,
                :DFd => 98,
                :SSn => 1.170552862,
                :SSd => 89.47482,
                :F => 1.282083395,
                :p => 0.26027488,
            ),
            "BF1 × WF2" => Dict(
                :DFn => 1,
                :DFd => 98,
                :SSn => 0.356567612,
                :SSd => 109.43652,
                :F => 0.319304974,
                :p => 0.57331694,
            ),
            "WF1 × WF2" => Dict(
                :DFn => 1,
                :DFd => 98,
                :SSn => 6.606470076,
                :SSd => 99.01734,
                :F => 6.538592631,
                :p => 0.01208969,
            ),
            "BF1 × WF1 × WF2" => Dict(
                :DFn => 1,
                :DFd => 98,
                :SSn => 2.252414719,
                :SSd => 99.01734,
                :F => 2.229272534,
                :p => 0.13863017,
            ),
        )
        check_anova_result(result, expected, emmeans_result; print_tables = true)
    end

    @testset "Mixed WB 2x2: Main effects with R values" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_mixed_WB_2x2.csv"), DataFrame)
        result = anova(data, :dv, :subject, within = [:WF1], between = [:BF1])
        em = emmeans(result)

        # BF1 main effect: R values from emmeans(res_mixed_WB_2x2_afex, ~ BF1)
        bf1 = filter(row -> row.Effect == "BF1", em.means)
        @test nrow(bf1) == 2

        # G1_L1: R values: emmean=-0.05771147, SE=0.1083142, df=98, CI=[-0.2726575, 0.1572345]
        g1_l1 = filter(row -> row.Level == "G1_L1", bf1)[1, :]
        @test isapprox(g1_l1.Mean, -0.05771147, rtol = RTOL_EMMEANS)
        @test isapprox(g1_l1.SE, 0.1083142, rtol = RTOL_EMMEANS)
        @test isapprox(g1_l1.Lower, -0.2726575, rtol = RTOL_EMMEANS)
        @test isapprox(g1_l1.Upper, 0.1572345, rtol = RTOL_EMMEANS)

        # G1_L2: R values: emmean=0.06025944, SE=0.1083142, df=98, CI=[-0.1546866, 0.2752054]
        g1_l2 = filter(row -> row.Level == "G1_L2", bf1)[1, :]
        @test isapprox(g1_l2.Mean, 0.06025944, rtol = RTOL_EMMEANS)
        @test isapprox(g1_l2.SE, 0.1083142, rtol = RTOL_EMMEANS)
        @test isapprox(g1_l2.Lower, -0.1546866, rtol = RTOL_EMMEANS)
        @test isapprox(g1_l2.Upper, 0.2752054, rtol = RTOL_EMMEANS)

        # WF1 main effect: R values from emmeans(res_mixed_WB_2x2_afex, ~ WF1)
        wf1 = filter(row -> row.Effect == "WF1", em.means)
        @test nrow(wf1) == 2
    end
end
