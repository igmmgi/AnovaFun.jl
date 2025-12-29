@testset "Estimated Marginal Means Tests" begin
    @testset "Within 2x2x2: WF1 marginal means" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_within_2x2x2.csv"), DataFrame)
        result = anova(data, :dv, :subject, within = [:WF1, :WF2, :WF3])
        em = emmeans(result)

        # Filter for WF1 main effect
        wf1_means = filter(row -> row.Effect == "WF1", em.means)

        # Expected values from R: emmeans(res_within_2x2x2, ~ WF1)
        @test nrow(wf1_means) == 2

        # F1_L1: R values: emmean=0.02086695, SE=0.05104823, df=99, CI=[-0.08042381, 0.1221577]
        f1_l1 = filter(row -> row.Level == "F1_L1", wf1_means)[1, :]
        @test isapprox(f1_l1.Mean, 0.02086695, rtol = RTOL_EMMEANS)
        @test isapprox(f1_l1.SE, 0.05104823, rtol = RTOL_EMMEANS)
        @test f1_l1.N == 100
        @test isapprox(f1_l1.Lower, -0.08042381, rtol = RTOL_EMMEANS)
        @test isapprox(f1_l1.Upper, 0.1221577, rtol = RTOL_EMMEANS)

        # F1_L2: R values: emmean=0.04602519, SE=0.05157833, df=99, CI=[-0.05631742, 0.1483678]
        f1_l2 = filter(row -> row.Level == "F1_L2", wf1_means)[1, :]
        @test isapprox(f1_l2.Mean, 0.04602519, rtol = RTOL_EMMEANS)
        @test isapprox(f1_l2.SE, 0.05157833, rtol = RTOL_EMMEANS)
        @test f1_l2.N == 100
        @test isapprox(f1_l2.Lower, -0.05631742, rtol = RTOL_EMMEANS)
        @test isapprox(f1_l2.Upper, 0.1483678, rtol = RTOL_EMMEANS)
    end

    @testset "Within 2x2x2: WF2 marginal means" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_within_2x2x2.csv"), DataFrame)
        result = anova(data, :dv, :subject, within = [:WF1, :WF2, :WF3])
        em = emmeans(result)

        # Filter for WF2 main effect
        wf2_means = filter(row -> row.Effect == "WF2", em.means)

        # Expected values from R: emmeans(res_within_2x2x2, ~ WF2)
        @test nrow(wf2_means) == 2

        # F2_L1: R values: emmean=-0.0630017, SE=0.05574203, df=99, CI=[-0.173606, 0.04760257]
        f2_l1 = filter(row -> row.Level == "F2_L1", wf2_means)[1, :]
        @test isapprox(f2_l1.Mean, -0.0630017, rtol = RTOL_EMMEANS)
        @test isapprox(f2_l1.SE, 0.05574203, rtol = RTOL_EMMEANS)
        @test f2_l1.N == 100
        @test isapprox(f2_l1.Lower, -0.173606, rtol = RTOL_EMMEANS)
        @test isapprox(f2_l1.Upper, 0.04760257, rtol = RTOL_EMMEANS)

        # F2_L2: R values: emmean=0.1298938, SE=0.04989835, df=99, CI=[0.0308847, 0.228903]
        f2_l2 = filter(row -> row.Level == "F2_L2", wf2_means)[1, :]
        @test isapprox(f2_l2.Mean, 0.1298938, rtol = RTOL_EMMEANS)
        @test isapprox(f2_l2.SE, 0.04989835, rtol = RTOL_EMMEANS)
        @test f2_l2.N == 100
        @test isapprox(f2_l2.Lower, 0.0308847, rtol = RTOL_EMMEANS)
        @test isapprox(f2_l2.Upper, 0.228903, rtol = RTOL_EMMEANS)
    end

    @testset "Within 2x2x2: Three-way interaction" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_within_2x2x2.csv"), DataFrame)
        result = anova(data, :dv, :subject, within = [:WF1, :WF2, :WF3])
        em = emmeans(result)

        # Filter for three-way interaction
        three_way = filter(row -> row.Effect == "WF1 × WF2 × WF3", em.means)

        # Expected values from R: emmeans(res_within_2x2x2, ~ WF1|WF2|WF3)
        @test nrow(three_way) == 8

        # Check specific cells against R values
        # F1_L1, F2_L1, F3_L1: R values: emmean=-0.1626, SE=0.1030, CI=[-0.3664, 0.0411]
        cell = filter(row -> row.Level == "F1_L1, F2_L1, F3_L1", three_way)[1, :]
        @test isapprox(cell.Mean, -0.1626, rtol = RTOL_EMMEANS)
        @test isapprox(cell.SE, 0.1030, rtol = RTOL_EMMEANS)
        @test cell.N == 100

        # F1_L2, F2_L2, F3_L2: R values: emmean=0.1571, SE=0.1110, CI=[-0.0624, 0.3765]
        cell = filter(row -> row.Level == "F1_L2, F2_L2, F3_L2", three_way)[1, :]
        @test isapprox(cell.Mean, 0.1571, rtol = RTOL_EMMEANS)
        @test isapprox(cell.SE, 0.1110, rtol = RTOL_EMMEANS)
        @test cell.N == 100

        # F1_L1, F2_L2, F3_L1: R values: emmean=0.0550, SE=0.0894, CI=[-0.1223, 0.2324]
        cell = filter(row -> row.Level == "F1_L1, F2_L2, F3_L1", three_way)[1, :]
        @test isapprox(cell.Mean, 0.0550, rtol = RTOL_EMMEANS)
        @test isapprox(cell.SE, 0.0894, rtol = RTOL_EMMEANS)
        @test cell.N == 100
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

    @testset "Mixed WWB 2x2x3: Marginal means" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_mixed_WWB_2x2x3.csv"), DataFrame)
        result = anova(data, :dv, :subject, within = [:WF1, :WF2], between = [:BF1])
        em = emmeans(result)

        # Check grand mean is present
        grand = filter(row -> row.Effect == "Grand Mean", em.means)
        @test nrow(grand) == 1

        # Check all main effects are present
        wf1 = filter(row -> row.Effect == "WF1", em.means)
        @test nrow(wf1) == 2

        wf2 = filter(row -> row.Effect == "WF2", em.means)
        @test nrow(wf2) == 2

        bf1 = filter(row -> row.Effect == "BF1", em.means)
        @test nrow(bf1) == 2  # Actually has 2 levels in test data

        # Check interactions
        wf1_wf2 = filter(row -> row.Effect == "WF1 × WF2", em.means)
        @test nrow(wf1_wf2) == 4  # 2x2

        wf1_bf1 = filter(row -> row.Effect == "BF1 × WF1", em.means)
        @test nrow(wf1_bf1) == 4  # 2x2 (not 2x3)

        # Check highest-order interaction
        three_way = filter(row -> row.Effect == "BF1 × WF1 × WF2", em.means)
        @test nrow(three_way) == 8  # 2x2x2 (not 2x2x3)
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

        # F1_L1: R values: emmean=-0.06103108, SE=0.1014479, df=98, CI=[-0.2623511, 0.1402889]
        f1_l1 = filter(row -> row.Level == "F1_L1", wf1)[1, :]
        @test isapprox(f1_l1.Mean, -0.06103108, rtol = RTOL_EMMEANS)
        @test isapprox(f1_l1.SE, 0.1014479, rtol = RTOL_EMMEANS)
        @test isapprox(f1_l1.Lower, -0.2623511, rtol = RTOL_EMMEANS)
        @test isapprox(f1_l1.Upper, 0.1402889, rtol = RTOL_EMMEANS)

        # F1_L2: R values: emmean=0.06357905, SE=0.1203017, df=98, CI=[-0.1751559, 0.302314]
        f1_l2 = filter(row -> row.Level == "F1_L2", wf1)[1, :]
        @test isapprox(f1_l2.Mean, 0.06357905, rtol = RTOL_EMMEANS)
        @test isapprox(f1_l2.SE, 0.1203017, rtol = RTOL_EMMEANS)
        @test isapprox(f1_l2.Lower, -0.1751559, rtol = RTOL_EMMEANS)
        @test isapprox(f1_l2.Upper, 0.302314, rtol = RTOL_EMMEANS)
    end

    @testset "Within 2x2: All effects present" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_within_2x2.csv"), DataFrame)
        result = anova(data, :dv, :subject, within = [:WF1, :WF2])
        em = emmeans(result)

        # Check all expected effects
        @test nrow(filter(row -> row.Effect == "Grand Mean", em.means)) == 1
        @test nrow(filter(row -> row.Effect == "WF1", em.means)) == 2
        @test nrow(filter(row -> row.Effect == "WF2", em.means)) == 2
        @test nrow(filter(row -> row.Effect == "WF1 × WF2", em.means)) == 4

        # Total should be 1 + 2 + 2 + 4 = 9
        @test nrow(em.means) == 9
    end

    @testset "Confidence intervals are valid" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_within_2x2.csv"), DataFrame)
        result = anova(data, :dv, :subject, within = [:WF1, :WF2])
        em = emmeans(result)

        # Check that Lower < Mean < Upper for all rows
        @test all(em.means.Lower .< em.means.Mean)
        @test all(em.means.Mean .< em.means.Upper)

        # Check that CI width matches 2 * t_crit * SE
        # We compute the exact t_crit from the CI and SE
        for row in eachrow(em.means)
            ci_width = row.Upper - row.Lower
            # The CI is constructed as Mean ± t_crit * SE, so:
            # t_crit = (Upper - Mean) / SE = (Mean - Lower) / SE
            t_crit = (row.Upper - row.Mean) / row.SE
            expected_width = 2 * t_crit * row.SE
            @test isapprox(ci_width, expected_width, rtol = RTOL_EMMEANS)
        end
    end

    @testset "Within 2 levels: WF1 marginal means" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_within_2.csv"), DataFrame)
        result = anova(data, :dv, :subject, within = [:WF1])
        em = emmeans(result)

        wf1_means = filter(row -> row.Effect == "WF1", em.means)
        @test nrow(wf1_means) == 2

        # F1_L1: R values: emmean=0.0249403, SE=0.1113254, df=99, CI=[-0.1959535, 0.2458341]
        f1_l1 = filter(row -> row.Level == "F1_L1", wf1_means)[1, :]
        @test isapprox(f1_l1.Mean, 0.0249403, rtol = RTOL_EMMEANS)
        @test isapprox(f1_l1.SE, 0.1113254, rtol = RTOL_EMMEANS)
        @test isapprox(f1_l1.Lower, -0.1959535, rtol = RTOL_EMMEANS)
        @test isapprox(f1_l1.Upper, 0.2458341, rtol = RTOL_EMMEANS)

        # F1_L2: R values: emmean=-0.02902921, SE=0.0940253, df=99, CI=[-0.2155958, 0.1575374]
        f1_l2 = filter(row -> row.Level == "F1_L2", wf1_means)[1, :]
        @test isapprox(f1_l2.Mean, -0.02902921, rtol = RTOL_EMMEANS)
        @test isapprox(f1_l2.SE, 0.0940253, rtol = RTOL_EMMEANS)
        @test isapprox(f1_l2.Lower, -0.2155958, rtol = RTOL_EMMEANS)
        @test isapprox(f1_l2.Upper, 0.1575374, rtol = RTOL_EMMEANS)
    end

    @testset "Within 3 levels: WF1 marginal means" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_within_3.csv"), DataFrame)
        result = anova(data, :dv, :subject, within = [:WF1])
        em = emmeans(result)

        wf1_means = filter(row -> row.Effect == "WF1", em.means)
        @test nrow(wf1_means) == 3

        # F1_L1: R values: emmean=-0.03306314, SE=0.1053431, df=99, CI=[-0.2420867, 0.1759604]
        f1_l1 = filter(row -> row.Level == "F1_L1", wf1_means)[1, :]
        @test isapprox(f1_l1.Mean, -0.03306314, rtol = RTOL_EMMEANS)
        @test isapprox(f1_l1.SE, 0.1053431, rtol = RTOL_EMMEANS)
        @test isapprox(f1_l1.Lower, -0.2420867, rtol = RTOL_EMMEANS)
        @test isapprox(f1_l1.Upper, 0.1759604, rtol = RTOL_EMMEANS)

        # F1_L2: R values: emmean=0.0387005, SE=0.09493681, df=99, CI=[-0.1496747, 0.2270757]
        f1_l2 = filter(row -> row.Level == "F1_L2", wf1_means)[1, :]
        @test isapprox(f1_l2.Mean, 0.0387005, rtol = RTOL_EMMEANS)
        @test isapprox(f1_l2.SE, 0.09493681, rtol = RTOL_EMMEANS)
        @test isapprox(f1_l2.Lower, -0.1496747, rtol = RTOL_EMMEANS)
        @test isapprox(f1_l2.Upper, 0.2270757, rtol = RTOL_EMMEANS)

        # F1_L3: R values: emmean=-0.1086139, SE=0.09456819, df=99, CI=[-0.2962577, 0.07902989]
        f1_l3 = filter(row -> row.Level == "F1_L3", wf1_means)[1, :]
        @test isapprox(f1_l3.Mean, -0.1086139, rtol = RTOL_EMMEANS)
        @test isapprox(f1_l3.SE, 0.09456819, rtol = RTOL_EMMEANS)
        @test isapprox(f1_l3.Lower, -0.2962577, rtol = RTOL_EMMEANS)
        @test isapprox(f1_l3.Upper, 0.07902989, rtol = RTOL_EMMEANS)
    end

    @testset "Within 2x3: Marginal means" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_within_2x3.csv"), DataFrame)
        result = anova(data, :dv, :subject, within = [:WF1, :WF2])
        em = emmeans(result)

        # WF1 main effect
        wf1 = filter(row -> row.Effect == "WF1", em.means)
        @test nrow(wf1) == 2

        # F1_L1: R values: emmean=0.003281966, SE=0.05813444, df=99, CI=[-0.1120694, 0.1186333]
        f1_l1 = filter(row -> row.Level == "F1_L1", wf1)[1, :]
        @test isapprox(f1_l1.Mean, 0.003281966, rtol = RTOL_EMMEANS)
        @test isapprox(f1_l1.SE, 0.05813444, rtol = RTOL_EMMEANS)
        @test isapprox(f1_l1.Lower, -0.1120694, rtol = RTOL_EMMEANS)
        @test isapprox(f1_l1.Upper, 0.1186333, rtol = RTOL_EMMEANS)

        # F1_L2: R values: emmean=-0.01854279, SE=0.06058802, df=99, CI=[-0.1387626, 0.101677]
        f1_l2 = filter(row -> row.Level == "F1_L2", wf1)[1, :]
        @test isapprox(f1_l2.Mean, -0.01854279, rtol = RTOL_EMMEANS)
        @test isapprox(f1_l2.SE, 0.06058802, rtol = RTOL_EMMEANS)
        @test isapprox(f1_l2.Lower, -0.1387626, rtol = RTOL_EMMEANS)
        @test isapprox(f1_l2.Upper, 0.101677, rtol = RTOL_EMMEANS)

        # WF2 main effect
        wf2 = filter(row -> row.Effect == "WF2", em.means)
        @test nrow(wf2) == 3

        # F2_L1: R values: emmean=0.07713898, SE=0.0752377, df=99, CI=[-0.07214893, 0.2264269]
        f2_l1 = filter(row -> row.Level == "F2_L1", wf2)[1, :]
        @test isapprox(f2_l1.Mean, 0.07713898, rtol = RTOL_EMMEANS)
        @test isapprox(f2_l1.SE, 0.0752377, rtol = RTOL_EMMEANS)
        @test isapprox(f2_l1.Lower, -0.07214893, rtol = RTOL_EMMEANS)
        @test isapprox(f2_l1.Upper, 0.2264269, rtol = RTOL_EMMEANS)

        # F2_L2: R values: emmean=-0.06466301, SE=0.08342011, df=99, CI=[-0.2301866, 0.1008606]
        f2_l2 = filter(row -> row.Level == "F2_L2", wf2)[1, :]
        @test isapprox(f2_l2.Mean, -0.06466301, rtol = RTOL_EMMEANS)
        @test isapprox(f2_l2.SE, 0.08342011, rtol = RTOL_EMMEANS)
        @test isapprox(f2_l2.Lower, -0.2301866, rtol = RTOL_EMMEANS)
        @test isapprox(f2_l2.Upper, 0.1008606, rtol = RTOL_EMMEANS)

        # F2_L3: R values: emmean=-0.03536721, SE=0.06525241, df=99, CI=[-0.1648421, 0.09410772]
        f2_l3 = filter(row -> row.Level == "F2_L3", wf2)[1, :]
        @test isapprox(f2_l3.Mean, -0.03536721, rtol = RTOL_EMMEANS)
        @test isapprox(f2_l3.SE, 0.06525241, rtol = RTOL_EMMEANS)
        @test isapprox(f2_l3.Lower, -0.1648421, rtol = RTOL_EMMEANS)
        @test isapprox(f2_l3.Upper, 0.09410772, rtol = RTOL_EMMEANS)
    end

    @testset "Between 3 levels: BF1 marginal means" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_between_3.csv"), DataFrame)
        result = anova(data, :dv, :subject, between = [:BF1])
        em = emmeans(result)

        bf1_means = filter(row -> row.Effect == "BF1", em.means)
        @test nrow(bf1_means) == 3

        # G1_L1: R values: emmean=-0.3012907, SE=0.1780052, df=97, CI=[-0.6545817, 0.05200028]
        g1_l1 = filter(row -> row.Level == "G1_L1", bf1_means)[1, :]
        @test isapprox(g1_l1.Mean, -0.3012907, rtol = RTOL_EMMEANS)
        @test isapprox(g1_l1.SE, 0.1780052, rtol = RTOL_EMMEANS)
        @test isapprox(g1_l1.Lower, -0.6545817, rtol = RTOL_EMMEANS)
        @test isapprox(g1_l1.Upper, 0.05200028, rtol = RTOL_EMMEANS)

        # G1_L2: R values: emmean=0.1830581, SE=0.1806821, df=97, CI=[-0.1755459, 0.541662]
        g1_l2 = filter(row -> row.Level == "G1_L2", bf1_means)[1, :]
        @test isapprox(g1_l2.Mean, 0.1830581, rtol = RTOL_EMMEANS)
        @test isapprox(g1_l2.SE, 0.1806821, rtol = RTOL_EMMEANS)
        @test isapprox(g1_l2.Lower, -0.1755459, rtol = RTOL_EMMEANS)
        @test isapprox(g1_l2.Upper, 0.541662, rtol = RTOL_EMMEANS)

        # G1_L3: R values: emmean=-0.005200259, SE=0.1806821, df=97, CI=[-0.3638042, 0.3534037]
        g1_l3 = filter(row -> row.Level == "G1_L3", bf1_means)[1, :]
        @test isapprox(g1_l3.Mean, -0.005200259, rtol = RTOL_EMMEANS)
        @test isapprox(g1_l3.SE, 0.1806821, rtol = RTOL_EMMEANS)
        @test isapprox(g1_l3.Lower, -0.3638042, rtol = RTOL_EMMEANS)
        @test isapprox(g1_l3.Upper, 0.3534037, rtol = RTOL_EMMEANS)
    end

    @testset "Between 2x2: BF1 and BF2 marginal means" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_between_2x2.csv"), DataFrame)
        result = anova(data, :dv, :subject, between = [:BF1, :BF2])
        em = emmeans(result)

        # BF1 main effect
        bf1 = filter(row -> row.Effect == "BF1", em.means)
        @test nrow(bf1) == 2

        # G1_L1: R values: emmean=-0.3413671, SE=0.1310625, df=96, CI=[-0.601524, -0.08121008]
        g1_l1 = filter(row -> row.Level == "G1_L1", bf1)[1, :]
        @test isapprox(g1_l1.Mean, -0.3413671, rtol = RTOL_EMMEANS)
        @test isapprox(g1_l1.SE, 0.1310625, rtol = RTOL_EMMEANS)
        @test isapprox(g1_l1.Lower, -0.601524, rtol = RTOL_EMMEANS)
        @test isapprox(g1_l1.Upper, -0.08121008, rtol = RTOL_EMMEANS)

        # G1_L2: R values: emmean=0.04874079, SE=0.1310625, df=96, CI=[-0.2114162, 0.3088978]
        g1_l2 = filter(row -> row.Level == "G1_L2", bf1)[1, :]
        @test isapprox(g1_l2.Mean, 0.04874079, rtol = RTOL_EMMEANS)
        @test isapprox(g1_l2.SE, 0.1310625, rtol = RTOL_EMMEANS)
        @test isapprox(g1_l2.Lower, -0.2114162, rtol = RTOL_EMMEANS)
        @test isapprox(g1_l2.Upper, 0.3088978, rtol = RTOL_EMMEANS)

        # BF2 main effect
        bf2 = filter(row -> row.Effect == "BF2", em.means)
        @test nrow(bf2) == 2

        # G2_L1: R values: emmean=-0.009581465, SE=0.1310625, df=96, CI=[-0.2697384, 0.2505755]
        g2_l1 = filter(row -> row.Level == "G2_L1", bf2)[1, :]
        @test isapprox(g2_l1.Mean, -0.009581465, rtol = RTOL_EMMEANS)
        @test isapprox(g2_l1.SE, 0.1310625, rtol = RTOL_EMMEANS)
        @test isapprox(g2_l1.Lower, -0.2697384, rtol = RTOL_EMMEANS)
        @test isapprox(g2_l1.Upper, 0.2505755, rtol = RTOL_EMMEANS)

        # G2_L2: R values: emmean=-0.2830448, SE=0.1310625, df=96, CI=[-0.5432018, -0.02288782]
        g2_l2 = filter(row -> row.Level == "G2_L2", bf2)[1, :]
        @test isapprox(g2_l2.Mean, -0.2830448, rtol = RTOL_EMMEANS)
        @test isapprox(g2_l2.SE, 0.1310625, rtol = RTOL_EMMEANS)
        @test isapprox(g2_l2.Lower, -0.5432018, rtol = RTOL_EMMEANS)
        @test isapprox(g2_l2.Upper, -0.02288782, rtol = RTOL_EMMEANS)
    end

    @testset "Within 2x2: WF1 and WF2 marginal means" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_within_2x2.csv"), DataFrame)
        result = anova(data, :dv, :subject, within = [:WF1, :WF2])
        em = emmeans(result)

        # WF1 main effect
        wf1 = filter(row -> row.Effect == "WF1", em.means)
        @test nrow(wf1) == 2

        # F1_L1: R values: emmean=-0.01386528, SE=0.07795743, df=99, CI=[-0.1685497, 0.1408192]
        f1_l1 = filter(row -> row.Level == "F1_L1", wf1)[1, :]
        @test isapprox(f1_l1.Mean, -0.01386528, rtol = RTOL_EMMEANS)
        @test isapprox(f1_l1.SE, 0.07795743, rtol = RTOL_EMMEANS)
        @test isapprox(f1_l1.Lower, -0.1685497, rtol = RTOL_EMMEANS)
        @test isapprox(f1_l1.Upper, 0.1408192, rtol = RTOL_EMMEANS)

        # F1_L2: R values: emmean=0.01021896, SE=0.07733165, df=99, CI=[-0.1432238, 0.1636617]
        f1_l2 = filter(row -> row.Level == "F1_L2", wf1)[1, :]
        @test isapprox(f1_l2.Mean, 0.01021896, rtol = RTOL_EMMEANS)
        @test isapprox(f1_l2.SE, 0.07733165, rtol = RTOL_EMMEANS)
        @test isapprox(f1_l2.Lower, -0.1432238, rtol = RTOL_EMMEANS)
        @test isapprox(f1_l2.Upper, 0.1636617, rtol = RTOL_EMMEANS)

        # WF2 main effect
        wf2 = filter(row -> row.Effect == "WF2", em.means)
        @test nrow(wf2) == 2

        # F2_L1: R values: emmean=-0.02320076, SE=0.06893284, df=99, CI=[-0.1599785, 0.113577]
        f2_l1 = filter(row -> row.Level == "F2_L1", wf2)[1, :]
        @test isapprox(f2_l1.Mean, -0.02320076, rtol = RTOL_EMMEANS)
        @test isapprox(f2_l1.SE, 0.06893284, rtol = RTOL_EMMEANS)
        @test isapprox(f2_l1.Lower, -0.1599785, rtol = RTOL_EMMEANS)
        @test isapprox(f2_l1.Upper, 0.113577, rtol = RTOL_EMMEANS)

        # F2_L2: R values: emmean=0.01955443, SE=0.08206975, df=99, CI=[-0.1432898, 0.1823986]
        f2_l2 = filter(row -> row.Level == "F2_L2", wf2)[1, :]
        @test isapprox(f2_l2.Mean, 0.01955443, rtol = RTOL_EMMEANS)
        @test isapprox(f2_l2.SE, 0.08206975, rtol = RTOL_EMMEANS)
        @test isapprox(f2_l2.Lower, -0.1432898, rtol = RTOL_EMMEANS)
        @test isapprox(f2_l2.Upper, 0.1823986, rtol = RTOL_EMMEANS)
    end

    @testset "Mixed WB 3x2: Marginal means" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_mixed_WB_3x2.csv"), DataFrame)
        result = anova(data, :dv, :subject, within = [:WF1], between = [:BF1])
        em = emmeans(result)

        # BF1 main effect
        bf1 = filter(row -> row.Effect == "BF1", em.means)
        @test nrow(bf1) == 2

        # G1_L1: R values: emmean=0.1801954, SE=0.08152538, df=98, CI=[0.01841091, 0.3419799]
        g1_l1 = filter(row -> row.Level == "G1_L1", bf1)[1, :]
        @test isapprox(g1_l1.Mean, 0.1801954, rtol = RTOL_EMMEANS)
        @test isapprox(g1_l1.SE, 0.08152538, rtol = RTOL_EMMEANS)
        @test isapprox(g1_l1.Lower, 0.01841091, rtol = RTOL_EMMEANS)
        @test isapprox(g1_l1.Upper, 0.3419799, rtol = RTOL_EMMEANS)

        # G1_L2: R values: emmean=0.02585295, SE=0.08152538, df=98, CI=[-0.1359315, 0.1876374]
        g1_l2 = filter(row -> row.Level == "G1_L2", bf1)[1, :]
        @test isapprox(g1_l2.Mean, 0.02585295, rtol = RTOL_EMMEANS)
        @test isapprox(g1_l2.SE, 0.08152538, rtol = RTOL_EMMEANS)
        @test isapprox(g1_l2.Lower, -0.1359315, rtol = RTOL_EMMEANS)
        @test isapprox(g1_l2.Upper, 0.1876374, rtol = RTOL_EMMEANS)

        # WF1 main effect
        wf1 = filter(row -> row.Effect == "WF1", em.means)
        @test nrow(wf1) == 3

        # F1_L1: R values: emmean=0.128633, SE=0.1060267, df=98, CI=[-0.08177355, 0.3390396]
        f1_l1 = filter(row -> row.Level == "F1_L1", wf1)[1, :]
        @test isapprox(f1_l1.Mean, 0.128633, rtol = RTOL_EMMEANS)
        @test isapprox(f1_l1.SE, 0.1060267, rtol = RTOL_EMMEANS)
        @test isapprox(f1_l1.Lower, -0.08177355, rtol = RTOL_EMMEANS)
        @test isapprox(f1_l1.Upper, 0.3390396, rtol = RTOL_EMMEANS)

        # F1_L2: R values: emmean=0.05187523, SE=0.1097527, df=98, CI=[-0.1659255, 0.269676]
        f1_l2 = filter(row -> row.Level == "F1_L2", wf1)[1, :]
        @test isapprox(f1_l2.Mean, 0.05187523, rtol = RTOL_EMMEANS)
        @test isapprox(f1_l2.SE, 0.1097527, rtol = RTOL_EMMEANS)
        @test isapprox(f1_l2.Lower, -0.1659255, rtol = RTOL_EMMEANS)
        @test isapprox(f1_l2.Upper, 0.269676, rtol = RTOL_EMMEANS)

        # F1_L3: R values: emmean=0.1285643, SE=0.09528463, df=98, CI=[-0.06052499, 0.3176535]
        f1_l3 = filter(row -> row.Level == "F1_L3", wf1)[1, :]
        @test isapprox(f1_l3.Mean, 0.1285643, rtol = RTOL_EMMEANS)
        @test isapprox(f1_l3.SE, 0.09528463, rtol = RTOL_EMMEANS)
        @test isapprox(f1_l3.Lower, -0.06052499, rtol = RTOL_EMMEANS)
        @test isapprox(f1_l3.Upper, 0.3176535, rtol = RTOL_EMMEANS)
    end

    @testset "Mixed WWB 2x2x3: Comprehensive marginal means" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_mixed_WWB_2x2x3.csv"), DataFrame)
        result = anova(data, :dv, :subject, within = [:WF1, :WF2], between = [:BF1])
        em = emmeans(result)

        # BF1 main effect
        bf1 = filter(row -> row.Effect == "BF1", em.means)
        @test nrow(bf1) == 2

        # G1_L1: R values: emmean=-0.04680735, SE=0.07284643, df=98, CI=[-0.1913687, 0.09775402]
        g1_l1 = filter(row -> row.Level == "G1_L1", bf1)[1, :]
        @test isapprox(g1_l1.Mean, -0.04680735, rtol = RTOL_EMMEANS)
        @test isapprox(g1_l1.SE, 0.07284643, rtol = RTOL_EMMEANS)
        @test isapprox(g1_l1.Lower, -0.1913687, rtol = RTOL_EMMEANS)
        @test isapprox(g1_l1.Upper, 0.09775402, rtol = RTOL_EMMEANS)

        # G1_L2: R values: emmean=0.03999692, SE=0.07284643, df=98, CI=[-0.1045644, 0.1845583]
        g1_l2 = filter(row -> row.Level == "G1_L2", bf1)[1, :]
        @test isapprox(g1_l2.Mean, 0.03999692, rtol = RTOL_EMMEANS)
        @test isapprox(g1_l2.SE, 0.07284643, rtol = RTOL_EMMEANS)
        @test isapprox(g1_l2.Lower, -0.1045644, rtol = RTOL_EMMEANS)
        @test isapprox(g1_l2.Upper, 0.1845583, rtol = RTOL_EMMEANS)

        # WF1 main effect
        wf1 = filter(row -> row.Effect == "WF1", em.means)
        @test nrow(wf1) == 2

        # F1_L1: R values: emmean=0.06212981, SE=0.07306527, df=98, CI=[-0.08286585, 0.2071255]
        f1_l1 = filter(row -> row.Level == "F1_L1", wf1)[1, :]
        @test isapprox(f1_l1.Mean, 0.06212981, rtol = RTOL_EMMEANS)
        @test isapprox(f1_l1.SE, 0.07306527, rtol = RTOL_EMMEANS)
        @test isapprox(f1_l1.Lower, -0.08286585, rtol = RTOL_EMMEANS)
        @test isapprox(f1_l1.Upper, 0.2071255, rtol = RTOL_EMMEANS)

        # F1_L2: R values: emmean=-0.06894023, SE=0.06732837, df=98
        f1_l2 = filter(row -> row.Level == "F1_L2", wf1)[1, :]
        @test isapprox(f1_l2.Mean, -0.06894023, rtol = RTOL_EMMEANS)
        @test isapprox(f1_l2.SE, 0.06732837, rtol = RTOL_EMMEANS)

        # WF2 main effect
        wf2 = filter(row -> row.Effect == "WF2", em.means)
        @test nrow(wf2) == 2

        # F2_L1: R values: emmean=0.04167216, SE=0.07093848, df=98, CI=[-0.09910295, 0.1824473]
        f2_l1 = filter(row -> row.Level == "F2_L1", wf2)[1, :]
        @test isapprox(f2_l1.Mean, 0.04167216, rtol = RTOL_EMMEANS)
        @test isapprox(f2_l1.SE, 0.07093848, rtol = RTOL_EMMEANS)
        @test isapprox(f2_l1.Lower, -0.09910295, rtol = RTOL_EMMEANS)
        @test isapprox(f2_l1.Upper, 0.1824473, rtol = RTOL_EMMEANS)

        # F2_L2: R values: emmean=-0.04848259, SE=0.07653646, df=98, CI=[-0.2003667, 0.1034015]
        f2_l2 = filter(row -> row.Level == "F2_L2", wf2)[1, :]
        @test isapprox(f2_l2.Mean, -0.04848259, rtol = RTOL_EMMEANS)
        @test isapprox(f2_l2.SE, 0.07653646, rtol = RTOL_EMMEANS)
        @test isapprox(f2_l2.Lower, -0.2003667, rtol = RTOL_EMMEANS)
        @test isapprox(f2_l2.Upper, 0.1034015, rtol = RTOL_EMMEANS)
    end
end
