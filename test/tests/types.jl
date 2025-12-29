@testset "Type accessors and helpers" begin
    @testset "AnovaResult accessors" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_between_2.csv"), DataFrame)
        result = anova(data, :dv, :subject; between = [:BF1])

        # Test accessor methods
        @test factors(result) == [:BF1]
        @test between_factors(result) == [:BF1]
        @test isempty(within_factors(result))
        @test n_id(result) > 0
        @test n_effects(result) >= 1
        @test design_type(result) == :between
        @test AnovaFun.data(result) isa DataFrame
        @test dv(result) == :dv
        @test id(result) == :subject
        @test !isnothing(model(result))
    end

    @testset "Within-subjects accessors" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_within_2x2.csv"), DataFrame)
        result = anova(data, :dv, :subject; within = [:WF1, :WF2])

        @test isempty(between_factors(result))
        @test within_factors(result) == [:WF1, :WF2]
        @test factors(result) == [:WF1, :WF2]
        @test design_type(result) == :within
    end

    @testset "Mixed design accessors" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_mixed_WB_2x2.csv"), DataFrame)
        result = anova(data, :dv, :subject; within = [:WF1], between = [:BF1])

        @test between_factors(result) == [:BF1]
        @test within_factors(result) == [:WF1]
        @test factors(result) == [:BF1, :WF1]
        @test design_type(result) == :mixed
    end

    @testset "AnovaResult show methods" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_between_2.csv"), DataFrame)
        result = anova(data, :dv, :subject; between = [:BF1])

        # Test that show methods don't error
        io = IOBuffer()
        show(io, MIME("text/plain"), result)
        output = String(take!(io))
        @test occursin("Between-Subjects", output)

        # Test compact show for between-subjects
        io = IOBuffer()
        show(io, result)
        output = String(take!(io))
        @test !isempty(output)
        @test occursin("Between", output)
        @test occursin("BF1", output)

        # Test compact show for within-subjects
        data_within = CSV.read(joinpath(TEST_DATA_DIR, "data_within_2.csv"), DataFrame)
        result_within = anova(data_within, :dv, :subject; within = [:WF1])
        io = IOBuffer()
        show(io, result_within)
        output = String(take!(io))
        @test occursin("Within", output)
        @test occursin("WF1", output)

        # Test compact show for mixed design
        data_mixed = CSV.read(joinpath(TEST_DATA_DIR, "data_mixed_WB_2x2.csv"), DataFrame)
        result_mixed = anova(data_mixed, :dv, :subject; within = [:WF1], between = [:BF1])
        io = IOBuffer()
        show(io, result_mixed)
        output = String(take!(io))
        @test occursin("Between", output)
        @test occursin("Within", output)
        @test occursin("BF1", output)
        @test occursin("WF1", output)
    end

    @testset "EmmeansResult show methods" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_between_2.csv"), DataFrame)
        result = anova(data, :dv, :subject; between = [:BF1])
        em = emmeans(result)

        @test em isa EmmeansResult
        @test em.anova === result

        # Test show methods (emmeans_table is called by show)
        io = IOBuffer()
        emmeans_table(em; io = io)
        output = String(take!(io))
        @test !isempty(output)

        # Test compact show
        io = IOBuffer()
        show(io, em)
        output = String(take!(io))
        @test occursin("EmmeansResult", output)
        @test occursin("level", output)

        # Test MIME show (calls emmeans_table internally)
        # Note: emmeans_table writes to stdout by default, so we test it directly
        io = IOBuffer()
        emmeans_table(em; io = io)
        output = String(take!(io))
        @test !isempty(output)
    end

    @testset "DesignInfo factory functions" begin
        # Test factory functions
        bf = [:BF1]
        wf = [:WF1]
        n = 10

        between_d = AnovaFun.between_design(bf, n)
        @test between_d.type == :between
        @test between_d.between_factors == bf
        @test isempty(between_d.within_factors)
        @test between_d.n_id == n

        within_d = AnovaFun.within_design(wf, n)
        @test within_d.type == :within
        @test isempty(within_d.between_factors)
        @test within_d.within_factors == wf
        @test within_d.n_id == n

        mixed_d = AnovaFun.mixed_design(bf, wf, n)
        @test mixed_d.type == :mixed
        @test mixed_d.between_factors == bf
        @test mixed_d.within_factors == wf
        @test mixed_d.n_id == n
    end

    @testset "_validate_factors" begin
        # Test empty factors
        @test_throws ArgumentError AnovaFun._validate_factors(Symbol[], "test")

        # Test duplicate factors
        @test_throws ArgumentError AnovaFun._validate_factors([:A, :A], "test")

        # Test valid factors (should not throw)
        AnovaFun._validate_factors([:A, :B], "test")
    end

    @testset "_format_factors_with_levels" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_between_2x2.csv"), DataFrame)
        factors = [:BF1, :BF2]

        formatted = AnovaFun._format_factors_with_levels(data, factors)
        @test occursin("BF1", formatted)
        @test occursin("BF2", formatted)
        @test occursin("×", formatted)

        # Test with single factor
        formatted_single = AnovaFun._format_factors_with_levels(data, [:BF1])
        @test occursin("BF1", formatted_single)
        @test !occursin("×", formatted_single)
    end

    @testset "n_effects accessor" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_between_2x2.csv"), DataFrame)
        result = anova(data, :dv, :subject; between = [:BF1, :BF2])

        n = n_effects(result)
        @test n >= 1  # Should have at least BF1, BF2, and BF1 × BF2
        @test n == count(row -> row.Effect != "Intercept", eachrow(result.table))
    end
end
