@testset "APA Formatting" begin
    @testset "p" begin
        @test p(0.0001; format = :markdown) == "*p* < .001"
        @test p(0.041; format = :markdown) == "*p* = .041"

        @test p(0.041; format = :latex) == "\\textit{p} = .041"
        @test p(0.0001; format = :latex) == "\\textit{p} < .001"

        @test p(0.041; format = :text) == "p = .041"
        @test p(0.0001; format = :text) == "p < .001"

        # Error case
        @test_throws ArgumentError p(0.05; format = :unknown)

        # Test with AnovaResult
        table = DataFrame(
            Effect = ["A"],
            p = [0.041],
            DFn = [1],
            DFd = [10],
            F = [1.0],
            SSn = [1.0],
            SSd = [1.0],
        )
        res = AnovaResult(
            DataFrame(),
            :RT,
            :id,
            table,
            DesignInfo(:within, Symbol[], Symbol[], 10),
            nothing,
        )
        @test p(res, "A"; format = :markdown) == "*p* = .041"
        @test p(res, "A"; format = :latex) == "\\textit{p} = .041"
    end

    @testset "f" begin
        table = DataFrame(
            Effect = ["Comp", "Side", "Comp x Side"],
            DFn = [1.0, 1.0, 1.0],
            DFd = [49.0, 49.0, 49.0],
            F = [4.39, 0.32, 0.49],
            p = [0.041, 0.574, 0.999], # Add p-values for fstat tests later
            pes = [0.08, 0.01, 0.01],
            ε = [1.0, 1.0, 0.97],
        )
        # Sphericity correction needs ε < 1.0 to show up

        design = DesignInfo(:mixed, [:Comp], [:Side], 50)
        result = AnovaResult(DataFrame(), :RT, :id, table, design, nothing)

        @test f(result, "Comp"; format = :markdown) == "*F*(1, 49) = 4.39"
        @test f(result, "Comp"; format = :latex) == "\\textit{F}(1, 49) = 4.39"
        @test f(result, "Comp"; format = :text) == "F(1, 49) = 4.39"
    end

    @testset "sphericity" begin
        table = DataFrame(
            Effect = ["A"],
            ε = [0.75],
            DFn = [2],
            DFd = [10],
            F = [1.0],
            p = [0.05],
            pes = [0.1],
        )
        result = AnovaResult(
            DataFrame(),
            :RT,
            :id,
            table,
            DesignInfo(:within, Symbol[], Symbol[], 10),
            nothing,
        )

        @test sphericity(result, "A") == "\$\\epsilon\$ = 0.75"
        @test sphericity(result, "A"; format = :latex) == "\$\\epsilon\$ = 0.75"
        @test sphericity(result, "A"; format = :text) == "epsilon = 0.75"
    end

    @testset "fstat" begin
        table = DataFrame(
            Effect = ["Comp", "Side"],
            DFn = [1.94, 1.0],
            DFd = [95.06, 49.0],
            F = [0.02, 4.39],
            p = [0.980, 0.041],
            pes = [0.08, 0.01], # pes for effect size check
            ε = [0.97, 1.0],
        )

        # Test generalized eta squared
        table.ges = [0.05, 0.05]

        result = AnovaResult(
            DataFrame(),
            :RT,
            :id,
            table,
            DesignInfo(:within, Symbol[], Symbol[], 10),
            nothing,
        )

        # Test specific effect sizes cleanly
        table_ges = DataFrame(
            Effect = ["A"],
            DFn = [1],
            DFd = [10],
            F = [1.0],
            p = [0.05],
            ges = [0.12],
            ε = [1.0],
        )
        res_ges = AnovaResult(
            DataFrame(),
            :RT,
            :id,
            table_ges,
            DesignInfo(:within, Symbol[], Symbol[], 10),
            nothing,
        )

        # Markdown (default)
        @test fstat(res_ges, "A") ==
              "*F*(1, 10) = 1.00, *p* = .050, \$\\eta_G^2\$ = 0.12, \$\\epsilon\$ = 1.00"

        # Latex
        @test fstat(res_ges, "A"; format = :latex) ==
              "\\textit{F}(1, 10) = 1.00, \\textit{p} = .050, \$\\eta_G^2\$ = 0.12, \$\\epsilon\$ = 1.00"

        # Text
        @test fstat(res_ges, "A"; format = :text) ==
              "F(1, 10) = 1.00, p = .050, eta_G^2 = 0.12, epsilon = 1.00"
    end

    @testset "means formatting" begin
        means_df = DataFrame(
            Effect = ["A", "A"],
            Level = ["L1", "L2"],
            Mean = [1.234, 5.678],
            Lower = [1.00, 5.286],
            Upper = [1.46, 6.07],
        )

        # Create minimal AnovaResult
        table = DataFrame(
            Effect = ["A"],
            DFn = [1.0],
            DFd = [10.0],
            F = [1.0],
            p = [0.5],
            SSn = [1.0],
            SSd = [1.0],
        )
        anova_res = AnovaResult(
            DataFrame(),
            :RT,
            :id,
            table,
            DesignInfo(:within, Symbol[], Symbol[], 10),
            nothing,
        )

        emmeans_res = EmmeansResult(means_df, anova_res, 0.95)

        # ci
        @test ci(1.00, 1.46) == "*95% CI* [1.00, 1.46]"
        @test ci(1.00, 1.46; format = :latex) == "95\\% CI [1.00, 1.46]"
        @test ci(1.00, 1.46; format = :text) == "95% CI [1.00, 1.46]"

        # m
        @test m(emmeans_res, "A", "L1") == "*M* = 1.23"
        @test m(emmeans_res, "A", "L1"; format = :latex) == "\\textit{M} = 1.23"
        @test m(emmeans_res, "A", "L1"; format = :text) == "M = 1.23"

        # m with unit
        @test m(emmeans_res, "A", "L1"; unit = " ms") == "*M* = 1.23 ms"
        @test m(emmeans_res, "A", "L1"; unit = " ms", format = :text) == "M = 1.23 ms"

        # m_ci
        @test m_ci(emmeans_res, "A", "L1") == "*M* = 1.23, *95% CI* [1.00, 1.46]"
        @test m_ci(emmeans_res, "A", "L1"; format = :latex) ==
              "\\textit{M} = 1.23, 95\\% CI [1.00, 1.46]"
        @test m_ci(emmeans_res, "A", "L1"; format = :text) ==
              "M = 1.23, 95% CI [1.00, 1.46]"

        # m_ci with unit
        @test m_ci(emmeans_res, "A", "L1"; unit = " ms") ==
              "*M* = 1.23 ms, *95% CI* [1.00, 1.46]"

    end
end
