using Pkg
Pkg.activate(".")
using AnovaFun
using DataFrames
using CSV
# Import CairoMakie for CI testing to ensure headless compatibility
if get(ENV, "CI", "false") == "true" || get(ENV, "GITHUB_ACTIONS", "false") == "true"
    using CairoMakie
    CairoMakie.activate!()
end
using BenchmarkTools

data = CSV.read(AnovaFun.ExampleData, DataFrame)
res = anova(data, :RT, :Subject, within = [:PreviousCongruency, :CurrentCongruency]);
em = emmeans(res);



plot_anova(
    em,
    x_grouping = :PreviousCongruency,
    y_grouping = :CurrentCongruency,
    individual_data = :none,
    axis_ylim = (480, 620),
    errorbars = :withinSE,
    theme = Theme(palette = (color = [:red, :blue],)),
)



plot_anova(
    em,
    x_grouping = :PreviousCongruency,
    y_grouping = :CurrentCongruency,
    plot_type = :raincloud_custom_2x2,
    individual_data = :connected_points,
    legend_title = nothing,
    legend_framevisible = false,
    legend_position = :lt,
    theme = Theme(Axis = (xlabelsize = 10,)),
)

# plot(..., theme = Theme(Axis = (xlabelsize = 30, ygridcolor = :red)))

# TODO: fix my custom raincloud plot
# TODO: pre-compile some functions


#------------------------------------------------------------------------------
# line plots
#------------------------------------------------------------------------------
plot_anova(res, x_grouping = :CurrentCongruency)
plot_anova(res, x_grouping = :CurrentCongruency, individual_data = :connected_points)
plot_anova(res, x_grouping = :CurrentCongruency, individual_data = :connected_points)
plot_anova(
    em,
    x_grouping = :PreviousCongruency,
    y_grouping = :CurrentCongruency,
    individual_data = :none,
    dodge_width = 0.25,
    legend_title = "test",
    legend_framevisible = false,
    legend_order = [1, 2],
)

plot_anova(
    em,
    x_grouping = :PreviousCongruency,
    y_grouping = :CurrentCongruency,
    individual_data = :none,
    dodge_width = 0.25,
    legend_title = "test",
    legend_framevisible = false,
    legend_order = [:Incongruent, :Congruent],
)


plot_anova(
    em,
    x_grouping = :PreviousCongruency,
    y_grouping = :CurrentCongruency,
    individual_data = :points,
    dodge_width = 0.25,
) # messes up the main point
plot_anova(
    em,
    x_grouping = :PreviousCongruency,
    y_grouping = :CurrentCongruency,
    individual_data = :connected_points,
    dodge_width = 0.25,
) # messes up the main point and main line of second group

# facet example
plot_anova(
    res,
    x_grouping = :PreviousCongruency,
    facet_cols = :CurrentCongruency,
    individual_data = :connected_points,
    theme = Theme(Axis = (titlesize = 100,)),
)




plot_anova(
    res,
    x_grouping = :PreviousCongruency,
    facet_cols = :CurrentCongruency,
    individual_data = :connected_points,
    ylim = (450, 650),
)


#------------------------------------------------------------------------------
# boxplots
#------------------------------------------------------------------------------
plot_anova(res, x_grouping = :CurrentCongruency, plot_type = :boxplot)
plot_anova(
    res,
    x_grouping = :CurrentCongruency,
    plot_type = :boxplot,
    individual_data = :points,
)
plot_anova(
    res,
    x_grouping = :CurrentCongruency,
    plot_type = :boxplot,
    individual_data = :connected_points,
)

plot_anova(
    em,
    x_grouping = :PreviousCongruency,
    y_grouping = :CurrentCongruency,
    plot_type = :boxplot,
    individual_data = :connected_points,
    dodge_width = 0.2,
)
plot_anova(
    em,
    x_grouping = :PreviousCongruency,
    y_grouping = :CurrentCongruency,
    plot_type = :boxplot,
    individual_data = :points,
    dodge_width = 0.25,
) # messes up the main point
plot_anova(
    em,
    x_grouping = :PreviousCongruency,
    y_grouping = :CurrentCongruency,
    plot_type = :boxplot,
    individual_data = :connected_points,
    dodge_width = 0.25,
) # messes up the main point and main line of second group
plot_anova(
    em,
    x_grouping = :PreviousCongruency,
    y_grouping = :CurrentCongruency,
    plot_type = :boxplot,
    individual_data = :points,
    point_alpha = 1,
    dodge_width = 0.25,
) # messes up the main point and main line of second group

# facet example
plot_anova(
    res,
    x_grouping = :PreviousCongruency,
    facet_cols = :CurrentCongruency,
    individual_data = :connected_points,
    plot_type = :boxplot,
)
plot_anova(
    res,
    x_grouping = :PreviousCongruency,
    facet_cols = :CurrentCongruency,
    individual_data = :connected_points,
    ylim = (450, 650),
    plot_type = :boxplot,
)


