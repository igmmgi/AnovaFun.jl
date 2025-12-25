@testset "Table formatting" begin
    @testset "anova_table formatting" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_between_2.csv"), DataFrame)
        result = anova(data, :dv, :subject; between = [:BF1])

        # Test different backends
        io = IOBuffer()
        anova_table(result; backend = :text, io = io)
        output = String(take!(io))
        @test occursin("ANOVA Table", output)
        @test occursin("BF1", output)

        io = IOBuffer()
        anova_table(result; backend = :markdown, io = io)
        output = String(take!(io))
        @test !isempty(output)

        io = IOBuffer()
        anova_table(result; backend = :latex, io = io)
        output = String(take!(io))
        @test !isempty(output)
    end

    @testset "anova_table options" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_between_2.csv"), DataFrame)
        result = anova(data, :dv, :subject; between = [:BF1])

        # Test include_intercept (only if intercept exists in table)
        has_intercept = "Intercept" in result.table.Effect
        if has_intercept
            io = IOBuffer()
            anova_table(result; include_intercept = true, io = io)
            output1 = String(take!(io))

            io = IOBuffer()
            anova_table(result; include_intercept = false, io = io)
            output2 = String(take!(io))
            @test length(output1) > length(output2)
        end

        # Test include_ss
        io = IOBuffer()
        anova_table(result; include_ss = true, io = io)
        output1 = String(take!(io))

        io = IOBuffer()
        anova_table(result; include_ss = false, io = io)
        output2 = String(take!(io))
        @test length(output1) != length(output2)

        # Test custom title
        io = IOBuffer()
        anova_table(result; title = "Custom Title", io = io)
        output = String(take!(io))
        @test occursin("Custom Title", output)
    end

    @testset "anova_table error cases" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_between_2.csv"), DataFrame)
        result = anova(data, :dv, :subject; between = [:BF1])

        @test_throws ArgumentError anova_table(result; backend = :invalid)
    end

    @testset "emmeans_table formatting" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_between_2.csv"), DataFrame)
        result = anova(data, :dv, :subject; between = [:BF1])
        em = emmeans(result)

        # Test different backends
        io = IOBuffer()
        emmeans_table(em; backend = :text, io = io)
        output = String(take!(io))
        @test occursin("Estimated Marginal Means", output)

        io = IOBuffer()
        emmeans_table(em; backend = :markdown, io = io)
        output = String(take!(io))
        @test !isempty(output)

        io = IOBuffer()
        emmeans_table(em; backend = :latex, io = io)
        output = String(take!(io))
        @test !isempty(output)
    end

    @testset "emmeans_table custom title" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_between_2.csv"), DataFrame)
        result = anova(data, :dv, :subject; between = [:BF1])
        em = emmeans(result)

        io = IOBuffer()
        emmeans_table(em; title = "Custom EMM Title", io = io)
        output = String(take!(io))
        @test occursin("Custom EMM Title", output)
    end

    @testset "emmeans_table error cases" begin
        data = CSV.read(joinpath(TEST_DATA_DIR, "data_between_2.csv"), DataFrame)
        result = anova(data, :dv, :subject; between = [:BF1])
        em = emmeans(result)

        @test_throws ArgumentError emmeans_table(em; backend = :invalid)
    end
end
