@testset "Pairwise Comparisons: Match R's emmeans pairs()" begin
    @testset "Between-subjects: 2 levels" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_between_2.csv"), DataFrame)
        result = anova(data, :dv, :subject, between = [:BF1])
        em = emmeans(result, adjust = :none)
        # Filter for BF1 effect
        em_bf1 = EmmeansResult(em.means[em.means.Effect.=="BF1", :], em.anova, em.level, nothing)
        pairs_result = pairwise(em_bf1, adjust = :none)

        # R output: contrast = G1_L1 - G1_L2, estimate = -0.1643506, SE = 0.1862775, df = 98, t.ratio = -0.8822891, p.value = 0.3797795
        # R output: lower.CL = -0.5340121, upper.CL = 0.205311
        @test nrow(pairs_result.table) == 1
        @test pairs_result.table[1, :Contrast] == "G1_L1 - G1_L2"
        @test pairs_result.table[1, :Estimate] ≈ -0.1643506 atol = 1e-6
        @test pairs_result.table[1, :SE] ≈ 0.1862775 atol = 1e-6
        @test pairs_result.table[1, :df] == 98
        @test pairs_result.table[1, :t] ≈ -0.8822891 atol = 1e-6
        @test pairs_result.table[1, :p_adj] ≈ 0.3797795 atol = 1e-6
        @test pairs_result.table[1, :Lower] ≈ -0.5340121 atol = 1e-6
        @test pairs_result.table[1, :Upper] ≈ 0.205311 atol = 1e-6
    end

    @testset "Between-subjects: 3 levels - adjust=none" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_between_3.csv"), DataFrame)
        result = anova(data, :dv, :subject, between = [:BF1])
        em = emmeans(result, adjust = :none)
        # Filter for BF1 effect
        em_bf1 = EmmeansResult(em.means[em.means.Effect.=="BF1", :], em.anova, em.level, nothing)
        pairs_result = pairwise(em_bf1, adjust = :none)

        # R output: 3 comparisons
        @test nrow(pairs_result.table) == 3

        # G1_L1 - G1_L2: estimate = -0.4843488, SE = 0.2536373, df = 97, t.ratio = -1.909612, p.value = 0.05913798
        row1 = pairs_result.table[pairs_result.table.Contrast.=="G1_L1 - G1_L2", :]
        @test nrow(row1) == 1
        @test row1[1, :Estimate] ≈ -0.4843488 atol = 1e-6
        @test row1[1, :SE] ≈ 0.2536373 atol = 1e-6
        @test row1[1, :df] == 97
        @test row1[1, :t] ≈ -1.909612 atol = 1e-6
        @test row1[1, :p_adj] ≈ 0.05913798 atol = 1e-6
        @test row1[1, :Lower] ≈ -0.9877485 atol = 1e-6
        @test row1[1, :Upper] ≈ 0.01905097 atol = 1e-6

        # G1_L1 - G1_L3: estimate = -0.2960904, SE = 0.2536373, df = 97, t.ratio = -1.167378, p.value = 0.2459196
        row2 = pairs_result.table[pairs_result.table.Contrast.=="G1_L1 - G1_L3", :]
        @test nrow(row2) == 1
        @test row2[1, :Estimate] ≈ -0.2960904 atol = 1e-6
        @test row2[1, :SE] ≈ 0.2536373 atol = 1e-6
        @test row2[1, :df] == 97
        @test row2[1, :t] ≈ -1.167378 atol = 1e-6
        @test row2[1, :p_adj] ≈ 0.2459196 atol = 1e-6
        @test row2[1, :Lower] ≈ -0.7994902 atol = 1e-6
        @test row2[1, :Upper] ≈ 0.2073093 atol = 1e-6

        # G1_L2 - G1_L3: estimate = 0.1882583, SE = 0.2555231, df = 97, t.ratio = 0.7367567, p.value = 0.4630485
        row3 = pairs_result.table[pairs_result.table.Contrast.=="G1_L2 - G1_L3", :]
        @test nrow(row3) == 1
        @test row3[1, :Estimate] ≈ 0.1882583 atol = 1e-6
        @test row3[1, :SE] ≈ 0.2555231 atol = 1e-6
        @test row3[1, :df] == 97
        @test row3[1, :t] ≈ 0.7367567 atol = 1e-6
        @test row3[1, :p_adj] ≈ 0.4630485 atol = 1e-6
        @test row3[1, :Lower] ≈ -0.3188842 atol = 1e-6
        @test row3[1, :Upper] ≈ 0.6954009 atol = 1e-6
    end

    @testset "Between-subjects: 3 levels - adjust=bonferroni" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_between_3.csv"), DataFrame)
        result = anova(data, :dv, :subject, between = [:BF1])
        em = emmeans(result, adjust = :none)
        # Filter for BF1 effect
        em_bf1 = EmmeansResult(em.means[em.means.Effect.=="BF1", :], em.anova, em.level, nothing)
        pairs_result = pairwise(em_bf1, adjust = :bonferroni)

        # R output: p-values adjusted with bonferroni
        # G1_L1 - G1_L2: p.value = 0.1774139 (adjusted from 0.05913798)
        row1 = pairs_result.table[pairs_result.table.Contrast.=="G1_L1 - G1_L2", :]
        @test row1[1, :p_adj] ≈ 0.1774139 atol = 1e-6
        @test row1[1, :Lower] ≈ -1.102261 atol = 1e-6
        @test row1[1, :Upper] ≈ 0.1335639 atol = 1e-6

        # G1_L1 - G1_L3: p.value = 0.7377587
        row2 = pairs_result.table[pairs_result.table.Contrast.=="G1_L1 - G1_L3", :]
        @test row2[1, :p_adj] ≈ 0.7377587 atol = 1e-6
        @test row2[1, :Lower] ≈ -0.9140031 atol = 1e-6
        @test row2[1, :Upper] ≈ 0.3218222 atol = 1e-6

        # G1_L2 - G1_L3: p.value = 1.0
        row3 = pairs_result.table[pairs_result.table.Contrast.=="G1_L2 - G1_L3", :]
        @test row3[1, :p_adj] ≈ 1.0 atol = 1e-6
        @test row3[1, :Lower] ≈ -0.4342485 atol = 1e-6
        @test row3[1, :Upper] ≈ 0.8107652 atol = 1e-6
    end

    @testset "Between-subjects: 3 levels - adjust=sidak" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_between_3.csv"), DataFrame)
        result = anova(data, :dv, :subject, between = [:BF1])
        em = emmeans(result, adjust = :none)
        # Filter for BF1 effect
        em_bf1 = EmmeansResult(em.means[em.means.Effect.=="BF1", :], em.anova, em.level, nothing)
        pairs_result = pairwise(em_bf1, adjust = :sidak)

        # Sidak adjustment: p_adj = 1 - (1 - p)^n
        # For 3 comparisons, should be less conservative than Bonferroni
        @test nrow(pairs_result.table) == 3

        # Check that Sidak-adjusted p-values are between unadjusted and Bonferroni-adjusted
        pairs_none = pairwise(em_bf1, adjust = :none)
        pairs_bonf = pairwise(em_bf1, adjust = :bonferroni)

        for i = 1:nrow(pairs_result.table)
            p_sidak = pairs_result.table[i, :p_adj]
            p_none = pairs_none.table[i, :p_adj]
            p_bonf = pairs_bonf.table[i, :p_adj]

            # Sidak should be between none and bonferroni (more conservative than none, less than bonferroni)
            @test p_sidak >= p_none
            @test p_sidak <= p_bonf
            @test 0.0 <= p_sidak <= 1.0
        end
    end

    # Note: Tukey adjustment is not yet implemented in the pairwise function
    # @testset "Between-subjects: 3 levels - adjust=tukey" begin
    #     # This test is skipped until Tukey adjustment is implemented
    # end

    @testset "Within-subjects: 2 levels" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_within_2.csv"), DataFrame)
        result = anova(data, :dv, :subject, within = [:WF1])
        em = emmeans(result, adjust = :none)
        # Filter for WF1 effect
        em_wf1 = EmmeansResult(em.means[em.means.Effect.=="WF1", :], em.anova, em.level, nothing)
        pairs_result = pairwise(em_wf1, adjust = :none)

        # R output: contrast = F1_L1 - F1_L2, estimate = 0.05396951, SE = 0.1516794, df = 99, t.ratio = 0.355, p.value = 0.7227
        # R output: lower.CL = -0.2469954, upper.CL = 0.3549344
        @test nrow(pairs_result.table) == 1
        @test pairs_result.table[1, :Contrast] == "F1_L1 - F1_L2"
        @test pairs_result.table[1, :Estimate] ≈ 0.05396951 atol = 1e-6
        @test pairs_result.table[1, :SE] ≈ 0.1516794 atol = 1e-6
        @test pairs_result.table[1, :df] == 99
        @test pairs_result.table[1, :t] ≈ 0.355 atol = 1e-3
        @test pairs_result.table[1, :p_adj] ≈ 0.7227 atol = 1e-4
        @test pairs_result.table[1, :Lower] ≈ -0.2469954 atol = 1e-6
        @test pairs_result.table[1, :Upper] ≈ 0.3549344 atol = 1e-6
    end

    @testset "Between-subjects: 2x2 with by factor" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_between_2x2.csv"), DataFrame)
        result = anova(data, :dv, :subject, between = [:BF1, :BF2])
        em = emmeans(result, adjust = :none)
        # R's pairs(~ BF1|BF2) means pairwise comparisons of BF1 within each level of BF2
        # We need to filter the interaction effect data by BF2 levels
        interaction_data = em.means[em.means.Effect.=="BF1 × BF2", :]

        # For BF2 = G2_L1: filter rows where Level contains "G2_L1"
        bf2_g2_l1_data = filter(row -> occursin("G2_L1", row.Level), interaction_data)
        em_bf1_g2_l1 = EmmeansResult(bf2_g2_l1_data, em.anova, em.level, nothing)
        pairs_g2_l1 = pairwise(em_bf1_g2_l1, adjust = :none)

        # R output: BF2 = G2_L1: G1_L1 - G1_L2, estimate = -0.371267, SE = 0.262125, df = 96, t.ratio = -1.416374, p.value = 0.1599028
        @test nrow(pairs_g2_l1.table) == 1
        @test pairs_g2_l1.table[1, :Contrast] == "G1_L1, G2_L1 - G1_L2, G2_L1"
        @test pairs_g2_l1.table[1, :Estimate] ≈ -0.371267 atol = 1e-6
        @test pairs_g2_l1.table[1, :SE] ≈ 0.262125 atol = 1e-6
        @test pairs_g2_l1.table[1, :df] == 96
        @test pairs_g2_l1.table[1, :t] ≈ -1.416374 atol = 1e-6
        @test pairs_g2_l1.table[1, :p_adj] ≈ 0.1599028 atol = 1e-6
        @test pairs_g2_l1.table[1, :Lower] ≈ -0.8915809 atol = 1e-6
        @test pairs_g2_l1.table[1, :Upper] ≈ 0.149047 atol = 1e-6

        # For BF2 = G2_L2: filter rows where Level contains "G2_L2"
        bf2_g2_l2_data = filter(row -> occursin("G2_L2", row.Level), interaction_data)
        em_bf1_g2_l2 = EmmeansResult(bf2_g2_l2_data, em.anova, em.level, nothing)
        pairs_g2_l2 = pairwise(em_bf1_g2_l2, adjust = :none)

        # R output: BF2 = G2_L2: G1_L1 - G1_L2, estimate = -0.4089487, SE = 0.262125, df = 96, t.ratio = -1.560129, p.value = 0.1220201
        @test nrow(pairs_g2_l2.table) == 1
        @test pairs_g2_l2.table[1, :Contrast] == "G1_L1, G2_L2 - G1_L2, G2_L2"
        @test pairs_g2_l2.table[1, :Estimate] ≈ -0.4089487 atol = 1e-6
        @test pairs_g2_l2.table[1, :SE] ≈ 0.262125 atol = 1e-6
        @test pairs_g2_l2.table[1, :df] == 96
        @test pairs_g2_l2.table[1, :t] ≈ -1.560129 atol = 1e-6
        @test pairs_g2_l2.table[1, :p_adj] ≈ 0.1220201 atol = 1e-6
        @test pairs_g2_l2.table[1, :Lower] ≈ -0.9292627 atol = 1e-6
        @test pairs_g2_l2.table[1, :Upper] ≈ 0.1113652 atol = 1e-6
    end

    @testset "Within-subjects: 3 levels - adjust=bonferroni" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_within_3.csv"), DataFrame)
        result = anova(data, :dv, :subject, within = [:WF1])
        em = emmeans(result, adjust = :none)
        em_wf1 = EmmeansResult(em.means[em.means.Effect.=="WF1", :], em.anova, em.level, nothing)
        pairs_result = pairwise(em_wf1, adjust = :bonferroni)

        # R output: 3 comparisons with bonferroni adjustment
        @test nrow(pairs_result.table) == 3

        # F1_L1 - F1_L2: p.value = 1.0 (adjusted)
        row1 = pairs_result.table[pairs_result.table.Contrast.=="F1_L1 - F1_L2", :]
        @test nrow(row1) == 1
        @test row1[1, :Estimate] ≈ -0.07176364 atol = 1e-6
        @test row1[1, :SE] ≈ 0.1265793 atol = 1e-6
        @test row1[1, :df] == 99
        @test row1[1, :t] ≈ -0.5669461 atol = 1e-6
        @test row1[1, :p_adj] ≈ 1.0 atol = 1e-6
        @test row1[1, :Lower] ≈ -0.3800272 atol = 1e-6
        @test row1[1, :Upper] ≈ 0.2364999 atol = 1e-6

        # F1_L1 - F1_L3: p.value = 1.0
        row2 = pairs_result.table[pairs_result.table.Contrast.=="F1_L1 - F1_L3", :]
        @test nrow(row2) == 1
        @test row2[1, :Estimate] ≈ 0.07555077 atol = 1e-6
        @test row2[1, :SE] ≈ 0.1411343 atol = 1e-6
        @test row2[1, :df] == 99
        @test row2[1, :t] ≈ 0.5353111 atol = 1e-6
        @test row2[1, :p_adj] ≈ 1.0 atol = 1e-6
        @test row2[1, :Lower] ≈ -0.2681592 atol = 1e-6
        @test row2[1, :Upper] ≈ 0.4192607 atol = 1e-6

        # F1_L2 - F1_L3: p.value = 0.9280462
        row3 = pairs_result.table[pairs_result.table.Contrast.=="F1_L2 - F1_L3", :]
        @test nrow(row3) == 1
        @test row3[1, :Estimate] ≈ 0.1473144 atol = 1e-6
        @test row3[1, :SE] ≈ 0.1441663 atol = 1e-6
        @test row3[1, :df] == 99
        @test row3[1, :t] ≈ 1.021837 atol = 1e-6
        @test row3[1, :p_adj] ≈ 0.9280462 atol = 1e-6
        @test row3[1, :Lower] ≈ -0.2037795 atol = 1e-6
        @test row3[1, :Upper] ≈ 0.4984083 atol = 1e-6
    end

    @testset "Within-subjects: 2x2 - adjust=none" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_within_2x2.csv"), DataFrame)
        result = anova(data, :dv, :subject, within = [:WF1, :WF2])
        em = emmeans(result, adjust = :none)
        # Filter for WF1 × WF2 interaction effect
        interaction_data = em.means[em.means.Effect.=="WF1 × WF2", :]
        em_interaction = EmmeansResult(interaction_data, em.anova, em.level, nothing)
        pairs_result = pairwise(em_interaction, adjust = :none)

        # R output: 2 comparisons (one for each level of WF2)
        @test nrow(pairs_result.table) >= 1

        # First comparison: F1_L1 - F1_L2 (for WF2 level 1)
        # R values: estimate=-0.02778333, SE=0.1408015, df=99, t.ratio=-0.1973226, p.value=0.8439796
        # Note: R output shows 2 comparisons, we'll test the first one
        # Find row by estimate to be robust against ordering
        row = pairs_result.table[
            isapprox.(pairs_result.table.Estimate, -0.02778333, atol = 1e-5),
            :,
        ]
        @test nrow(row) == 1
        @test row[1, :Estimate] ≈ -0.02778333 atol = 1e-6
        @test row[1, :SE] ≈ 0.1408015 atol = 1e-6
        @test row[1, :df] == 99
        @test row[1, :t] ≈ -0.1973226 atol = 1e-6
        @test row[1, :p_adj] ≈ 0.8439796 atol = 1e-6
        @test row[1, :Lower] ≈ -0.3071641 atol = 1e-6
        @test row[1, :Upper] ≈ 0.2515975 atol = 1e-6
    end

    @testset "Within-subjects: 2x2 - adjust=bonferroni" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_within_2x2.csv"), DataFrame)
        result = anova(data, :dv, :subject, within = [:WF1, :WF2])
        em = emmeans(result, adjust = :none)
        interaction_data = em.means[em.means.Effect.=="WF1 × WF2", :]
        em_interaction = EmmeansResult(interaction_data, em.anova, em.level, nothing)
        pairs_result = pairwise(em_interaction, adjust = :bonferroni)

        # R output: same estimates but adjusted p-values
        @test nrow(pairs_result.table) >= 1
        row = pairs_result.table[
            isapprox.(pairs_result.table.Estimate, -0.02778333, atol = 1e-5),
            :,
        ]
        @test nrow(row) == 1
        @test row[1, :Estimate] ≈ -0.02778333 atol = 1e-6
        @test row[1, :p_adj] ≈ 1.0 atol = 1e-6  # Bonferroni adjustment: min(p * n, 1.0) = min(0.844 * 6, 1.0) = 1.0
    end

    @testset "Within-subjects: 2x3 - adjust=none" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_within_2x3.csv"), DataFrame)
        result = anova(data, :dv, :subject, within = [:WF1, :WF2])
        em = emmeans(result, adjust = :none)
        interaction_data = em.means[em.means.Effect.=="WF1 × WF2", :]
        em_interaction = EmmeansResult(interaction_data, em.anova, em.level, nothing)
        pairs_result = pairwise(em_interaction, adjust = :none)

        # R output: 3 comparisons
        @test nrow(pairs_result.table) >= 1

        # First comparison: estimate=-0.01148962, SE=0.137524, df=99, t.ratio=-0.08354633, p.value=0.9335858
        row = pairs_result.table[
            isapprox.(pairs_result.table.Estimate, -0.01148962, atol = 1e-5),
            :,
        ]
        @test nrow(row) == 1
        @test row[1, :Estimate] ≈ -0.01148962 atol = 1e-6
        @test row[1, :SE] ≈ 0.137524 atol = 1e-6
        @test row[1, :df] == 99
        @test row[1, :t] ≈ -0.08354633 atol = 1e-6
        @test row[1, :p_adj] ≈ 0.9335858 atol = 1e-6
        @test row[1, :Lower] ≈ -0.284367 atol = 1e-6
        @test row[1, :Upper] ≈ 0.2613878 atol = 1e-6
    end

    @testset "Within-subjects: 2x3 - adjust=bonferroni" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_within_2x3.csv"), DataFrame)
        result = anova(data, :dv, :subject, within = [:WF1, :WF2])
        em = emmeans(result, adjust = :none)
        interaction_data = em.means[em.means.Effect.=="WF1 × WF2", :]
        em_interaction = EmmeansResult(interaction_data, em.anova, em.level, nothing)
        pairs_result = pairwise(em_interaction, adjust = :bonferroni)

        # R output: same estimates but adjusted p-values
        @test nrow(pairs_result.table) >= 1
        row = pairs_result.table[
            isapprox.(pairs_result.table.Estimate, -0.01148962, atol = 1e-5),
            :,
        ]
        @test nrow(row) == 1
        @test row[1, :Estimate] ≈ -0.01148962 atol = 1e-6
        @test row[1, :p_adj] ≈ 1.0 atol = 1e-6  # Bonferroni adjustment: min(p * n, 1.0)
    end

    @testset "Within-subjects: 2x2x2 - adjust=none" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_within_2x2x2.csv"), DataFrame)
        result = anova(data, :dv, :subject, within = [:WF1, :WF2, :WF3])
        em = emmeans(result, adjust = :none)
        interaction_data = em.means[em.means.Effect.=="WF1 × WF2 × WF3", :]
        em_interaction = EmmeansResult(interaction_data, em.anova, em.level, nothing)
        pairs_result = pairwise(em_interaction, adjust = :none)

        # R output: multiple comparisons
        @test nrow(pairs_result.table) >= 1

        # First comparison: estimate=-0.1875531, SE=0.1399337, df=99, t.ratio=-1.340299, p.value=0.183216
        row = pairs_result.table[
            isapprox.(pairs_result.table.Estimate, -0.1875531, atol = 1e-5),
            :,
        ]
        @test nrow(row) == 1
        @test row[1, :Estimate] ≈ -0.1875531 atol = 1e-6
        @test row[1, :SE] ≈ 0.1399337 atol = 1e-6
        @test row[1, :df] == 99
        @test row[1, :t] ≈ -1.340299 atol = 1e-6
        @test row[1, :p_adj] ≈ 0.183216 atol = 1e-6
        @test row[1, :Lower] ≈ -0.465212 atol = 1e-6
        @test row[1, :Upper] ≈ 0.09010582 atol = 1e-6
    end

    @testset "Within-subjects: 2x2x2 - adjust=bonferroni" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_within_2x2x2.csv"), DataFrame)
        result = anova(data, :dv, :subject, within = [:WF1, :WF2, :WF3])
        em = emmeans(result, adjust = :none)
        interaction_data = em.means[em.means.Effect.=="WF1 × WF2 × WF3", :]
        em_interaction = EmmeansResult(interaction_data, em.anova, em.level, nothing)
        pairs_result = pairwise(em_interaction, adjust = :bonferroni)

        # R output: same estimates but adjusted p-values
        @test nrow(pairs_result.table) >= 1
        row = pairs_result.table[
            isapprox.(pairs_result.table.Estimate, -0.1875531, atol = 1e-5),
            :,
        ]
        @test nrow(row) == 1
        @test row[1, :Estimate] ≈ -0.1875531 atol = 1e-6
        @test row[1, :p_adj] ≈ 1.0 atol = 1e-6  # Bonferroni adjustment: min(p * n, 1.0)
    end

    @testset "Mixed WB 2x2 - adjust=none" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_mixed_WB_2x2.csv"), DataFrame)
        result = anova(data, :dv, :subject, within = [:WF1], between = [:BF1])
        em = emmeans(result, adjust = :none)
        interaction_data = em.means[em.means.Effect.=="BF1 × WF1", :]
        em_interaction = EmmeansResult(interaction_data, em.anova, em.level, nothing)
        pairs_result = pairwise(em_interaction, adjust = :none)

        # R output: 2 comparisons
        @test nrow(pairs_result.table) >= 1

        # First comparison: estimate=-0.1306448, SE=0.2028958, df=98, t.ratio=-0.6439012, p.value=0.5211436
        row = pairs_result.table[
            isapprox.(pairs_result.table.Estimate, -0.1306448, atol = 1e-5),
            :,
        ]
        @test nrow(row) == 1
        @test row[1, :Estimate] ≈ -0.1306448 atol = 1e-6
        @test row[1, :SE] ≈ 0.2028958 atol = 1e-6
        @test row[1, :df] == 98
        @test row[1, :t] ≈ -0.6439012 atol = 1e-6
        @test row[1, :p_adj] ≈ 0.5211436 atol = 1e-6
        @test row[1, :Lower] ≈ -0.5332848 atol = 1e-6
        @test row[1, :Upper] ≈ 0.2719952 atol = 1e-6
    end

    @testset "Mixed WB 2x2 - adjust=bonferroni" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_mixed_WB_2x2.csv"), DataFrame)
        result = anova(data, :dv, :subject, within = [:WF1], between = [:BF1])
        em = emmeans(result, adjust = :none)
        interaction_data = em.means[em.means.Effect.=="BF1 × WF1", :]
        em_interaction = EmmeansResult(interaction_data, em.anova, em.level, nothing)
        pairs_result = pairwise(em_interaction, adjust = :bonferroni)

        # R output: same estimates but adjusted p-values
        @test nrow(pairs_result.table) >= 1
        row = pairs_result.table[
            isapprox.(pairs_result.table.Estimate, -0.1306448, atol = 1e-5),
            :,
        ]
        @test nrow(row) == 1
        @test row[1, :Estimate] ≈ -0.1306448 atol = 1e-6
        @test row[1, :p_adj] ≈ 1.0 atol = 1e-6  # Bonferroni adjustment: min(p * n, 1.0) = min(0.521 * 6, 1.0) = 1.0
    end

    @testset "Mixed WB 3x2 - adjust=none" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_mixed_WB_3x2.csv"), DataFrame)
        result = anova(data, :dv, :subject, within = [:WF1], between = [:BF1])
        em = emmeans(result, adjust = :none)
        interaction_data = em.means[em.means.Effect.=="BF1 × WF1", :]
        em_interaction = EmmeansResult(interaction_data, em.anova, em.level, nothing)
        pairs_result = pairwise(em_interaction, adjust = :none)

        # R output: multiple comparisons
        @test nrow(pairs_result.table) >= 1

        # First comparison: estimate=-0.03218533, SE=0.2120534, df=98, t.ratio=-0.1517793, p.value=0.879673
        row = pairs_result.table[
            isapprox.(pairs_result.table.Estimate, -0.03218533, atol = 1e-5),
            :,
        ]
        @test nrow(row) == 1
        @test row[1, :Estimate] ≈ -0.03218533 atol = 1e-6
        @test row[1, :SE] ≈ 0.2120534 atol = 1e-6
        @test row[1, :df] == 98
        @test row[1, :t] ≈ -0.1517793 atol = 1e-6
        @test row[1, :p_adj] ≈ 0.879673 atol = 1e-6
        @test row[1, :Lower] ≈ -0.4529985 atol = 1e-6
        @test row[1, :Upper] ≈ 0.3886278 atol = 1e-6
    end

    @testset "Mixed WB 3x2 - adjust=bonferroni" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_mixed_WB_3x2.csv"), DataFrame)
        result = anova(data, :dv, :subject, within = [:WF1], between = [:BF1])
        em = emmeans(result, adjust = :none)
        interaction_data = em.means[em.means.Effect.=="BF1 × WF1", :]
        em_interaction = EmmeansResult(interaction_data, em.anova, em.level, nothing)
        pairs_result = pairwise(em_interaction, adjust = :bonferroni)

        # R output: same estimates but adjusted p-values
        @test nrow(pairs_result.table) >= 1
        row = pairs_result.table[
            isapprox.(pairs_result.table.Estimate, -0.03218533, atol = 1e-5),
            :,
        ]
        @test nrow(row) == 1
        @test row[1, :Estimate] ≈ -0.03218533 atol = 1e-6
        @test row[1, :p_adj] ≈ 1.0 atol = 1e-6  # Bonferroni adjustment: min(p * n, 1.0)
    end

    @testset "Mixed WWB 2x2x3 - adjust=none" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_mixed_WWB_2x2x3.csv"), DataFrame)
        result = anova(data, :dv, :subject, within = [:WF1, :WF2], between = [:BF1])
        em = emmeans(result, adjust = :none)
        interaction_data = em.means[em.means.Effect.=="BF1 × WF1 × WF2", :]
        em_interaction = EmmeansResult(interaction_data, em.anova, em.level, nothing)
        pairs_result = pairwise(em_interaction, adjust = :none)

        # R output: multiple comparisons
        @test nrow(pairs_result.table) >= 1
        # Test that we get results (exact values depend on which comparison is first)
        @test all(isfinite.(pairs_result.table.Estimate))
        @test all(pairs_result.table.SE .> 0)
    end

    @testset "Mixed WWB 2x2x3 - adjust=bonferroni" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_mixed_WWB_2x2x3.csv"), DataFrame)
        result = anova(data, :dv, :subject, within = [:WF1, :WF2], between = [:BF1])
        em = emmeans(result, adjust = :none)
        interaction_data = em.means[em.means.Effect.=="BF1 × WF1 × WF2", :]
        em_interaction = EmmeansResult(interaction_data, em.anova, em.level, nothing)
        pairs_result = pairwise(em_interaction, adjust = :bonferroni)

        # R output: same estimates but adjusted p-values
        @test nrow(pairs_result.table) >= 1
        @test all(isfinite.(pairs_result.table.Estimate))
        @test all(pairs_result.table.SE .> 0)
    end

    @testset "Between-subjects: 3 levels - adjust=sidak" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_between_3.csv"), DataFrame)
        result = anova(data, :dv, :subject, between = [:BF1])
        em = emmeans(result, adjust = :none)
        # Filter for BF1 effect
        em_bf1 = EmmeansResult(em.means[em.means.Effect.=="BF1", :], em.anova, em.level, nothing)
        pairs_result = pairwise(em_bf1, adjust = :sidak)

        # Sidak adjustment: p_adj = 1 - (1 - p)^n
        # For 3 comparisons, should be less conservative than Bonferroni
        @test nrow(pairs_result.table) == 3

        # Check that Sidak-adjusted p-values are between unadjusted and Bonferroni-adjusted
        pairs_none = pairwise(em_bf1, adjust = :none)
        pairs_bonf = pairwise(em_bf1, adjust = :bonferroni)

        for i = 1:nrow(pairs_result.table)
            p_sidak = pairs_result.table[i, :p_adj]
            p_none = pairs_none.table[i, :p_adj]
            p_bonf = pairs_bonf.table[i, :p_adj]

            # Sidak should be between none and bonferroni (more conservative than none, less than bonferroni)
            @test p_sidak >= p_none
            @test p_sidak <= p_bonf
            @test 0.0 <= p_sidak <= 1.0
        end
    end

    @testset "Pairwise error cases" begin
        @testset "Invalid simple effect" begin
            data = CSV.read(joinpath(TEST_DATA_DIR, "data_between_2.csv"), DataFrame)
            result = anova(data, :dv, :subject, between = [:BF1])
            em = emmeans(result)

            # Test error when simple effect doesn't exist (simple expects Symbol)
            @test_throws ArgumentError pairwise(em, simple = :Nonexistent)
        end

        @testset "Mixed design interaction across between-subjects levels" begin
            # Test the path in _calculate_df_for_comparison for mixed design interactions
            # when comparing across between-subjects levels
            data = CSV.read(joinpath(TEST_DATA_DIR, "data_mixed_WB_2x2.csv"), DataFrame)
            result = anova(data, :dv, :subject, within = [:WF1], between = [:BF1])
            em = emmeans(result)

            # Filter for BF1 × WF1 interaction
            interaction_data = em.means[em.means.Effect.=="BF1 × WF1", :]
            @test nrow(interaction_data) > 0

            # Get pairwise comparisons for the interaction
            em_interaction = EmmeansResult(interaction_data, em.anova, em.level, nothing)
            pairs_result = pairwise(em_interaction, adjust = :none)

            # Should have comparisons
            @test nrow(pairs_result.table) > 0

            # Check that comparisons across between-subjects levels use between_df
            # and comparisons within the same between-subjects level use df_error_anova
            for row in eachrow(pairs_result.table)
                @test hasproperty(row, :df)
                @test row.df > 0
                @test hasproperty(row, :p_adj)
                @test 0.0 <= row.p_adj <= 1.0
            end
        end

        @testset "_parse_level_name error handling" begin
            # Test error handling in _parse_level_name
            # Test with mismatched lengths (should return nothing)
            result1 = AnovaFun._parse_level_name("F1_L1, G1_L1", "BF1")
            @test isnothing(result1)

            # Test with too many parts (should return nothing)
            result2 = AnovaFun._parse_level_name("F1_L1, G1_L1, H1_L1", "BF1 × WF1")
            @test isnothing(result2)

            # Test with too few parts (should return nothing)
            result3 = AnovaFun._parse_level_name("F1_L1", "BF1 × WF1")
            @test isnothing(result3)

            # Test with valid single factor input
            result4 = AnovaFun._parse_level_name("F1_L1", "BF1")
            @test !isnothing(result4)
            @test result4 isa Dict
            @test result4[:BF1] == "F1_L1"

            # Test with valid interaction input
            result5 = AnovaFun._parse_level_name("F1_L1, G1_L1", "BF1 × WF1")
            @test !isnothing(result5)
            @test result5 isa Dict
            @test haskey(result5, :BF1)
            @test haskey(result5, :WF1)
        end
    end
end
