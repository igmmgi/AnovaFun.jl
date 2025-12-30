@testset "Sample size estimation" begin
    @testset "Binary search method" begin
        result = sample_size(
            target_power=80,
            within=Dict(:factor1 => [1, 2], :factor2 => [1, 2]),
            mu=[1.0, 1.0, 1.0, 2.0],
            sd=1.0,
            r=0.5,
            method=:binary,
            n_sims=100,
            min_n=5,
            max_n=50,
            n_anchors=5,
        )
        
        @test result isa SampleSizeResult
        @test !isempty(result.power)
        @test !isempty(result.results)
        @test result.target_power == 80.0
        @test :n in propertynames(result.power)
        @test :Effect in propertynames(result.power)
        @test :Power in propertynames(result.power)
        @test :EffectSize in propertynames(result.power)
    end
    
    @testset "Sequential search method" begin
        result = sample_size(
            target_power=80,
            within=Dict(:factor1 => [1, 2]),
            mu=[1.0, 2.0],
            sd=1.0,
            r=0.5,
            method=:sequential,
            n_sims=100,
            min_n=10,
            max_n=30,
            step=5,
        )
        
        @test result isa SampleSizeResult
        @test !isempty(result.power)
        @test !isempty(result.results)
        @test result.target_power == 80.0
    end
    
    @testset "Between-subjects design" begin
        result = sample_size(
            target_power=80,
            between=Dict(:group => [:A, :B]),
            mu=[1.0, 2.0],
            sd=1.0,
            method=:binary,
            n_sims=100,
            min_n=10,
            max_n=40,
        )
        
        @test result isa SampleSizeResult
        @test !isempty(result.power)
    end
    
    @testset "Mixed design" begin
        result = sample_size(
            target_power=80,
            between=Dict(:group => [:A, :B]),
            within=Dict(:time => [1, 2]),
            mu=[1.0, 1.2, 1.5, 1.8],
            sd=1.0,
            r=0.5,
            method=:binary,
            n_sims=100,
            min_n=10,
            max_n=40,
        )
        
        @test result isa SampleSizeResult
        @test !isempty(result.power)
    end
end

