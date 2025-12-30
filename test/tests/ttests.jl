using Test
using AnovaFun

@testset "t-tests" begin
    @testset "paired_ttest returns dz" begin
        x = [1.0, 2.0, 3.0, 4.0]
        y = [1.0, 1.0, 2.0, 2.0]
        res = paired_ttest(x, y)
        @test hasproperty(res, :df)
        @test hasproperty(res, :t)
        @test hasproperty(res, :p)
        @test hasproperty(res, :dz)
        @test res.df == 3
        @test isfinite(res.t)
        @test isfinite(res.dz)

        # Report formatting
        s = tstat(res; format = :text)
        @test occursin("t(", s)
        @test occursin("p", s)
        @test occursin("dz", s) || occursin("d_z", s)
    end

    @testset "independent_ttest returns d" begin
        x = [1.0, 2.0, 3.0]
        y = [2.0, 4.0, 6.0]
        res = independent_ttest(x, y)
        @test hasproperty(res, :df)
        @test hasproperty(res, :t)
        @test hasproperty(res, :p)
        @test hasproperty(res, :d)
        @test res.df == 4
        @test isfinite(res.d)

        # Report formatting
        s = tstat(res; format = :text)
        @test occursin("t(", s)
        @test occursin("p", s)
        @test occursin("d", s)
    end
end
