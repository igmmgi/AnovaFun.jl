@testset "Data simulation" begin
    @testset "Within-subjects design" begin
        data = simulate_data(
            20,
            within=Dict(:factor1 => [1, 2], :factor2 => [1, 2]),
            mu=[1.0, 1.0, 1.0, 2.0],
            sd=1.0,
            r=0.5,
        )
        
        @test data isa DataFrame
        @test :id in propertynames(data)
        @test :dv in propertynames(data)
        @test :factor1 in propertynames(data)
        @test :factor2 in propertynames(data)
        @test nrow(data) == 20 * 2 * 2  # n * n_levels_factor1 * n_levels_factor2
        @test all(data.id .>= 1)
        @test all(data.id .<= 20)
    end
    
    @testset "Between-subjects design" begin
        data = simulate_data(
            30,
            between=Dict(:group => [:A, :B]),
            mu=[1.0, 2.0],
            sd=1.0,
        )
        
        @test data isa DataFrame
        @test :id in propertynames(data)
        @test :dv in propertynames(data)
        @test :group in propertynames(data)
        @test nrow(data) == 30 * 2  # n per group * 2 groups = 60 total subjects
        @test length(unique(data.id)) == 30 * 2  # 60 total subjects
    end
    
    @testset "Mixed design" begin
        data = simulate_data(
            25,
            between=Dict(:group => [:A, :B]),
            within=Dict(:time => [1, 2]),
            mu=[1.0, 1.2, 1.5, 1.8],
            sd=1.0,
            r=0.6,
        )
        
        @test data isa DataFrame
        @test :id in propertynames(data)
        @test :dv in propertynames(data)
        @test :group in propertynames(data)
        @test :time in propertynames(data)
        @test nrow(data) == 25 * 2 * 2  # n per group * 2 groups * 2 within levels = 100 rows
    end
    
    @testset "Single value mu and sd" begin
        data = simulate_data(
            15,
            within=Dict(:condition => [:A, :B]),
            mu=1.5,
            sd=0.8,
            r=0.5,
        )
        
        @test data isa DataFrame
        @test nrow(data) == 15 * 2
    end
    
    @testset "No correlation (independent)" begin
        data = simulate_data(
            20,
            within=Dict(:factor => [1, 2]),
            mu=[1.0, 2.0],
            sd=1.0,
            r=nothing,
        )
        
        @test data isa DataFrame
        @test nrow(data) == 20 * 2
    end
    
    @testset "within_correlation_matrix" begin
        data = simulate_data(
            40,
            between=Dict(:group => [:A, :B]),
            within=Dict(:emotion => [:cheerful, :sad]),
            mu=[1.03, 1.41, 0.98, 1.01],
            sd=1.03,
            r=0.8,
        )
        
        corr_matrix = within_correlation_matrix(data)
        
        @test corr_matrix isa DataFrame
        @test :cell in propertynames(corr_matrix)
        @test nrow(corr_matrix) == 2  # 2 within-subjects cells
        @test ncol(corr_matrix) == 3  # cell column + 2 correlation columns
    end
end

