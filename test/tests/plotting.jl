using AnovaFun
using DataFrames
using CSV
using Test
using Printf
using Makie

# Use CairoMakie for saving plots
using CairoMakie
CairoMakie.activate!()  # Set CairoMakie as the active backend 

# Create output directory for saved plots
const PLOT_OUTPUT_DIR = joinpath(@__DIR__, "..", "plot_anova_outputs")
mkpath(PLOT_OUTPUT_DIR)

# Counter for unique plot filenames per plot type
plot_counters = Dict{Symbol,Ref{Int}}(
    :line => Ref(0),
    :bar => Ref(0),
    :boxplot => Ref(0),
    :violin => Ref(0),
    :raincloud => Ref(0),
    :raincloud_custom => Ref(0),
    :raincloud_custom_2x2 => Ref(0),
    :mutating => Ref(0),
)

# Helper function to create and save a plot
function create_and_save_plot(test_name, plot_func, args...; kwargs...)
    # Extract plot_type from kwargs (default to :line)
    plot_type = get(kwargs, :plot_type, :line)

    # Get or create counter for this plot type
    if !haskey(plot_counters, plot_type)
        plot_counters[plot_type] = Ref(0)
    end

    plot_counters[plot_type][] += 1
    result = plot_func(args...; kwargs...)

    # Handle both NamedTuple (fig=, axes=) and plain Figure returns
    fig = result isa Figure ? result : result.fig

    # Create subfolder for plot type
    plot_type_dir = joinpath(PLOT_OUTPUT_DIR, string(plot_type))
    mkpath(plot_type_dir)

    filename = @sprintf(
        "%03d_%s.png",
        plot_counters[plot_type][],
        replace(test_name, " " => "_", "(" => "", ")" => "")
    )
    filepath = joinpath(plot_type_dir, filename)
    save(filepath, fig)
    return result
end

# Common test data setup
const TEST_DATA_DIR = joinpath(@__DIR__, "..", "test_data")

# Setup data for within-subjects 2x2
function setup_within_2x2()
    data = CSV.read(joinpath(TEST_DATA_DIR, "data_within_2x2.csv"), DataFrame)
    res = anova(data, :dv, :subject, within = [:WF1, :WF2])
    em = emmeans(res)
    return data, res, em
end

# Setup data for within-subjects 2x2x2
function setup_within_2x2x2()
    data = CSV.read(joinpath(TEST_DATA_DIR, "data_within_2x2x2.csv"), DataFrame)
    res = anova(data, :dv, :subject, within = [:WF1, :WF2, :WF3])
    em = emmeans(res)
    return data, res, em
end

# Setup data for between-subjects 2x2
function setup_between_2x2()
    data = CSV.read(joinpath(TEST_DATA_DIR, "data_between_2x2.csv"), DataFrame)
    res = anova(data, :dv, :subject, between = [:BF1, :BF2])
    em = emmeans(res)
    return data, res, em
end

# Setup data for mixed design
function setup_mixed_WB_2x2()
    data = CSV.read(joinpath(TEST_DATA_DIR, "data_mixed_WB_2x2.csv"), DataFrame)
    res = anova(data, :dv, :subject, within = [:WF1], between = [:BF1])
    em = emmeans(res)
    return data, res, em
end

# Setup data for example 2x2 data (dat.csv)
const ExampleData = joinpath(@__DIR__, "..", "test_data", "dat.csv")
function setup_example_2x2()
    data = CSV.read(ExampleData, DataFrame)
    res = anova(data, :RT, :Subject, within = [:PreviousCongruency, :CurrentCongruency])
    em = emmeans(res)
    return data, res, em
end

