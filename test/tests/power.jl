@testset "Power analysis" begin
    @testset "Within-subjects design" begin

        result = power_analysis(
            20,
            within = Dict(:factor1 => [1, 2], :factor2 => [1, 2]),
            mu = [1.0, 1.0, 1.0, 2.0],
            sd = 1.0,
            r = 0.5,
            n_sims = 100,
        )

        @test result isa PowerResult
        @test !isempty(result.power)
        @test result.n_sims == 100
        @test result.alpha == 0.05
        @test :n in propertynames(result.power)
        @test :Effect in propertynames(result.power)
        @test :Power in propertynames(result.power)
        @test :EffectSize in propertynames(result.power)
        @test all(0 .<= result.power.Power .<= 100)
    end

    @testset "Between-subjects design" begin
        result = power_analysis(
            30,
            between = Dict(:group => [:A, :B]),
            mu = [1.0, 2.0],
            sd = 1.0,
            n_sims = 100,
        )

        @test result isa PowerResult
        @test !isempty(result.power)
        @test all(0 .<= result.power.Power .<= 100)
    end

    @testset "Mixed design" begin
        result = power_analysis(
            25,
            between = Dict(:group => [:A, :B]),
            within = Dict(:time => [1, 2]),
            mu = [1.0, 1.2, 1.5, 1.8],
            sd = 1.0,
            r = 0.6,
            n_sims = 100,
        )

        @test result isa PowerResult
        @test !isempty(result.power)
        @test all(0 .<= result.power.Power .<= 100)
    end

    @testset "Single factor within-subjects" begin

        using AnovaFun
        result = power_analysis(
            15,
            within = Dict(:condition => [:A, :B, :C]),
            mu = [1.0, 1.5, 2.0],
            sd = 1.0,
            r = 0.5,
            n_sims = 100,
        )

        @test result isa PowerResult
        @test !isempty(result.power)
    end

    @testset "Custom alpha" begin
        result = power_analysis(
            20,
            within = Dict(:factor => [1, 2]),
            mu = [1.0, 2.0],
            sd = 1.0,
            r = 0.5,
            n_sims = 100,
            alpha = 0.01,
        )

        @test result.alpha == 0.01
    end

end
