using AnovaFun
using Test

@testset "PlotConfig" begin

    # ─── Constructor defaults ───────────────────────────────────────────────
    @testset "Default construction" begin
        config = AnovaFun.PlotConfig()

        # Spot-check defaults from each struct
        @test config.violin.width == 0.25
        @test config.violin.alpha == 0.3
        @test config.violin.strokecolor == :grey
        @test config.boxplot.show_median == true
        @test config.boxplot.show_outliers == false
        @test config.errorbar.linewidth == 2
        @test config.individual_data.color_mode == :match
        @test config.individual_data.alpha == 0.5
        @test config.bar.width == 0.2
        @test config.bar.strokecolor == :black
        @test config.raincloud.show_violin == true
        @test config.raincloud.show_boxplot == true
        @test config.raincloud.show_mean == true
        @test config.layout.panel_width == 800
        @test config.layout.panel_height == 600
        @test config.jitter.dodged_mult == 0.6
        @test config.ylim.padding == 0.1
        @test config.axis.ylabel == "Mean"
        @test isnothing(config.axis.xlabel)
        @test isnothing(config.axis.ylim)
        @test isnothing(config.figure.size)
        @test config.legend.show == true
        @test config.legend.position == :rt
        @test config.dodge_width == 0.0
        @test isnothing(config.theme)
        @test isnothing(config._resolved_theme)
    end

    # ─── Prefix routing ────────────────────────────────────────────────────
    @testset "Prefix routing" begin
        config = AnovaFun.PlotConfig(;
            violin_width = 0.5,
            boxplot_show_median = false,
            errorbar_linewidth = 5,
            individual_data_alpha = 0.8,
            bar_strokewidth = 3.0,
            raincloud_jitter_mult = 0.2,
            layout_panel_width = 1200,
            jitter_single_width = 0.15,
            ylim_padding = 0.2,
            axis_ylabel = "Custom Y",
            figure_size = (1000, 800),
            legend_position = :lb,
            dodge_width = 0.5,
        )

        @test config.violin.width == 0.5
        @test config.boxplot.show_median == false
        @test config.errorbar.linewidth == 5
        @test config.individual_data.alpha == 0.8
        @test config.bar.strokewidth == 3.0
        @test config.raincloud.jitter_mult == 0.2
        @test config.layout.panel_width == 1200
        @test config.jitter.single_width == 0.15
        @test config.ylim.padding == 0.2
        @test config.axis.ylabel == "Custom Y"
        @test config.figure.size == (1000, 800)
        @test config.legend.position == :lb
        @test config.dodge_width == 0.5
    end

    # ─── Raincloud 2x2 prefix routing ──────────────────────────────────────
    @testset "Raincloud 2x2 prefix mapping" begin
        config = AnovaFun.PlotConfig(;
            raincloud_2x2_violin_offset = 0.1,
            raincloud_2x2_box_dodge = 0.05,
        )

        @test config.raincloud.x2x2_violin_offset == 0.1
        @test config.raincloud.x2x2_box_dodge == 0.05
        # Non-2x2 fields should still be default
        @test config.raincloud.violin_offset == 0.15
    end

    # ─── Top-level aliases ─────────────────────────────────────────────────
    @testset "title alias" begin
        # `title` maps to axis.title
        config = AnovaFun.PlotConfig(; title = "My Title")
        @test config.axis.title == "My Title"

        # Explicit axis_title takes precedence over title
        config2 = AnovaFun.PlotConfig(; title = "Alias", axis_title = "Explicit")
        @test config2.axis.title == "Explicit"
    end

    @testset "legend = false alias" begin
        config = AnovaFun.PlotConfig(; legend = false)
        @test config.legend.show == false

        # Explicit legend_show takes precedence
        config2 = AnovaFun.PlotConfig(; legend = false, legend_show = true)
        @test config2.legend.show == true
    end

    # ─── Typo detection ───────────────────────────────────────────────────
    @testset "Typo detection" begin
        @test_throws ArgumentError AnovaFun.PlotConfig(; violin_colr = :red)
        @test_throws ArgumentError AnovaFun.PlotConfig(; boxplot_shoow_median = true)
        @test_throws ArgumentError AnovaFun.PlotConfig(; errobar_linewidth = 3)
        @test_throws ArgumentError AnovaFun.PlotConfig(; completely_unknown = 42)
    end

    # ─── Axis Makie passthrough ────────────────────────────────────────────
    @testset "Axis Makie passthrough" begin
        config = AnovaFun.PlotConfig(;
            axis_xlabelsize = 30,
            axis_ylabel = "Custom",
        )
        @test config.axis.ylabel == "Custom"
        @test config.axis.makie_attrs[:xlabelsize] == 30
    end

    # ─── to_dict round-trip ────────────────────────────────────────────────
    @testset "to_dict round-trip" begin
        config = AnovaFun.PlotConfig(;
            violin_width = 0.5,
            boxplot_alpha = 0.6,
            axis_ylabel = "Test",
            raincloud_2x2_box_dodge = 0.07,
            dodge_width = 0.4,
        )
        d = AnovaFun.to_dict(config)

        @test d[:violin_width] == 0.5
        @test d[:boxplot_alpha] == 0.6
        @test d[:axis_ylabel] == "Test"
        @test d[:raincloud_2x2_box_dodge] == 0.07
        @test d[:dodge_width] == 0.4
    end

    # ─── to_fields_dict ────────────────────────────────────────────────────
    @testset "to_fields_dict" begin
        vk = AnovaFun.ViolinKwargs(; color = :red, width = 0.3)
        d = AnovaFun.to_fields_dict(vk)
        @test d[:color] == :red
        @test d[:width] == 0.3
        @test haskey(d, :strokecolor)  # non-nothing defaults included
    end

    # ─── to_makie_dict ─────────────────────────────────────────────────────
    @testset "to_makie_dict for AxisKwargs" begin
        ak = AnovaFun.AxisKwargs(;
            ylabel = "Y",
            xlabel = "X",
            xticklabels = ["a", "b"],
            makie_attrs = Dict{Symbol,Any}(:xlabelsize => 30),
        )
        d = AnovaFun.to_makie_dict(ak)
        @test d[:ylabel] == "Y"
        @test d[:xlabel] == "X"
        @test d[:xlabelsize] == 30
        @test !haskey(d, :xticklabels)  # custom field, not forwarded to Makie
        @test !haskey(d, :xlim)         # custom field, not forwarded to Makie
    end

    @testset "to_makie_dict for LegendKwargs with positioning exclusion" begin
        lk = AnovaFun.LegendKwargs(;
            position = :rt,
            makie_attrs = Dict{Symbol,Any}(:halign => :left, :framevisible => true),
        )
        d = AnovaFun.to_makie_dict(lk; exclude_positioning = true)
        @test !haskey(d, :halign)
        @test d[:framevisible] == true
        @test d[:position] == :rt
    end

    # ─── New AxisKwargs fields ────────────────────────────────────────────
    @testset "AxisKwargs new fields - defaults" begin
        config = AnovaFun.PlotConfig()
        @test isnothing(config.axis.xorder)
        @test isnothing(config.axis.yticks)
        @test isnothing(config.axis.xticklabels)
    end

    @testset "AxisKwargs new fields - routing" begin
        config = AnovaFun.PlotConfig(;
            axis_xorder = ["B", "A"],
            axis_yticks = 0:10:100,
        )
        @test config.axis.xorder == ["B", "A"]
        @test config.axis.yticks == 0:10:100
    end

    @testset "to_makie_dict excludes custom axis fields" begin
        ak = AnovaFun.AxisKwargs(;
            ylabel = "Y",
            xticklabels = ["a", "b"],
            xorder = ["b", "a"],
            yticks = 0:10:100,
        )
        d = AnovaFun.to_makie_dict(ak)
        @test d[:ylabel] == "Y"
        @test !haskey(d, :xticklabels)
        @test !haskey(d, :xorder)
        @test !haskey(d, :yticks)
    end

    # ─── New LegendKwargs field ───────────────────────────────────────────
    @testset "LegendKwargs labels - default" begin
        config = AnovaFun.PlotConfig()
        @test isnothing(config.legend.labels)
    end

    @testset "LegendKwargs labels - routing" begin
        config = AnovaFun.PlotConfig(; legend_labels = ["A", "B"])
        @test config.legend.labels == ["A", "B"]
    end

    # ─── _resolve_legend_label helper ─────────────────────────────────────
    @testset "_resolve_legend_label" begin
        y_unique = ["level1", "level2"]

        # Without custom labels — returns string(y_level)
        config_no_labels = AnovaFun.PlotConfig()
        @test AnovaFun._resolve_legend_label(config_no_labels, "level1", y_unique) == "level1"
        @test isnothing(AnovaFun._resolve_legend_label(config_no_labels, nothing, y_unique))

        # With custom labels — maps by position
        config_labels = AnovaFun.PlotConfig(; legend_labels = ["Custom A", "Custom B"])
        @test AnovaFun._resolve_legend_label(config_labels, "level1", y_unique) == "Custom A"
        @test AnovaFun._resolve_legend_label(config_labels, "level2", y_unique) == "Custom B"
    end

    # ─── _apply_xorder! helper ────────────────────────────────────────────
    @testset "_apply_xorder!" begin
        # No xorder — no change
        x = ["A", "B", "C"]
        config_no = AnovaFun.PlotConfig()
        AnovaFun._apply_xorder!(x, config_no)
        @test x == ["A", "B", "C"]

        # With xorder — reorders in place
        x2 = ["A", "B", "C"]
        config_order = AnovaFun.PlotConfig(; axis_xorder = ["C", "A", "B"])
        AnovaFun._apply_xorder!(x2, config_order)
        @test x2 == ["C", "A", "B"]

        # Invalid level — throws
        x3 = ["A", "B"]
        config_bad = AnovaFun.PlotConfig(; axis_xorder = ["A", "X"])
        @test_throws ArgumentError AnovaFun._apply_xorder!(x3, config_bad)

        # Wrong count — throws
        x4 = ["A", "B"]
        config_short = AnovaFun.PlotConfig(; axis_xorder = ["A"])
        @test_throws ArgumentError AnovaFun._apply_xorder!(x4, config_short)
    end
end

