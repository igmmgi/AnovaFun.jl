import PrecompileTools
import CSV

PrecompileTools.@compile_workload begin

    # Create synthetic data for precompilation to cover main code paths
    df_between = DataFrame(
        dv = randn(40),
        id = repeat(1:20, 2),
        group = repeat([:A, :B], inner = 20),
    )

    test_data_dir = joinpath(@__DIR__, "..", "test", "test_data")
    df_within = CSV.read(joinpath(test_data_dir, "data_within_2.csv"), DataFrame)
    df_mixed = CSV.read(joinpath(test_data_dir, "data_mixed_WB_2x2.csv"), DataFrame)
    df_within_2x2 = CSV.read(joinpath(test_data_dir, "data_within_2x2.csv"), DataFrame)

    # Precompile anova function calls
    res_between = anova(df_between, :dv, :id, between = [:group])
    res_within = anova(df_within, :dv, :subject, within = [:WF1])
    res_mixed = anova(df_mixed, :dv, :subject, between = [:BF1], within = [:WF1])
    res_within_2x2 = anova(df_within_2x2, :dv, :subject, within = [:WF1, :WF2])
    anova(df_within, :dv, :subject, within = [:WF1], correction = :GG)
    anova(df_within, :dv, :subject, within = [:WF1], correction = :HF)
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

    # Precompile accessor functions
    factors(res_within)
    between_factors(res_between)
    within_factors(res_within)
    n_id(res_within)
    n_effects(res_within)
    design_type(res_within)
    res_within.data
    res_within.dv
    res_within.id
    model(res_within)

    # Precompile table functions (suppress output during precompilation)
    anova_table(res_within; io=devnull);
    emmeans_table(em_within; io=devnull);

    # Precompile helper functions
    p(0.05)
    p(res_within, "WF1")
    f(res_within, "WF1")
    sphericity(res_within, "WF1")
    fstat(res_within, "WF1")
    m(em_within, "WF1", "F1_L1")
    ci(0.1, 0.2)
    ci(em_within, "WF1", "F1_L1")
    m_ci(em_within, "WF1", "F1_L1")

    # Precompile plot_anova - minimal set to cover main code paths
    plot_anova(em_within, x_grouping = :WF1)  # Basic 1D plot with EmmeansResult
    plot_anova(em_within_2x2, x_grouping = :WF1, y_grouping = :WF2)  # Basic 2D plot

    # Precompile sphericity and homogeneity checks
    sphericity_check(res_within)
    check_homogeneity(res_between)

end
