import PrecompileTools

PrecompileTools.@compile_workload begin
    # Create synthetic data for precompilation to cover main code paths
    df_between = DataFrame(
        dv = randn(40),
        id = repeat(1:20, 2),
        group = repeat([:A, :B], inner = 20),
    )
    df_within = DataFrame(
        dv = randn(40),
        id = repeat(1:20, 2),
        condition = repeat([:pre, :post], 20),
    )
    df_mixed = DataFrame(
        dv = randn(80),
        id = repeat(1:20, 4),
        group = repeat([:A, :B], inner = 40),
        condition = repeat([:pre, :post], 40),
    )
    df_within_2x2 = DataFrame(
        dv = randn(80),
        id = repeat(1:20, 4),
        factor1 = repeat([:A, :B], inner = 40),
        factor2 = repeat([:X, :Y], 40),
    )

    # Precompile anova function calls
    res_between = anova(df_between, :dv, :id, between = [:group])
    res_within = anova(df_within, :dv, :id, within = [:condition])
    res_mixed = anova(df_mixed, :dv, :id, between = [:group], within = [:condition])
    res_within_2x2 = anova(df_within_2x2, :dv, :id, within = [:factor1, :factor2])
    anova(df_within, :dv, :id, within = [:condition], correction = :GG)
    anova(df_within, :dv, :id, within = [:condition], correction = :HF)
    anova(df_between, :dv, :id, between = [:group], effect_size = :pes)
    anova(df_between, :dv, :id, between = [:group], effect_size = :es)
    anova(df_between, :dv, :id, between = [:group], effect_size = :os)

    # Precompile emmeans function calls
    em_between = emmeans(res_between)
    em_within = emmeans(res_within)
    em_mixed = emmeans(res_mixed)
    em_within_2x2 = emmeans(res_within_2x2)
    emmeans(res_within, level = 0.95, adjust = :none)
    emmeans(res_within, level = 0.90, adjust = :bonferroni)

    # Precompile pairwise function calls
    pairwise(em_within)
    pairwise(em_within, adjust = :bonferroni)
    pairwise(em_within, adjust = :sidak)
    pairwise(em_within_2x2, by = :factor1)

    # Precompile accessor functions
    factors(res_within)
    between_factors(res_between)
    within_factors(res_within)
    n_id(res_within)
    n_effects(res_within)
    design_type(res_within)
    data(res_within)
    dv(res_within)
    id(res_within)
    model(res_within)

    # Precompile table functions
    anova_table(res_within)
    emmeans_table(em_within)

    # Precompile helper functions
    p(0.05)
    p(res_within, "condition")
    f(res_within, "condition")
    sphericity(res_within, "condition")
    fstat(res_within, "condition")
    m(em_within, "condition", "pre")
    ci(0.1, 0.2)
    ci(em_within, "condition", "pre")
    m_ci(em_within, "condition", "pre")

    # Precompile plot_anova with AnovaResult
    plot_anova(res_within, x_grouping = :condition)
    plot_anova(res_within_2x2, x_grouping = :factor1, y_grouping = :factor2)
    plot_anova(res_mixed, x_grouping = :condition, y_grouping = :group)
    plot_anova(res_mixed, x_grouping = :condition, facet_cols = :group)
    plot_anova(res_within, x_grouping = :condition, individual_data = :none)
    plot_anova(res_within, x_grouping = :condition, individual_data = :points)
    plot_anova(res_within, x_grouping = :condition, individual_data = :connected_points)

    # Precompile plot_anova with EmmeansResult
    plot_anova(em_within, x_grouping = :condition)
    plot_anova(em_within_2x2, x_grouping = :factor1, y_grouping = :factor2)
    plot_anova(em_mixed, x_grouping = :condition, y_grouping = :group)

    # Precompile different plot types
    plot_anova(em_within, x_grouping = :condition, plot_type = :line)
    plot_anova(em_within, x_grouping = :condition, plot_type = :boxplot)
    plot_anova(em_within, x_grouping = :condition, plot_type = :violin)
    plot_anova(em_within, x_grouping = :condition, plot_type = :bar)
    plot_anova(em_within, x_grouping = :condition, plot_type = :raincloud)
    plot_anova(em_within, x_grouping = :condition, plot_type = :raincloud_custom)
    plot_anova(
        em_within,
        x_grouping = :condition,
        plot_type = :raincloud_custom,
        individual_data = :connected_points,
    )
    plot_anova(
        em_within_2x2,
        x_grouping = :factor1,
        y_grouping = :factor2,
        plot_type = :raincloud_custom_2x2,
    )
    plot_anova(
        em_within_2x2,
        x_grouping = :factor1,
        y_grouping = :factor2,
        plot_type = :raincloud_custom_2x2,
        individual_data = :connected_points,
    )

    # Precompile error bar options
    plot_anova(em_within, x_grouping = :condition, errorbars = :SE)
    plot_anova(em_within, x_grouping = :condition, errorbars = :CI)
    plot_anova(em_within, x_grouping = :condition, errorbars = :withinSE)
    plot_anova(em_within, x_grouping = :condition, errorbars = :withinCI)
    plot_anova(em_within, x_grouping = :condition, errorbars = :none)

    # Precompile sphericity and homogeneity checks
    sphericity_check(res_within)
    check_homogeneity(res_between)
end
