@testset "Report formatting functions" begin
    @testset "p-value formatting" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_between_2.csv"), DataFrame)
        result = anova(data, :dv, :subject; between = [:BF1])

        # Test p function with numeric value
        @test occursin("p", p(0.05))
        @test occursin("p", p(0.001))
        @test occursin("p", p(0.0001))
        @test occursin("< .001", p(0.0001))

        # Test p function with AnovaResult
        p_str = p(result, "BF1")
        @test occursin("p", p_str)

        # Test different formats
        p_md = p(0.05; format = :markdown)
        p_latex = p(0.05; format = :latex)
        p_text = p(0.05; format = :text)
        @test p_md != p_latex
        @test p_text != p_md

        # Test error case
        @test_throws ArgumentError p(result, "Nonexistent")
    end

    @testset "F-statistic formatting" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_between_2.csv"), DataFrame)
        result = anova(data, :dv, :subject; between = [:BF1])

        f_str = f(result, "BF1")
        @test occursin("F", f_str)
        @test occursin("(", f_str)
        @test occursin(")", f_str)

        # Test different formats
        f_md = f(result, "BF1"; format = :markdown)
        f_latex = f(result, "BF1"; format = :latex)
        f_text = f(result, "BF1"; format = :text)
        @test f_md != f_latex

        # Test error case
        @test_throws ArgumentError f(result, "Nonexistent")
    end

    @testset "Sphericity formatting" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_within_3.csv"), DataFrame)
        result = anova(data, :dv, :subject; within = [:WF1], correction = :GG)

        # Test sphericity function
        sph_str = sphericity(result, "WF1")
        if !isempty(sph_str)
            @test occursin("epsilon", sph_str) || occursin("ε", sph_str)
        end

        # Test with no correction (should return empty)
        result_no_corr = anova(data, :dv, :subject; within = [:WF1], correction = :none)
        sph_str_empty = sphericity(result_no_corr, "WF1")
        @test isempty(sph_str_empty)

        # Test different formats
        result_gg = anova(data, :dv, :subject; within = [:WF1], correction = :GG)
        sph_md = sphericity(result_gg, "WF1"; format = :markdown)
        sph_latex = sphericity(result_gg, "WF1"; format = :latex)
        sph_text = sphericity(result_gg, "WF1"; format = :text)
        if !isempty(sph_md)
            # Markdown and latex might be the same for epsilon, but text should be different
            @test sph_text != sph_md || sph_text != sph_latex
        end
    end

    @testset "fstat formatting" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_between_2.csv"), DataFrame)
        result = anova(data, :dv, :subject; between = [:BF1])

        fstat_str = fstat(result, "BF1")
        @test occursin("F", fstat_str)
        @test occursin("p", fstat_str)

        # Test different formats
        fstat_md = fstat(result, "BF1"; format = :markdown)
        fstat_latex = fstat(result, "BF1"; format = :latex)
        @test fstat_md != fstat_latex

        # Test error case
        @test_throws ArgumentError fstat(result, "Nonexistent")
    end

    @testset "Mean formatting" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_between_2.csv"), DataFrame)
        result = anova(data, :dv, :subject; between = [:BF1])
        em = emmeans(result)

        m_str = m(em, "BF1", "G1_L1")
        @test occursin("M", m_str) || occursin("Mean", m_str)

        # Test with unit
        m_str_unit = m(em, "BF1", "G1_L1"; unit = " ms")
        @test occursin("ms", m_str_unit)

        # Test different formats
        m_md = m(em, "BF1", "G1_L1"; format = :markdown)
        m_latex = m(em, "BF1", "G1_L1"; format = :latex)
        @test m_md != m_latex

        # Test error case
        @test_throws ArgumentError m(em, "Nonexistent", "Level")
    end

    @testset "CI formatting" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_between_2.csv"), DataFrame)
        result = anova(data, :dv, :subject; between = [:BF1])
        em = emmeans(result)

        # Test ci with numeric values
        ci_str = ci(0.1, 0.2)
        @test occursin("CI", ci_str)
        @test occursin("0.10", ci_str) || occursin("0.1", ci_str)

        # Test ci with EmmeansResult
        ci_str_em = ci(em, "BF1", "G1_L1")
        @test occursin("CI", ci_str_em)

        # Test different formats
        ci_md = ci(0.1, 0.2; format = :markdown)
        ci_latex = ci(0.1, 0.2; format = :latex)
        @test ci_md != ci_latex

        # Test error cases
        @test_throws ArgumentError ci(em, "Nonexistent", "Level")
    end

    @testset "m_ci formatting" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_between_2.csv"), DataFrame)
        result = anova(data, :dv, :subject; between = [:BF1])
        em = emmeans(result)

        m_ci_str = m_ci(em, "BF1", "G1_L1")
        @test occursin("M", m_ci_str) || occursin("Mean", m_ci_str)
        @test occursin("CI", m_ci_str)

        # Test with unit
        m_ci_str_unit = m_ci(em, "BF1", "G1_L1"; unit = " ms")
        @test occursin("ms", m_ci_str_unit)

        # Test different formats
        m_ci_md = m_ci(em, "BF1", "G1_L1"; format = :markdown)
        m_ci_latex = m_ci(em, "BF1", "G1_L1"; format = :latex)
        @test m_ci_md != m_ci_latex

        # Test error case
        @test_throws ArgumentError m_ci(em, "Nonexistent", "Level")
    end

    @testset "Format error cases" begin
        @test_throws ArgumentError AnovaFun._get_symbols(:invalid)
    end
end