#------------------------------------------------------------------------------
# violin
#------------------------------------------------------------------------------
plot_anova(
    res,
    x_grouping = :CurrentCongruency,
    plot_type = :violin,
    violin_transparency = 0.1,
)
plot_anova(
    res,
    x_grouping = :CurrentCongruency,
    plot_type = :violin,
    individual_data = :points,
)
plot_anova(
    res,
    x_grouping = :CurrentCongruency,
    plot_type = :violin,
    individual_data = :connected_points,
)

plot_anova(
    em,
    x_grouping = :PreviousCongruency,
    y_grouping = :CurrentCongruency,
    plot_type = :violin,
    individual_data = :connected_points,
    dodge_width = 0.2,
)
plot_anova(
    em,
    x_grouping = :PreviousCongruency,
    y_grouping = :CurrentCongruency,
    plot_type = :violin,
    individual_data = :connected_points,
    dodge_width = 0.25,
) # messes up the main point and main line of second group

# facet example
plot_anova(
    res,
    x_grouping = :PreviousCongruency,
    facet_cols = :CurrentCongruency,
    individual_data = :connected_points,
    plot_type = :violin,
)
plot_anova(
    res,
    x_grouping = :PreviousCongruency,
    facet_cols = :CurrentCongruency,
    individual_data = :connected_points,
    ylim = (450, 650),
    plot_type = :violin,
)


#------------------------------------------------------------------------------
# barplot
#------------------------------------------------------------------------------
plot_anova(res, x_grouping = :CurrentCongruency, plot_type = :bar)
plot_anova(
    res,
    x_grouping = :CurrentCongruency,
    plot_type = :bar,
    individual_data = :points,
)
plot_anova(
    res,
    x_grouping = :CurrentCongruency,
    plot_type = :bar,
    individual_data = :connected_points,
)
plot_anova(
    em,
    x_grouping = :PreviousCongruency,
    y_grouping = :CurrentCongruency,
    plot_type = :bar,
    individual_data = :connected_points,
    dodge_width = 0.2,
)

# facet example
plot_anova(
    res,
    x_grouping = :PreviousCongruency,
    facet_cols = :CurrentCongruency,
    individual_data = :connected_points,
    plot_type = :bar,
)
plot_anova(
    res,
    x_grouping = :PreviousCongruency,
    facet_cols = :CurrentCongruency,
    individual_data = :connected_points,
    ylim = (450, 650),
    plot_type = :bar,
)



#------------------------------------------------------------------------------
# raincloud
#------------------------------------------------------------------------------
plot_anova(em, x_grouping = :CurrentCongruency, plot_type = :raincloud)
plot_anova(
    em,
    x_grouping = :PreviousCongruency,
    y_grouping = :CurrentCongruency,
    plot_type = :raincloud,
)

# facet example
plot_anova(
    res,
    x_grouping = :PreviousCongruency,
    facet_cols = :CurrentCongruency,
    individual_data = :connected_points,
    plot_type = :raincloud,
)
plot_anova(
    res,
    x_grouping = :PreviousCongruency,
    facet_cols = :CurrentCongruency,
    individual_data = :connected_points,
    ylim = (450, 650),
    plot_type = :raincloud,
)

# customisation
plot_anova(
    res,
    x_grouping = :CurrentCongruency,
    plot_type = :raincloud,
    raincloud_markersize = 10,
    raincloud_plot_boxplots = false,
    raincloud_cloud_width = 0.25,
    raincloud_boxplot_width = 0.05,
)

plot_anova(
    em,
    x_grouping = :PreviousCongruency,
    y_grouping = :CurrentCongruency,
    plot_type = :raincloud,
    dodge_width = 0.5,
    raincloud_cloud_width = 0.5,
    raincloud_plot_boxplots = true,
    raincloud_center_boxplot = false,
    raincloud_boxplot_nudge = -0.05,
    raincloud_gap = 0.5,
    raincloud_side_nudge = 0.1,
)


#------------------------------------------------------------------------------
# raincloud
#------------------------------------------------------------------------------
plot_anova(em, x_grouping = :CurrentCongruency, plot_type = :raincloud_custom)
plot_anova(
    em,
    x_grouping = :PreviousCongruency,
    y_grouping = :CurrentCongruency,
    plot_type = :raincloud_custom,
)

# facet example
plot_anova(
    res,
    x_grouping = :PreviousCongruency,
    facet_cols = :CurrentCongruency,
    individual_data = :connected_points,
    plot_type = :raincloud,
)
plot_anova(
    res,
    x_grouping = :PreviousCongruency,
    facet_cols = :CurrentCongruency,
    individual_data = :connected_points,
    ylim = (450, 650),
    plot_type = :raincloud,
)