@testset "Plotting Tests" begin

    # Reset all counters at start of test suite
    for counter in values(plot_counters)
        counter[] = 0
    end

    # ============================================================================
    # LINE PLOTS
    # ============================================================================
    @testset "Line Plots" begin
        data, res, em = setup_within_2x2()

        @testset "Basic line plot" begin
            fig = create_and_save_plot(
                "Basic line plot",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :line,
            )
            @test fig isa Figure
        end

        @testset "Dodge width - small" begin
            fig = create_and_save_plot(
                "Dodge width small",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :line,
                dodge_width = 0.2,
            )
            @test fig isa Figure
        end

        @testset "Dodge width - large" begin
            fig = create_and_save_plot(
                "Dodge width large",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :line,
                dodge_width = 0.4,
            )
            @test fig isa Figure
        end

        @testset "Custom theme" begin
            custom_theme = Theme(
                palette = (
                    color = [:red, :blue],
                    linewidth = [5.0],
                    marker = [:rect],
                    markersize = [20],
                ),
            )

            fig = create_and_save_plot(
                "Custom theme",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :line,
                theme = custom_theme,
            )
            @test fig isa Figure
        end

        @testset "Error bar customization" begin
            fig = create_and_save_plot(
                "Error bar customization",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :line,
                errorbar_whiskerwidth = 30,
                errorbar_linewidth = 3,
            )
            @test fig isa Figure
        end

        @testset "Facet by columns" begin
            fig = create_and_save_plot(
                "Facet by columns",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                facet_cols = :WF2,
                plot_type = :line,
            )
            @test fig isa Figure
        end

        @testset "Facet by rows" begin
            fig = create_and_save_plot(
                "Facet by rows",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                facet_rows = :WF2,
                plot_type = :line,
            )
            @test fig isa Figure
        end

        @testset "Individual points" begin
            fig = create_and_save_plot(
                "Individual points",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :line,
                individual_data = :points,
            )
            @test fig isa Figure
        end

        @testset "Individual points - custom alpha" begin
            fig = create_and_save_plot(
                "Individual points custom alpha",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :line,
                individual_data = :points,
                individual_data_alpha = 0.1,
            )
            @test fig isa Figure
        end

        @testset "Connected individual points" begin
            fig = create_and_save_plot(
                "Connected individual points",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :line,
                individual_data = :connected_points,
            )
            @test fig isa Figure
        end

        @testset "Connected individual points - custom alphas" begin
            fig = create_and_save_plot(
                "Connected individual points custom alphas",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :line,
                individual_data = :connected_points,
                individual_data_alpha = 0.1,
                individual_data_line_alpha = 0.3,
            )
            @test fig isa Figure
        end

        @testset "Within-participant error bars" begin
            fig = create_and_save_plot(
                "Within-participant error bars",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :line,
                errorbars = :withinSE,
            )
            @test fig isa Figure
        end

        @testset "Main effect only" begin
            fig = create_and_save_plot(
                "Main effect only",
                plot_anova,
                em,
                x_grouping = :WF1,
                plot_type = :line,
            )
            @test fig isa Figure
        end

        # Multi-factor tests
        data_2x2x2, res_2x2x2, em_2x2x2 = setup_within_2x2x2()

        @testset "Facet by columns and rows" begin
            fig = create_and_save_plot(
                "Facet by columns and rows",
                plot_anova,
                em_2x2x2,
                x_grouping = :WF1,
                y_grouping = :WF2,
                facet_cols = :WF3,
                facet_rows = :WF2,
                plot_type = :line,
            )
            @test fig isa Figure
        end

        @testset "Three-way with column facets" begin
            fig = create_and_save_plot(
                "Three way with column facets",
                plot_anova,
                em_2x2x2,
                x_grouping = :WF1,
                y_grouping = :WF2,
                facet_cols = :WF3,
                plot_type = :line,
            )
            @test fig isa Figure
        end

        # Between-subjects tests
        data_between, res_between, em_between = setup_between_2x2()

        @testset "Between-subjects line plot" begin
            fig = create_and_save_plot(
                "Between subjects line plot",
                plot_anova,
                em_between,
                x_grouping = :BF1,
                y_grouping = :BF2,
                plot_type = :line,
            )
            @test fig isa Figure
        end

        @testset "Between-subjects error bars" begin
            fig = create_and_save_plot(
                "Between subjects error bars",
                plot_anova,
                em_between,
                x_grouping = :BF1,
                y_grouping = :BF2,
                plot_type = :line,
                errorbars = :SE,
            )
            @test fig isa Figure
        end

        # Mixed design tests
        data_mixed, res_mixed, em_mixed = setup_mixed_WB_2x2()

        @testset "Mixed design line plot" begin
            fig = create_and_save_plot(
                "Mixed design line plot",
                plot_anova,
                em_mixed,
                x_grouping = :WF1,
                y_grouping = :BF1,
                plot_type = :line,
            )
            @test fig isa Figure
        end

        @testset "Mixed design with faceting" begin
            fig = create_and_save_plot(
                "Mixed design with faceting",
                plot_anova,
                em_mixed,
                x_grouping = :WF1,
                y_grouping = :BF1,
                facet_cols = :BF1,
                plot_type = :line,
            )
            @test fig isa Figure
        end

        # Direct AnovaResult input
        @testset "Plot from AnovaResult" begin
            fig = create_and_save_plot(
                "Plot from AnovaResult",
                plot_anova,
                res,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :line,
            )
            @test fig isa Figure
        end

        @testset "No error bars" begin
            fig = create_and_save_plot(
                "No error bars",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :line,
                errorbars = :none,
            )
            @test fig isa Figure
        end

        @testset "Customization - axis, legend, title, and ylim" begin
            # Combined test for all customization options
            fig = create_and_save_plot(
                "Customization axis, legend, title, and ylim",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :line,
                # Axis customization
                axis_title = "My Plot Title",
                axis_xlabel = "My X Axis",
                axis_ylabel = "My Y Axis",
                axis_ylim = (-1.0, 1.0),
                # Legend customization
                legend_title = "My Factor",
                legend_position = :lb,
            )
            @test fig isa Figure
        end

        @testset "Legend - hide" begin
            fig = create_and_save_plot(
                "Legend hide",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :line,
                legend = false,
            )
            @test fig isa Figure
        end

        @testset "Custom ylim" begin
            fig = create_and_save_plot(
                "Custom ylim",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :line,
                axis_ylim = (-0.5, 0.5),
            )
            @test fig isa Figure
        end

        @testset "Figure size" begin
            fig = create_and_save_plot(
                "Figure size",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :line,
                figure_size = (1200, 800),
            )
            @test fig isa Figure
        end

        # Example data tests
        data_example, res_example, em_example = setup_example_2x2()

        @testset "Example 2x2 data" begin
            fig = create_and_save_plot(
                "Example 2x2 data",
                plot_anova,
                em_example,
                x_grouping = :PreviousCongruency,
                y_grouping = :CurrentCongruency,
                plot_type = :line,
            )
            @test fig isa Figure
        end

        @testset "ggplot2 theme" begin
            fig = create_and_save_plot(
                "ggplot2 theme",
                plot_anova,
                em_example,
                x_grouping = :PreviousCongruency,
                y_grouping = :CurrentCongruency,
                plot_type = :line,
                theme = theme_ggplot2(),
            )
            @test fig isa Figure
        end

        # ─── New kwargs tests ─────────────────────────────────────────────
        @testset "axis_xorder" begin
            fig = create_and_save_plot(
                "axis_xorder",
                plot_anova,
                em_example,
                x_grouping = :CurrentCongruency,
                y_grouping = :PreviousCongruency,
                plot_type = :line,
                axis_xorder = ["Incongruent", "Congruent"],
            )
            @test fig isa Figure
        end

        @testset "axis_yticks" begin
            fig = create_and_save_plot(
                "axis_yticks",
                plot_anova,
                em_example,
                x_grouping = :CurrentCongruency,
                y_grouping = :PreviousCongruency,
                plot_type = :line,
                axis_yticks = 500:25:600,
            )
            @test fig isa Figure
        end

        @testset "legend_labels" begin
            fig = create_and_save_plot(
                "legend_labels",
                plot_anova,
                em_example,
                x_grouping = :CurrentCongruency,
                y_grouping = :PreviousCongruency,
                plot_type = :line,
                legend_labels = ["Prev Con", "Prev Inc"],
            )
            @test fig isa Figure
        end

        @testset "legend_position" begin
            fig = create_and_save_plot(
                "legend_position",
                plot_anova,
                em_example,
                x_grouping = :CurrentCongruency,
                y_grouping = :PreviousCongruency,
                plot_type = :line,
                legend_position = :lb,
            )
            @test fig isa Figure
        end

        @testset "Combined new kwargs" begin
            fig = create_and_save_plot(
                "Combined new kwargs",
                plot_anova,
                em_example,
                x_grouping = :CurrentCongruency,
                y_grouping = :PreviousCongruency,
                plot_type = :line,
                axis_xorder = ["Incongruent", "Congruent"],
                axis_xticklabels = ["Inc", "Con"],
                axis_yticks = 500:25:600,
                axis_ylim = (500, 600),
                legend_labels = ["Prev Con", "Prev Inc"],
                legend_position = :lt,
                legend_framevisible = false,
                legend_title = "Previous",
            )
            @test fig isa Figure
        end

        @testset "axis_xorder invalid level" begin
            @test_throws ArgumentError plot_anova(
                em_example,
                x_grouping = :CurrentCongruency,
                y_grouping = :PreviousCongruency,
                plot_type = :line,
                axis_xorder = ["Invalid", "Congruent"],
            )
        end
    end

    # ============================================================================
    # BAR PLOTS
    # ============================================================================
    @testset "Bar Plots" begin
        data, res, em = setup_within_2x2()

        @testset "Basic bar plot" begin
            fig = create_and_save_plot(
                "Basic bar plot",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :bar,
            )
            @test fig isa Figure
        end

        @testset "Custom theme" begin
            custom_theme = Theme(palette = (color = [:green, :orange], linewidth = [3.0]))

            fig = create_and_save_plot(
                "Custom theme",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :bar,
                theme = custom_theme,
            )
            @test fig isa Figure
        end

        @testset "Error bar customization" begin
            fig = create_and_save_plot(
                "Error bar customization",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :bar,
                errorbar_whiskerwidth = 30,
                errorbar_linewidth = 3,
            )
            @test fig isa Figure
        end

        @testset "Facet by columns" begin
            fig = create_and_save_plot(
                "Facet by columns",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                facet_cols = :WF2,
                plot_type = :bar,
            )
            @test fig isa Figure
        end

        @testset "Facet by rows" begin
            fig = create_and_save_plot(
                "Facet by rows",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                facet_rows = :WF2,
                plot_type = :bar,
            )
            @test fig isa Figure
        end

        @testset "Individual points" begin
            fig = create_and_save_plot(
                "Individual points",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :bar,
                individual_data = :points,
            )
            @test fig isa Figure
        end

        @testset "Individual points custom alpha" begin
            fig = create_and_save_plot(
                "Individual points custom alpha",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :bar,
                individual_data = :points,
                individual_data_alpha = 0.1,
            )
            @test fig isa Figure
        end

        @testset "Connected individual points" begin
            fig = create_and_save_plot(
                "Connected individual points",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :bar,
                individual_data = :connected_points,
            )
            @test fig isa Figure
        end

        @testset "Connected individual points custom alphas" begin
            fig = create_and_save_plot(
                "Connected individual points custom alphas",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :bar,
                individual_data = :connected_points,
                individual_data_alpha = 0.1,
                individual_data_line_alpha = 0.3,
            )
            @test fig isa Figure
        end

        @testset "Within-participant error bars" begin
            fig = create_and_save_plot(
                "Within participant error bars",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :bar,
                errorbars = :withinSE,
            )
            @test fig isa Figure
        end

        @testset "Main effect only" begin
            fig = create_and_save_plot(
                "Main effect only",
                plot_anova,
                em,
                x_grouping = :WF1,
                plot_type = :bar,
            )
            @test fig isa Figure
        end

        # Multi-factor tests
        data_2x2x2, res_2x2x2, em_2x2x2 = setup_within_2x2x2()

        @testset "Facet by columns and rows" begin
            fig = create_and_save_plot(
                "Facet by columns and rows",
                plot_anova,
                em_2x2x2,
                x_grouping = :WF1,
                y_grouping = :WF2,
                facet_cols = :WF3,
                facet_rows = :WF2,
                plot_type = :bar,
            )
            @test fig isa Figure
        end

        @testset "Three-way bar with facets" begin
            fig = create_and_save_plot(
                "Three way bar with facets",
                plot_anova,
                em_2x2x2,
                x_grouping = :WF1,
                y_grouping = :WF2,
                facet_cols = :WF3,
                plot_type = :bar,
            )
            @test fig isa Figure
        end

        # Between-subjects tests
        data_between, res_between, em_between = setup_between_2x2()

        @testset "Between-subjects bar plot" begin
            fig = create_and_save_plot(
                "Between subjects bar plot",
                plot_anova,
                em_between,
                x_grouping = :BF1,
                y_grouping = :BF2,
                plot_type = :bar,
            )
            @test fig isa Figure
        end

        @testset "Between-subjects bar plot with facets" begin
            fig = create_and_save_plot(
                "Between subjects bar plot with facets",
                plot_anova,
                em_between,
                x_grouping = :BF1,
                y_grouping = :BF2,
                facet_cols = :BF2,
                plot_type = :bar,
            )
            @test fig isa Figure
        end

        @testset "Between-subjects error bars" begin
            fig = create_and_save_plot(
                "Between subjects error bars",
                plot_anova,
                em_between,
                x_grouping = :BF1,
                y_grouping = :BF2,
                plot_type = :bar,
                errorbars = :SE,
            )
            @test fig isa Figure
        end

        # Mixed design tests
        data_mixed, res_mixed, em_mixed = setup_mixed_WB_2x2()

        @testset "Mixed design bar plot" begin
            fig = create_and_save_plot(
                "Mixed design bar plot",
                plot_anova,
                em_mixed,
                x_grouping = :WF1,
                y_grouping = :BF1,
                plot_type = :bar,
            )
            @test fig isa Figure
        end

        @testset "Mixed design with faceting" begin
            fig = create_and_save_plot(
                "Mixed design with faceting",
                plot_anova,
                em_mixed,
                x_grouping = :WF1,
                y_grouping = :BF1,
                facet_cols = :BF1,
                plot_type = :bar,
            )
            @test fig isa Figure
        end

        # Direct AnovaResult input
        @testset "Plot from AnovaResult" begin
            fig = create_and_save_plot(
                "Plot from AnovaResult",
                plot_anova,
                res,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :bar,
            )
            @test fig isa Figure
        end

        @testset "Plot from AnovaResult with emmeans_adjust" begin
            fig = create_and_save_plot(
                "Plot from AnovaResult with emmeans_adjust",
                plot_anova,
                res,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :bar,
                emmeans_adjust = :bonferroni,
            )
            @test fig isa Figure
        end

        @testset "No error bars" begin
            fig = create_and_save_plot(
                "No error bars",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :bar,
                errorbars = :none,
            )
            @test fig isa Figure
        end

        @testset "Customization axis, legend, title, and ylim" begin
            # Combined test for all customization options
            fig = create_and_save_plot(
                "Customization axis legend title ylim",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :bar,
                # Axis customization
                axis_title = "My Plot Title",
                axis_xlabel = "My X Axis",
                axis_ylabel = "My Y Axis",
                axis_ylim = (-1.0, 1.0),
                # Legend customization
                legend_title = "My Factor",
                legend_position = :lb,
            )
            @test fig isa Figure
        end

        @testset "Legend hide" begin
            fig = create_and_save_plot(
                "Legend hide",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :bar,
                legend = false,
            )
            @test fig isa Figure
        end

        @testset "Custom ylim" begin
            fig = create_and_save_plot(
                "Custom ylim",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :bar,
                axis_ylim = (-0.5, 0.5),
            )
            @test fig isa Figure
        end

        @testset "Figure size" begin
            fig = create_and_save_plot(
                "Figure size",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :bar,
                figure_size = (1200, 800),
            )
            @test fig isa Figure
        end

        # Example data tests
        data_example, res_example, em_example = setup_example_2x2()

        @testset "Example 2x2 data" begin
            fig = create_and_save_plot(
                "Example 2x2 data",
                plot_anova,
                em_example,
                x_grouping = :PreviousCongruency,
                y_grouping = :CurrentCongruency,
                plot_type = :bar,
            )
            @test fig isa Figure
        end

        @testset "Custom theme 1" begin
            custom_theme = Theme(
                palette = (color = [:black, :grey],),
                Axis = (
                    xlabelsize = 24,
                    ylabelsize = 24,
                    xticklabelsize = 20,
                    yticklabelsize = 20,
                    titlesize = 28,
                ),
                Legend = (labelsize = 18, titlesize = 20),
            )

            fig = create_and_save_plot(
                "Custom theme 1",
                plot_anova,
                em_example,
                x_grouping = :PreviousCongruency,
                y_grouping = :CurrentCongruency,
                plot_type = :bar,
                theme = custom_theme,
                axis_title = "Congruency Sequence Effect",
                axis_xlabel = "Previous Trial",
                axis_ylabel = "Mean RT [ms]",
                legend_title = "Current Trial",
                legend_framevisible = false,
                legend_order = [:Incongruent, :Congruent],
            )
            @test fig isa Figure
        end
    end

    # ============================================================================
    # BOXPLOT PLOTS
    # ============================================================================
    @testset "Boxplot Plots" begin
        data, res, em = setup_within_2x2()

        @testset "Basic boxplot" begin
            fig = create_and_save_plot(
                "Basic boxplot",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :boxplot,
            )
            @test fig isa Figure
        end

        @testset "Boxplot with facets" begin
            fig = create_and_save_plot(
                "Boxplot with facets",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                facet_cols = :WF2,
                plot_type = :boxplot,
            )
            @test fig isa Figure
        end

        @testset "Custom theme" begin
            custom_theme = Theme(palette = (color = [:purple, :pink],))

            fig = create_and_save_plot(
                "Custom theme",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :boxplot,
                theme = custom_theme,
            )
            @test fig isa Figure
        end

        @testset "Individual points" begin
            fig = create_and_save_plot(
                "Individual points",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :boxplot,
                individual_data = :points,
            )
            @test fig isa Figure
        end

        @testset "Individual points custom alpha" begin
            fig = create_and_save_plot(
                "Individual points custom alpha",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :boxplot,
                individual_data = :points,
                individual_data_alpha = 0.1,
            )
            @test fig isa Figure
        end

        @testset "Connected individual points" begin
            fig = create_and_save_plot(
                "Connected individual points",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :boxplot,
                individual_data = :connected_points,
            )
            @test fig isa Figure
        end

        @testset "Connected individual points custom alphas" begin
            fig = create_and_save_plot(
                "Connected individual points custom alphas",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :boxplot,
                individual_data = :connected_points,
                individual_data_alpha = 0.1,
                individual_data_line_alpha = 0.3,
            )
            @test fig isa Figure
        end

        @testset "Main effect only" begin
            fig = create_and_save_plot(
                "Main effect only",
                plot_anova,
                em,
                x_grouping = :WF1,
                plot_type = :boxplot,
            )
            @test fig isa Figure
        end

        # Multi-factor tests
        data_2x2x2, res_2x2x2, em_2x2x2 = setup_within_2x2x2()

        @testset "Facet by columns and rows" begin
            fig = create_and_save_plot(
                "Facet by columns and rows",
                plot_anova,
                em_2x2x2,
                x_grouping = :WF1,
                y_grouping = :WF2,
                facet_cols = :WF3,
                facet_rows = :WF2,
                plot_type = :boxplot,
            )
            @test fig isa Figure
        end

        @testset "Three-way with column facets" begin
            fig = create_and_save_plot(
                "Three-way with column facets",
                plot_anova,
                em_2x2x2,
                x_grouping = :WF1,
                y_grouping = :WF2,
                facet_cols = :WF3,
                plot_type = :boxplot,
            )
            @test fig isa Figure
        end

        # Between-subjects tests
        data_between, res_between, em_between = setup_between_2x2()

        @testset "Between-subjects boxplot" begin
            fig = create_and_save_plot(
                "Between-subjects boxplot",
                plot_anova,
                em_between,
                x_grouping = :BF1,
                y_grouping = :BF2,
                plot_type = :boxplot,
            )
            @test fig isa Figure
        end

        @testset "Between-subjects boxplot with facets" begin
            fig = create_and_save_plot(
                "Between-subjects boxplot with facets",
                plot_anova,
                em_between,
                x_grouping = :BF1,
                y_grouping = :BF2,
                facet_cols = :BF2,
                plot_type = :boxplot,
            )
            @test fig isa Figure
        end

        # Mixed design tests
        data_mixed, res_mixed, em_mixed = setup_mixed_WB_2x2()

        @testset "Mixed design boxplot" begin
            fig = create_and_save_plot(
                "Mixed design boxplot",
                plot_anova,
                em_mixed,
                x_grouping = :WF1,
                y_grouping = :BF1,
                plot_type = :boxplot,
            )
            @test fig isa Figure
        end

        @testset "Mixed design with faceting" begin
            fig = create_and_save_plot(
                "Mixed design with faceting",
                plot_anova,
                em_mixed,
                x_grouping = :WF1,
                y_grouping = :BF1,
                facet_cols = :BF1,
                plot_type = :boxplot,
            )
            @test fig isa Figure
        end

        # Direct AnovaResult input
        @testset "Plot from AnovaResult" begin
            fig = create_and_save_plot(
                "Plot from AnovaResult",
                plot_anova,
                res,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :boxplot,
            )
            @test fig isa Figure
        end

        @testset "Plot from AnovaResult with emmeans_adjust" begin
            fig = create_and_save_plot(
                "Plot from AnovaResult with emmeans_adjust",
                plot_anova,
                res,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :boxplot,
                emmeans_adjust = :bonferroni,
            )
            @test fig isa Figure
        end

        @testset "Customization axis, legend, title, and ylim" begin
            # Combined test for all customization options
            fig = create_and_save_plot(
                "Customization axis legend title ylim",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :boxplot,
                # Axis customization
                axis_title = "My Plot Title",
                axis_xlabel = "My X Axis",
                axis_ylabel = "My Y Axis",
                axis_ylim = (-1.0, 1.0),
                # Legend customization
                legend_title = "My Factor",
                legend_position = :lb,
            )
            @test fig isa Figure
        end

        @testset "Legend hide" begin
            fig = create_and_save_plot(
                "Legend hide",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :boxplot,
                legend = false,
            )
            @test fig isa Figure
        end

        @testset "Custom ylim" begin
            fig = create_and_save_plot(
                "Custom ylim",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :boxplot,
                axis_ylim = (-0.5, 0.5),
            )
            @test fig isa Figure
        end

        @testset "Figure size" begin
            fig = create_and_save_plot(
                "Figure size",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :boxplot,
                figure_size = (1200, 800),
            )
            @test fig isa Figure
        end

        # Example data tests
        data_example, res_example, em_example = setup_example_2x2()

        @testset "Example 2x2 data" begin
            fig = create_and_save_plot(
                "Example 2x2 data",
                plot_anova,
                em_example,
                x_grouping = :PreviousCongruency,
                y_grouping = :CurrentCongruency,
                plot_type = :boxplot,
            )
            @test fig isa Figure
        end
    end

    # ============================================================================
    # VIOLIN PLOTS
    # ============================================================================
    @testset "Violin Plots" begin
        data, res, em = setup_within_2x2()

        @testset "Basic violin plot" begin
            fig = create_and_save_plot(
                "Basic violin plot",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :violin,
            )
            @test fig isa Figure
        end

        @testset "Dodge width - small" begin
            fig = create_and_save_plot(
                "Dodge width small",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :violin,
                dodge_width = 0.2,
            )
            @test fig isa Figure
        end

        @testset "Dodge width - large" begin
            fig = create_and_save_plot(
                "Dodge width large",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :violin,
                dodge_width = 0.4,
            )
            @test fig isa Figure
        end

        @testset "Custom theme" begin
            custom_theme = Theme(palette = (color = [:cyan, :magenta],))

            fig = create_and_save_plot(
                "Custom theme",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :violin,
                theme = custom_theme,
            )
            @test fig isa Figure
        end

        @testset "Facet by columns" begin
            fig = create_and_save_plot(
                "Facet by columns",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                facet_cols = :WF2,
                plot_type = :violin,
            )
            @test fig isa Figure
        end

        @testset "Facet by rows" begin
            fig = create_and_save_plot(
                "Facet by rows",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                facet_rows = :WF2,
                plot_type = :violin,
            )
            @test fig isa Figure
        end

        @testset "Individual points" begin
            fig = create_and_save_plot(
                "Individual points",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :violin,
                individual_data = :points,
            )
            @test fig isa Figure
        end

        @testset "Individual points custom alpha" begin
            fig = create_and_save_plot(
                "Individual points custom alpha",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :violin,
                individual_data = :points,
                individual_data_alpha = 0.1,
            )
            @test fig isa Figure
        end

        @testset "Connected individual points" begin
            fig = create_and_save_plot(
                "Connected individual points",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :violin,
                individual_data = :connected_points,
            )
            @test fig isa Figure
        end

        @testset "Connected individual points custom alphas" begin
            fig = create_and_save_plot(
                "Connected individual points custom alphas",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :violin,
                individual_data = :connected_points,
                individual_data_alpha = 0.1,
                individual_data_line_alpha = 0.3,
            )
            @test fig isa Figure
        end

        @testset "Main effect only" begin
            fig = create_and_save_plot(
                "Main effect only",
                plot_anova,
                em,
                x_grouping = :WF1,
                plot_type = :violin,
            )
            @test fig isa Figure
        end

        # Multi-factor tests
        data_2x2x2, res_2x2x2, em_2x2x2 = setup_within_2x2x2()

        @testset "Facet by columns and rows" begin
            fig = create_and_save_plot(
                "Facet by columns and rows",
                plot_anova,
                em_2x2x2,
                x_grouping = :WF1,
                y_grouping = :WF2,
                facet_cols = :WF3,
                facet_rows = :WF2,
                plot_type = :violin,
            )
            @test fig isa Figure
        end

        @testset "Three-way violin with facets" begin
            fig = create_and_save_plot(
                "Three-way violin with facets",
                plot_anova,
                em_2x2x2,
                x_grouping = :WF1,
                y_grouping = :WF2,
                facet_cols = :WF3,
                plot_type = :violin,
            )
            @test fig isa Figure
        end

        # Between-subjects tests
        data_between, res_between, em_between = setup_between_2x2()

        @testset "Between-subjects violin plot" begin
            fig = create_and_save_plot(
                "Between-subjects violin plot",
                plot_anova,
                em_between,
                x_grouping = :BF1,
                y_grouping = :BF2,
                plot_type = :violin,
            )
            @test fig isa Figure
        end

        @testset "Between-subjects violin plot with facets" begin
            fig = create_and_save_plot(
                "Between-subjects violin plot with facets",
                plot_anova,
                em_between,
                x_grouping = :BF1,
                y_grouping = :BF2,
                facet_cols = :BF2,
                plot_type = :violin,
            )
            @test fig isa Figure
        end

        # Mixed design tests
        data_mixed, res_mixed, em_mixed = setup_mixed_WB_2x2()

        @testset "Mixed design violin plot" begin
            fig = create_and_save_plot(
                "Mixed design violin plot",
                plot_anova,
                em_mixed,
                x_grouping = :WF1,
                y_grouping = :BF1,
                plot_type = :violin,
            )
            @test fig isa Figure
        end

        @testset "Mixed design with faceting" begin
            fig = create_and_save_plot(
                "Mixed design with faceting",
                plot_anova,
                em_mixed,
                x_grouping = :WF1,
                y_grouping = :BF1,
                facet_cols = :BF1,
                plot_type = :violin,
            )
            @test fig isa Figure
        end

        # Direct AnovaResult input
        @testset "Plot from AnovaResult" begin
            fig = create_and_save_plot(
                "Plot from AnovaResult",
                plot_anova,
                res,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :violin,
            )
            @test fig isa Figure
        end

        @testset "Plot from AnovaResult with emmeans_adjust" begin
            fig = create_and_save_plot(
                "Plot from AnovaResult with emmeans_adjust",
                plot_anova,
                res,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :violin,
                emmeans_adjust = :bonferroni,
            )
            @test fig isa Figure
        end

        @testset "Customization axis legend title ylim" begin
            # Combined test for all customization options
            fig = create_and_save_plot(
                "Customization axis legend title ylim",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :violin,
                # Axis customization
                axis_title = "My Plot Title",
                axis_xlabel = "My X Axis",
                axis_ylabel = "My Y Axis",
                axis_ylim = (-1.0, 1.0),
                # Legend customization
                legend_title = "My Factor",
                legend_position = :lb,
            )
            @test fig isa Figure
        end

        @testset "Legend hide" begin
            fig = create_and_save_plot(
                "Legend hide",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :violin,
                legend = false,
            )
            @test fig isa Figure
        end

        @testset "Custom ylim" begin
            fig = create_and_save_plot(
                "Custom ylim",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :violin,
                axis_ylim = (-0.5, 0.5),
            )
            @test fig isa Figure
        end

        @testset "Figure size" begin
            fig = create_and_save_plot(
                "Figure size",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :violin,
                figure_size = (1200, 800),
            )
            @test fig isa Figure
        end

        # Example data tests
        data_example, res_example, em_example = setup_example_2x2()

        @testset "Example 2x2 data" begin
            fig = create_and_save_plot(
                "Example 2x2 data",
                plot_anova,
                em_example,
                x_grouping = :PreviousCongruency,
                y_grouping = :CurrentCongruency,
                plot_type = :violin,
            )
            @test fig isa Figure
        end
    end

    # ============================================================================
    # RAINCLOUD PLOTS
    # ============================================================================
    @testset "Raincloud Plots" begin
        data, res, em = setup_within_2x2()

        @testset "Basic raincloud plot" begin
            fig = create_and_save_plot(
                "Basic raincloud plot",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :raincloud,
            )
            @test fig isa Figure
        end

        @testset "Raincloud with facets" begin
            fig = create_and_save_plot(
                "Raincloud with facets",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                facet_cols = :WF2,
                plot_type = :raincloud,
            )
            @test fig isa Figure
        end

        @testset "Custom theme" begin
            custom_theme = Theme(palette = (color = [:yellow, :brown],))

            fig = create_and_save_plot(
                "Custom theme",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :raincloud,
                theme = custom_theme,
            )
            @test fig isa Figure
        end

        @testset "Individual points" begin
            fig = create_and_save_plot(
                "Individual points",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :raincloud,
                individual_data = :points,
            )
            @test fig isa Figure
        end

        @testset "Individual points custom alpha" begin
            fig = create_and_save_plot(
                "Individual points custom alpha",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :raincloud,
                individual_data = :points,
                individual_data_alpha = 0.1,
            )
            @test fig isa Figure
        end

        @testset "Main effect only" begin
            fig = create_and_save_plot(
                "Main effect only",
                plot_anova,
                em,
                x_grouping = :WF1,
                plot_type = :raincloud,
            )
            @test fig isa Figure
        end

        @testset "Facet by columns" begin
            fig = create_and_save_plot(
                "Facet by columns",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                facet_cols = :WF2,
                plot_type = :raincloud,
            )
            @test fig isa Figure
        end

        @testset "Facet by rows" begin
            fig = create_and_save_plot(
                "Facet by rows",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                facet_rows = :WF2,
                plot_type = :raincloud,
            )
            @test fig isa Figure
        end

        # Multi-factor tests
        data_2x2x2, res_2x2x2, em_2x2x2 = setup_within_2x2x2()

        @testset "Facet by columns and rows" begin
            fig = create_and_save_plot(
                "Facet by columns and rows",
                plot_anova,
                em_2x2x2,
                x_grouping = :WF1,
                y_grouping = :WF2,
                facet_cols = :WF3,
                facet_rows = :WF2,
                plot_type = :raincloud,
            )
            @test fig isa Figure
        end

        @testset "Three-way raincloud with facets" begin
            fig = create_and_save_plot(
                "Three-way raincloud with facets",
                plot_anova,
                em_2x2x2,
                x_grouping = :WF1,
                y_grouping = :WF2,
                facet_cols = :WF3,
                plot_type = :raincloud,
            )
            @test fig isa Figure
        end

        # Between-subjects tests
        data_between, res_between, em_between = setup_between_2x2()

        @testset "Between-subjects raincloud" begin
            fig = create_and_save_plot(
                "Between-subjects raincloud",
                plot_anova,
                em_between,
                x_grouping = :BF1,
                y_grouping = :BF2,
                plot_type = :raincloud,
            )
            @test fig isa Figure
        end

        @testset "Between-subjects raincloud with facets" begin
            fig = create_and_save_plot(
                "Between-subjects raincloud with facets",
                plot_anova,
                em_between,
                x_grouping = :BF1,
                y_grouping = :BF2,
                facet_cols = :BF2,
                plot_type = :raincloud,
            )
            @test fig isa Figure
        end

        # Mixed design tests
        data_mixed, res_mixed, em_mixed = setup_mixed_WB_2x2()

        @testset "Mixed design raincloud" begin
            fig = create_and_save_plot(
                "Mixed design raincloud",
                plot_anova,
                em_mixed,
                x_grouping = :WF1,
                y_grouping = :BF1,
                plot_type = :raincloud,
            )
            @test fig isa Figure
        end

        @testset "Mixed design with faceting" begin
            fig = create_and_save_plot(
                "Mixed design with faceting",
                plot_anova,
                em_mixed,
                x_grouping = :WF1,
                y_grouping = :BF1,
                facet_cols = :BF1,
                plot_type = :raincloud,
            )
            @test fig isa Figure
        end

        # Direct AnovaResult input
        @testset "Plot from AnovaResult" begin
            fig = create_and_save_plot(
                "Plot from AnovaResult",
                plot_anova,
                res,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :raincloud,
            )
            @test fig isa Figure
        end

        @testset "Plot from AnovaResult with emmeans_adjust" begin
            fig = create_and_save_plot(
                "Plot from AnovaResult with emmeans_adjust",
                plot_anova,
                res,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :raincloud,
                emmeans_adjust = :bonferroni,
            )
            @test fig isa Figure
        end

        @testset "Dodge width - small" begin
            fig = create_and_save_plot(
                "Dodge width small",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :raincloud,
                dodge_width = 0.2,
            )
            @test fig isa Figure
        end

        @testset "Dodge width - large" begin
            fig = create_and_save_plot(
                "Dodge width large",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :raincloud,
                dodge_width = 0.8,
            )
            @test fig isa Figure
        end

        @testset "Customization axis legend title ylim" begin
            # Combined test for all customization options
            fig = create_and_save_plot(
                "Customization axis legend title ylim",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :raincloud,
                # Axis customization
                axis_title = "My Plot Title",
                axis_xlabel = "My X Axis",
                axis_ylabel = "My Y Axis",
                axis_ylim = (-1.0, 1.0),
                # Legend customization
                legend_title = "My Factor",
                legend_position = :lb,
            )
            @test fig isa Figure
        end

        @testset "Legend hide" begin
            fig = create_and_save_plot(
                "Legend hide",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :raincloud,
                legend = false,
            )
            @test fig isa Figure
        end

        @testset "Custom ylim" begin
            fig = create_and_save_plot(
                "Custom ylim",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :raincloud,
                axis_ylim = (-0.5, 0.5),
            )
            @test fig isa Figure
        end

        @testset "Figure size" begin
            fig = create_and_save_plot(
                "Figure size",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :raincloud,
                figure_size = (1200, 800),
            )
            @test fig isa Figure
        end

        # Example data tests
        data_example, res_example, em_example = setup_example_2x2()

        @testset "Example 2x2 data" begin
            fig = create_and_save_plot(
                "Example 2x2 data",
                plot_anova,
                em_example,
                x_grouping = :PreviousCongruency,
                y_grouping = :CurrentCongruency,
                plot_type = :raincloud,
            )
            @test fig isa Figure
        end
    end

    # ============================================================================
    # RAINCLOUD_CUSTOM PLOTS
    # ============================================================================
    @testset "Raincloud Custom Plots" begin
        data, res, em = setup_within_2x2()

        @testset "Basic raincloud_custom plot" begin
            fig = create_and_save_plot(
                "Basic raincloud_custom plot",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :raincloud_custom,
            )
            @test fig isa Figure
        end

        @testset "Custom theme" begin
            custom_theme = Theme(palette = (color = [:teal, :coral],))

            fig = create_and_save_plot(
                "Custom theme",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :raincloud_custom,
                theme = custom_theme,
            )
            @test fig isa Figure
        end

        @testset "Individual points" begin
            fig = create_and_save_plot(
                "Individual points",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :raincloud_custom,
                individual_data = :points,
            )
            @test fig isa Figure
        end

        @testset "Individual points custom alpha" begin
            fig = create_and_save_plot(
                "Individual points custom alpha",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :raincloud_custom,
                individual_data = :points,
                individual_data_alpha = 0.1,
            )
            @test fig isa Figure
        end

        @testset "Main effect only" begin
            fig = create_and_save_plot(
                "Main effect only",
                plot_anova,
                em,
                x_grouping = :WF1,
                plot_type = :raincloud_custom,
            )
            @test fig isa Figure
        end

        # Connected points only make sense when pairing by x-levels (no y_grouping)
        @testset "Connected points x-level pairing" begin
            fig = create_and_save_plot(
                "Connected points x-level pairing",
                plot_anova,
                em,
                x_grouping = :WF1,
                plot_type = :raincloud_custom,
                individual_data = :connected_points,
            )
            @test fig isa Figure
        end

        @testset "Connected points x-level pairing custom alphas" begin
            fig = create_and_save_plot(
                "Connected points x-level pairing custom alphas",
                plot_anova,
                em,
                x_grouping = :WF1,
                plot_type = :raincloud_custom,
                individual_data = :connected_points,
                individual_data_alpha = 0.1,
                individual_data_line_alpha = 0.3,
            )
            @test fig isa Figure
        end

        @testset "Facet by columns" begin
            fig = create_and_save_plot(
                "Facet by columns",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                facet_cols = :WF2,
                plot_type = :raincloud_custom,
            )
            @test fig isa Figure
        end

        @testset "Facet by rows" begin
            fig = create_and_save_plot(
                "Facet by rows",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                facet_rows = :WF2,
                plot_type = :raincloud_custom,
            )
            @test fig isa Figure
        end

        @testset "Raincloud_custom with facets" begin
            fig = create_and_save_plot(
                "Raincloud_custom with facets",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                facet_cols = :WF2,
                plot_type = :raincloud_custom,
            )
            @test fig isa Figure
        end

        # Multi-factor tests
        data_2x2x2, res_2x2x2, em_2x2x2 = setup_within_2x2x2()

        @testset "Facet by columns and rows" begin
            fig = create_and_save_plot(
                "Facet by columns and rows",
                plot_anova,
                em_2x2x2,
                x_grouping = :WF1,
                y_grouping = :WF2,
                facet_cols = :WF3,
                facet_rows = :WF2,
                plot_type = :raincloud_custom,
            )
            @test fig isa Figure
        end

        @testset "Three-way raincloud_custom with facets" begin
            fig = create_and_save_plot(
                "Three-way raincloud_custom with facets",
                plot_anova,
                em_2x2x2,
                x_grouping = :WF1,
                y_grouping = :WF2,
                facet_cols = :WF3,
                plot_type = :raincloud_custom,
            )
            @test fig isa Figure
        end

        # Between-subjects tests
        data_between, res_between, em_between = setup_between_2x2()

        @testset "Between-subjects raincloud_custom" begin
            fig = create_and_save_plot(
                "Between-subjects raincloud_custom",
                plot_anova,
                em_between,
                x_grouping = :BF1,
                y_grouping = :BF2,
                plot_type = :raincloud_custom,
            )
            @test fig isa Figure
        end

        @testset "Between-subjects raincloud_custom with facets" begin
            fig = create_and_save_plot(
                "Between-subjects raincloud_custom with facets",
                plot_anova,
                em_between,
                x_grouping = :BF1,
                y_grouping = :BF2,
                facet_cols = :BF2,
                plot_type = :raincloud_custom,
            )
            @test fig isa Figure
        end

        # Mixed design tests
        data_mixed, res_mixed, em_mixed = setup_mixed_WB_2x2()

        @testset "Mixed design raincloud_custom" begin
            fig = create_and_save_plot(
                "Mixed design raincloud_custom",
                plot_anova,
                em_mixed,
                x_grouping = :WF1,
                y_grouping = :BF1,
                plot_type = :raincloud_custom,
            )
            @test fig isa Figure
        end

        @testset "Mixed design with faceting" begin
            fig = create_and_save_plot(
                "Mixed design with faceting",
                plot_anova,
                em_mixed,
                x_grouping = :WF1,
                y_grouping = :BF1,
                facet_cols = :BF1,
                plot_type = :raincloud_custom,
            )
            @test fig isa Figure
        end

        # Direct AnovaResult input
        @testset "Plot from AnovaResult" begin
            fig = create_and_save_plot(
                "Plot from AnovaResult",
                plot_anova,
                res,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :raincloud_custom,
            )
            @test fig isa Figure
        end

        @testset "Plot from AnovaResult with emmeans_adjust" begin
            fig = create_and_save_plot(
                "Plot from AnovaResult with emmeans_adjust",
                plot_anova,
                res,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :raincloud_custom,
                emmeans_adjust = :bonferroni,
            )
            @test fig isa Figure
        end

        @testset "Customization axis legend title ylim" begin
            # Combined test for all customization options
            fig = create_and_save_plot(
                "Customization axis legend title ylim",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :raincloud_custom,
                # Axis customization
                axis_title = "My Plot Title",
                axis_xlabel = "My X Axis",
                axis_ylabel = "My Y Axis",
                axis_ylim = (-1.0, 1.0),
                # Legend customization
                legend_title = "My Factor",
                legend_position = :lb,
            )
            @test fig isa Figure
        end

        @testset "Legend hide" begin
            fig = create_and_save_plot(
                "Legend hide",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :raincloud_custom,
                legend = false,
            )
            @test fig isa Figure
        end

        @testset "Custom ylim" begin
            fig = create_and_save_plot(
                "Custom ylim",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :raincloud_custom,
                axis_ylim = (-0.5, 0.5),
            )
            @test fig isa Figure
        end

        @testset "Figure size" begin
            fig = create_and_save_plot(
                "Figure size",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :raincloud_custom,
                figure_size = (1200, 800),
            )
            @test fig isa Figure
        end

        # Offset customization examples
        @testset "Offset points over boxplot" begin
            fig = create_and_save_plot(
                "Offset points over boxplot",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :raincloud_custom,
                individual_data = :points,
                raincloud_box_offset = 0.15,
                raincloud_points_offset = 0.15,  # Same as box = overlay
            )
            @test fig isa Figure
        end

        @testset "Offset wide spacing" begin
            fig = create_and_save_plot(
                "Offset wide spacing",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :raincloud_custom,
                individual_data = :points,
                raincloud_violin_offset = 0.5,
                raincloud_box_offset = 0.3,
                raincloud_points_offset = 0.1,
            )
            @test fig isa Figure
        end

        @testset "Offset compact spacing" begin
            fig = create_and_save_plot(
                "Offset compact spacing",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :raincloud_custom,
                individual_data = :points,
                raincloud_violin_offset = 0.2,
                raincloud_box_offset = 0.1,
                raincloud_points_offset = 0.0,
            )
            @test fig isa Figure
        end

        # Component visibility tests
        @testset "Hide violin" begin
            fig = create_and_save_plot(
                "Hide violin",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :raincloud_custom,
                individual_data = :points,
                raincloud_show_violin = false,
            )
            @test fig isa Figure
        end

        @testset "Hide boxplot" begin
            fig = create_and_save_plot(
                "Hide boxplot",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :raincloud_custom,
                individual_data = :points,
                raincloud_show_boxplot = false,
            )
            @test fig isa Figure
        end

        @testset "Hide mean" begin
            fig = create_and_save_plot(
                "Hide mean",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :raincloud_custom,
                individual_data = :points,
                errorbars = :withinSE,
                raincloud_show_mean = false,
            )
            @test fig isa Figure
        end

        @testset "Points only" begin
            fig = create_and_save_plot(
                "Points only",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :raincloud_custom,
                individual_data = :points,
                raincloud_show_violin = false,
                raincloud_show_boxplot = false,
                raincloud_show_mean = false,
                legend_show = false,  # No labeled plots when both violin and boxplot hidden
            )
            @test fig isa Figure
        end

        @testset "Violin and points only" begin
            fig = create_and_save_plot(
                "Violin and points only",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :raincloud_custom,
                individual_data = :points,
                raincloud_show_boxplot = false,
                raincloud_show_mean = false,
            )
            @test fig isa Figure
        end

        # Example data tests for raincloud_custom
        data_example, res_example, em_example = setup_example_2x2()

        @testset "Example 2x2 data" begin
            fig = create_and_save_plot(
                "Example 2x2 data",
                plot_anova,
                em_example,
                x_grouping = :PreviousCongruency,
                y_grouping = :CurrentCongruency,
                plot_type = :raincloud_custom,
            )
            @test fig isa Figure
        end
    end

    # ============================================================================
    # RAINCLOUD_CUSTOM_2x2 PLOTS
    # ============================================================================
    @testset "Raincloud Custom 2x2 Plots" begin
        data, res, em = setup_within_2x2()

        @testset "Basic raincloud_custom_2x2 plot" begin
            fig = create_and_save_plot(
                "Basic raincloud_custom_2x2 plot",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :raincloud_custom_2x2,
            )
            @test fig isa Figure
        end

        @testset "Custom theme" begin
            custom_theme = Theme(palette = (color = [:teal, :coral],))

            fig = create_and_save_plot(
                "Custom theme",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :raincloud_custom_2x2,
                theme = custom_theme,
            )
            @test fig isa Figure
        end

        @testset "Individual points" begin
            fig = create_and_save_plot(
                "Individual points",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :raincloud_custom_2x2,
                individual_data = :points,
            )
            @test fig isa Figure
        end

        @testset "Individual points custom alpha" begin
            fig = create_and_save_plot(
                "Individual points custom alpha",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :raincloud_custom_2x2,
                individual_data = :points,
                individual_data_alpha = 0.1,
            )
            @test fig isa Figure
        end

        @testset "Connected points" begin
            fig = create_and_save_plot(
                "Connected points",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :raincloud_custom_2x2,
                individual_data = :connected_points,
            )
            @test fig isa Figure
        end

        @testset "Connected points custom alphas" begin
            fig = create_and_save_plot(
                "Connected points custom alphas",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :raincloud_custom_2x2,
                individual_data = :connected_points,
                individual_data_alpha = 0.1,
                individual_data_line_alpha = 0.3,
            )
            @test fig isa Figure
        end

        @testset "Error bars" begin
            fig = create_and_save_plot(
                "Error bars",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :raincloud_custom_2x2,
                errorbars = :withinSE,
            )
            @test fig isa Figure
        end

        @testset "Facet by columns" begin
            data_2x2x2, res_2x2x2, em_2x2x2 = setup_within_2x2x2()
            fig = create_and_save_plot(
                "Facet by columns",
                plot_anova,
                em_2x2x2,
                x_grouping = :WF1,
                y_grouping = :WF2,
                facet_cols = :WF3,
                plot_type = :raincloud_custom_2x2,
            )
            @test fig isa Figure
        end

        @testset "Facet by rows" begin
            data_2x2x2, res_2x2x2, em_2x2x2 = setup_within_2x2x2()
            fig = create_and_save_plot(
                "Facet by rows",
                plot_anova,
                em_2x2x2,
                x_grouping = :WF1,
                y_grouping = :WF2,
                facet_rows = :WF3,
                plot_type = :raincloud_custom_2x2,
            )
            @test fig isa Figure
        end

        @testset "Three-way with facets" begin
            data_2x2x2, res_2x2x2, em_2x2x2 = setup_within_2x2x2()
            fig = create_and_save_plot(
                "Three-way with facets",
                plot_anova,
                em_2x2x2,
                x_grouping = :WF1,
                y_grouping = :WF2,
                facet_cols = :WF3,
                plot_type = :raincloud_custom_2x2,
            )
            @test fig isa Figure
        end

        # Between-subjects tests
        data_between, res_between, em_between = setup_between_2x2()

        @testset "Between-subjects" begin
            fig = create_and_save_plot(
                "Between-subjects",
                plot_anova,
                em_between,
                x_grouping = :BF1,
                y_grouping = :BF2,
                plot_type = :raincloud_custom_2x2,
            )
            @test fig isa Figure
        end

        @testset "Between-subjects with facets" begin
            fig = create_and_save_plot(
                "Between-subjects with facets",
                plot_anova,
                em_between,
                x_grouping = :BF1,
                y_grouping = :BF2,
                facet_cols = :BF2,
                plot_type = :raincloud_custom_2x2,
            )
            @test fig isa Figure
        end

        # Mixed design tests
        data_mixed, res_mixed, em_mixed = setup_mixed_WB_2x2()

        @testset "Mixed design" begin
            fig = create_and_save_plot(
                "Mixed design",
                plot_anova,
                em_mixed,
                x_grouping = :WF1,
                y_grouping = :BF1,
                plot_type = :raincloud_custom_2x2,
            )
            @test fig isa Figure
        end

        @testset "Mixed design with faceting" begin
            fig = create_and_save_plot(
                "Mixed design with faceting",
                plot_anova,
                em_mixed,
                x_grouping = :WF1,
                y_grouping = :BF1,
                facet_cols = :BF1,
                plot_type = :raincloud_custom_2x2,
            )
            @test fig isa Figure
        end

        # Plot from AnovaResult
        @testset "Plot from AnovaResult" begin
            fig = create_and_save_plot(
                "Plot from AnovaResult",
                plot_anova,
                res,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :raincloud_custom_2x2,
            )
            @test fig isa Figure
        end

        @testset "Plot from AnovaResult with emmeans_adjust" begin
            fig = create_and_save_plot(
                "Plot from AnovaResult with emmeans_adjust",
                plot_anova,
                res,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :raincloud_custom_2x2,
                emmeans_adjust = :bonferroni,
            )
            @test fig isa Figure
        end

        @testset "Customization axis legend title ylim" begin
            fig = create_and_save_plot(
                "Customization axis legend title ylim",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :raincloud_custom_2x2,
                axis_xlabel = "Custom X",
                axis_ylabel = "Custom Y",
                title = "Custom Title",
                axis_ylim = (-3, 3),
                legend_position = :rt,
            )
            @test fig isa Figure
        end

        @testset "Advanced customization with colors, labels, and legend" begin
            data_example, res_example, em_example = setup_example_2x2()

            custom_theme = Theme(
                palette = (color = [:red, :blue],),
                Axis = (xlabelsize = 14, ylabelsize = 14),
                Legend = (titlefontsize = 12,),
            )

            fig = create_and_save_plot(
                "Advanced customization with colors, labels, and legend",
                plot_anova,
                em_example,
                x_grouping = :CurrentCongruency,
                y_grouping = :PreviousCongruency,
                plot_type = :raincloud_custom_2x2,
                theme = custom_theme,
                axis_xlabel = "Current Trial Type",
                axis_ylabel = "Reaction Time (ms)",
                legend_title = "Previous Trial",
            )
            @test fig isa Figure
        end

        @testset "Legend hide" begin
            fig = create_and_save_plot(
                "Legend hide",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :raincloud_custom_2x2,
                legend_show = false,
            )
            @test fig isa Figure
        end

        @testset "Custom ylim" begin
            fig = create_and_save_plot(
                "Custom ylim",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :raincloud_custom_2x2,
                axis_ylim = (-5, 5),
            )
            @test fig isa Figure
        end

        @testset "Figure size" begin
            fig = create_and_save_plot(
                "Figure size",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :raincloud_custom_2x2,
                figure_size = (1200, 800),
            )
            @test fig isa Figure
        end

        # Offset customization examples
        @testset "Offset points over boxplot" begin
            fig = create_and_save_plot(
                "Offset points over boxplot",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :raincloud_custom_2x2,
                individual_data = :points,
                raincloud_box_offset = 0.15,
                raincloud_points_offset = 0.15,  # Same as box = overlay
            )
            @test fig isa Figure
        end

        @testset "Offset wide spacing" begin
            fig = create_and_save_plot(
                "Offset wide spacing",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :raincloud_custom_2x2,
                individual_data = :points,
                raincloud_violin_offset = 0.5,
                raincloud_box_offset = 0.3,
                raincloud_points_offset = 0.1,
            )
            @test fig isa Figure
        end

        @testset "Offset compact spacing" begin
            fig = create_and_save_plot(
                "Offset compact spacing",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :raincloud_custom_2x2,
                individual_data = :points,
                raincloud_violin_offset = 0.2,
                raincloud_box_offset = 0.1,
                raincloud_points_offset = 0.0,
            )
            @test fig isa Figure
        end

        # Component visibility tests
        @testset "Hide violin" begin
            fig = create_and_save_plot(
                "Hide violin",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :raincloud_custom_2x2,
                individual_data = :points,
                raincloud_show_violin = false,
            )
            @test fig isa Figure
        end

        @testset "Hide boxplot" begin
            fig = create_and_save_plot(
                "Hide boxplot",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :raincloud_custom_2x2,
                individual_data = :points,
                raincloud_show_boxplot = false,
            )
            @test fig isa Figure
        end

        @testset "Hide mean" begin
            fig = create_and_save_plot(
                "Hide mean",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :raincloud_custom_2x2,
                individual_data = :points,
                errorbars = :withinSE,
                raincloud_show_mean = false,
            )
            @test fig isa Figure
        end

        @testset "Points only" begin
            fig = create_and_save_plot(
                "Points only",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :raincloud_custom_2x2,
                individual_data = :points,
                raincloud_show_violin = false,
                raincloud_show_boxplot = false,
                raincloud_show_mean = false,
                legend_show = false,  # No labeled plots when both violin and boxplot hidden
            )
            @test fig isa Figure
        end

        @testset "Violin and points only" begin
            fig = create_and_save_plot(
                "Violin and points only",
                plot_anova,
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :raincloud_custom_2x2,
                individual_data = :points,
                raincloud_show_boxplot = false,
                raincloud_show_mean = false,
            )
            @test fig isa Figure
        end

        # Example data tests
        data_example, res_example, em_example = setup_example_2x2()

        @testset "Example 2x2 data" begin
            fig = create_and_save_plot(
                "Example 2x2 data",
                plot_anova,
                em_example,
                x_grouping = :PreviousCongruency,
                y_grouping = :CurrentCongruency,
                plot_type = :raincloud_custom_2x2,
            )
            @test fig isa Figure
        end
    end

    # ============================================================================
    # MUTATING VARIANT: plot_anova!
    # ============================================================================
    @testset "plot_anova! (Mutating)" begin
        data, res, em = setup_within_2x2()
        data_example, res_example, em_example = setup_example_2x2()

        # Helper: create & save a figure produced by one or more plot_anova! calls
        function save_mutating_plot(test_name, fig)
            plot_counters[:mutating][] += 1
            plot_type_dir = joinpath(PLOT_OUTPUT_DIR, "mutating")
            mkpath(plot_type_dir)
            filename = @sprintf(
                "%03d_%s.png",
                plot_counters[:mutating][],
                replace(test_name, " " => "_", "(" => "", ")" => ""),
            )
            save(joinpath(plot_type_dir, filename), fig)
            return fig
        end

        @testset "Single panel into fig[1,1]" begin
            fig = Figure(size = (800, 600))
            returned = plot_anova!(
                fig[1, 1],
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :line,
            )
            # plot_anova! should return the parent Figure
            @test returned === fig
            save_mutating_plot("single panel line", fig)
        end

        @testset "Single panel from AnovaResult" begin
            fig = Figure(size = (800, 600))
            returned = plot_anova!(
                fig[1, 1],
                res,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :line,
            )
            @test returned === fig
            save_mutating_plot("single panel from AnovaResult", fig)
        end

        @testset "Two plots side by side (combined figure)" begin
            data_mixed, res_mixed, em_mixed = setup_mixed_WB_2x2()
            fig = Figure(size = (1600, 700))
            plot_anova!(
                fig[1, 1],
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :line,
                axis_ylabel = "DV (within 2×2)",
            )
            plot_anova!(
                fig[1, 2],
                em_mixed,
                x_grouping = :WF1,
                y_grouping = :BF1,
                plot_type = :line,
                axis_ylabel = "DV (mixed)",
            )
            @test fig isa Figure
            save_mutating_plot("two plots side by side", fig)
        end

        @testset "Two plots stacked vertically" begin
            fig = Figure(size = (800, 1200))
            plot_anova!(
                fig[1, 1],
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :line,
                axis_title = "Line Plot",
            )
            plot_anova!(
                fig[2, 1],
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :bar,
                axis_title = "Bar Plot",
            )
            @test fig isa Figure
            save_mutating_plot("two plots stacked vertically", fig)
        end

        @testset "Bar plot into sub-position" begin
            fig = Figure(size = (800, 600))
            returned = plot_anova!(
                fig[1, 1],
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :bar,
            )
            @test returned === fig
            save_mutating_plot("bar plot sub-position", fig)
        end

        @testset "Main effect only in sub-position" begin
            fig = Figure(size = (800, 600))
            returned = plot_anova!(
                fig[1, 1],
                em,
                x_grouping = :WF1,
                plot_type = :line,
            )
            @test returned === fig
            save_mutating_plot("main effect only sub-position", fig)
        end

        @testset "With facet cols in sub-position" begin
            data_2x2x2, res_2x2x2, em_2x2x2 = setup_within_2x2x2()
            fig = Figure(size = (1200, 600))
            returned = plot_anova!(
                fig[1, 1],
                em_2x2x2,
                x_grouping = :WF1,
                y_grouping = :WF2,
                facet_cols = :WF3,
                plot_type = :line,
            )
            @test returned === fig
            save_mutating_plot("facet cols sub-position", fig)
        end

        @testset "Custom axis labels in sub-position" begin
            fig = Figure(size = (800, 600))
            returned = plot_anova!(
                fig[1, 1],
                em_example,
                x_grouping = :PreviousCongruency,
                y_grouping = :CurrentCongruency,
                plot_type = :line,
                axis_xlabel = "Previous Congruency",
                axis_ylabel = "RT (ms)",
                axis_title = "Congruency Effect",
                legend_title = "Current",
            )
            @test returned === fig
            save_mutating_plot("custom axis labels sub-position", fig)
        end

        @testset "No error bars in sub-position" begin
            fig = Figure(size = (800, 600))
            returned = plot_anova!(
                fig[1, 1],
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :line,
                errorbars = :none,
            )
            @test returned === fig
            save_mutating_plot("no error bars sub-position", fig)
        end

        @testset "Within-subject error bars in sub-position" begin
            fig = Figure(size = (800, 600))
            returned = plot_anova!(
                fig[1, 1],
                em,
                x_grouping = :WF1,
                y_grouping = :WF2,
                plot_type = :line,
                errorbars = :withinSE,
            )
            @test returned === fig
            save_mutating_plot("within SE sub-position", fig)
        end
    end  # @testset "plot_anova! (Mutating)"
end

# Print summary
println("\n✓ All plotting tests passed!")
println("All plots saved to: $PLOT_OUTPUT_DIR")
total_plots = sum(c[] for c in values(plot_counters))
println("Total plots saved: $total_plots")
