using Test
using AnovaFun
using DataFrames

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

    @testset "paired_ttest DataFrame method" begin
        x = [1.0, 2.0, 3.0, 4.0]
        y = [1.0, 1.0, 2.0, 2.0]
        df = DataFrame(score = vcat(x, y), cond = vcat(fill(1, 4), fill(2, 4)))

        # auto-detect two groups
        res_df = paired_ttest(df, :score, by = :cond)
        res_vec = paired_ttest(x, y)
        @test res_df.t ≈ res_vec.t
        @test res_df.p ≈ res_vec.p
        @test res_df.df == res_vec.df
        @test res_df.dz ≈ res_vec.dz

        # explicit levels
        res_levels = paired_ttest(df, :score, by = :cond, levels = [1, 2])
        @test res_levels.t ≈ res_vec.t

        # reversed levels should flip t sign
        res_rev = paired_ttest(df, :score, by = :cond, levels = [2, 1])
        @test res_rev.t ≈ -res_vec.t

        # tail keyword forwarded
        res_left = paired_ttest(df, :score, by = :cond, tail = :right)
        @test res_left.p < res_df.p  # one-tailed should be smaller when effect is positive

        # error when more than 2 groups
        df3 = DataFrame(score = rand(9), cond = repeat(1:3, 3))
        @test_throws ErrorException paired_ttest(df3, :score, by = :cond)
    end

    @testset "independent_ttest DataFrame method" begin
        x = [1.0, 2.0, 3.0]
        y = [2.0, 4.0, 6.0]
        df = DataFrame(score = vcat(x, y), group = vcat(fill(:a, 3), fill(:b, 3)))

        # auto-detect two groups
        res_df = independent_ttest(df, :score, by = :group)
        res_vec = independent_ttest(x, y)
        @test res_df.t ≈ res_vec.t
        @test res_df.p ≈ res_vec.p
        @test res_df.df == res_vec.df
        @test res_df.d ≈ res_vec.d

        # explicit levels
        res_levels = independent_ttest(df, :score, by = :group, levels = [:a, :b])
        @test res_levels.t ≈ res_vec.t

        # reversed levels should flip t sign
        res_rev = independent_ttest(df, :score, by = :group, levels = [:b, :a])
        @test res_rev.t ≈ -res_vec.t

        # tail keyword forwarded
        res_right = independent_ttest(df, :score, by = :group, tail = :left)
        @test res_right.p < res_df.p  # one-tailed in correct direction

        # error when more than 2 groups
        df3 = DataFrame(score = rand(9), group = repeat([:a, :b, :c], 3))
        @test_throws ErrorException independent_ttest(df3, :score, by = :group)

        # works with unequal group sizes
        df_unequal = DataFrame(
            score = [1.0, 2.0, 3.0, 4.0, 5.0],
            group = [1, 1, 2, 2, 2]
        )
        res_uneq = independent_ttest(df_unequal, :score, by = :group)
        @test res_uneq.df == 3  # n1 + n2 - 2 = 2 + 3 - 2
        @test isfinite(res_uneq.t)
    end
end