# customisation
plot_anova(
    res,
    x_grouping = :CurrentCongruency,
    plot_type = :raincloud,
    raincloud_markersize = 10,
    raincloud_plot_boxplots = false,
    raincloud_cloud_width = 0.25,
    raincloud_boxplot_width = 0.05,
)

plot_anova(
    em,
    x_grouping = :PreviousCongruency,
    y_grouping = :CurrentCongruency,
    plot_type = :raincloud,
    dodge_width = 0.5,
    raincloud_cloud_width = 0.5,
    raincloud_plot_boxplots = true,
    raincloud_center_boxplot = false,
    raincloud_boxplot_nudge = -0.05,
    raincloud_gap = 0.5,
    raincloud_side_nudge = 0.1,
)


#------------------------------------------------------------------------------
# Multiple y_factors example (y_grouping with 2+ factors)
#------------------------------------------------------------------------------
# Load data with 3 factors to demonstrate multiple y_factors
data_3way =
    CSV.read(joinpath(@__DIR__, "..", "test_data", "data_within_2x2x2.csv"), DataFrame)
res_3way = anova(data_3way, :dv, :subject, within = [:WF1, :WF2, :WF3])
em_3way = emmeans(res_3way)

# Example: x_grouping uses WF1, y_grouping uses both WF2 and WF3
# The legend title will be "WF2 × WF3" and each entry will show combinations like "F2_L1 × F3_L1"
plot_anova(em_3way, x_grouping = :WF1, y_grouping = (:WF2, :WF3), plot_type = :line)
plot_anova(
    em_3way,
    x_grouping = :WF1,
    y_grouping = (:WF2, :WF3),
    plot_type = :bar,
    individual_data = :connected_points,
)
plot_anova(
    em_3way,
    x_grouping = (:WF1, :WF2),
    y_grouping = (:WF3),
    plot_type = :boxplot,
    individual_data = :points,
    dodge_width = 0.25,
)


#------------------------------------------------------------------------------
# 2x2x2x2 within-subjects example (4 factors, each with 2 levels)
#------------------------------------------------------------------------------
# Generate synthetic data for a 2x2x2x2 within-subjects design
n_id = 20
subjects = repeat(1:n_id, inner = 16)  # 2^4 = 16 conditions per subject

# Create all combinations of 4 factors, each with 2 levels
A = repeat([:A1, :A2], outer = 8)
B = repeat([:B1, :B2], outer = 4, inner = 2)
C = repeat([:C1, :C2], outer = 2, inner = 4)
D = repeat([:D1, :D2], inner = 8)

# Repeat for all subjects
A = repeat(A, outer = n_id)
B = repeat(B, outer = n_id)
C = repeat(C, outer = n_id)
D = repeat(D, outer = n_id)

# Generate dependent variable with some effects
# Base effect + main effects + interactions
dv =
    100 .+ 10 .* (A .== :A2) .+ 8 .* (B .== :B2) .+ 6 .* (C .== :C2) .+ 4 .* (D .== :D2) .+
    5 .* (A .== :A2) .* (B .== :B2) .+  # AB interaction
    3 .* (A .== :A2) .* (C .== :C2) .+  # AC interaction
    randn(length(subjects)) .* 15  # Add noise

data_2x2x2x2 = DataFrame(subject = subjects, A = A, B = B, C = C, D = D, dv = dv)

res_2x2x2x2 = anova(data_2x2x2x2, :dv, :subject, within = [:A, :B, :C, :D])
em_2x2x2x2 = emmeans(res_2x2x2x2)

# Example plots with different factor combinations
# Single factor on x-axisa


plot_anova(
    em_2x2x2x2,
    x_grouping = :A,
    y_grouping = :B,
    facet_cols = :C,
    facet_rows = :D,
    plot_type = :line,
    legend_when_faceting = true,
    theme = Theme(Axis = (titlesize = 30,)),
)

# Two factors: one on x, one on y (legend)
plot_anova(
    em_2x2x2x2,
    x_grouping = :A,
    y_grouping = :B,
    plot_type = :line,
    individual_data = :connected_points,
)

# Three factors: one on x, two on y (legend shows combinations)
plot_anova(
    em_2x2x2x2,
    x_grouping = :A,
    y_grouping = (:B, :C),
    plot_type = :bar,
    dodge_width = 0.3,
)

# Four factors: two on x, two on y
plot_anova(
    em_2x2x2x2,
    x_grouping = (:A, :B),
    y_grouping = (:C, :D),
    plot_type = :line,
    individual_data = :points,
)

# With faceting
plot_anova(em_2x2x2x2, x_grouping = :A, y_grouping = :B, facet_cols = :C, plot_type = :bar)
plot_anova(
    em_2x2x2x2,
    x_grouping = :A,
    y_grouping = :B,
    facet_cols = :C,
    facet_rows = :D,
    plot_type = :line,
    individual_data = :connected_points,
)
