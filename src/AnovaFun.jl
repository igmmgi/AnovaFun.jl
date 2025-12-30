__precompile__(true)

"""
    AnovaFun.jl

A Julia implementation of a traditional anova type analysis loosely based (inspired) by R's `ez`,
`afex`, and `emmeans` packages. NB: This is not a full implementation (many features are missing!),
but a simplified version implementing basic/standard anova functionality, and functionality that I
currently use. IT IS PROBABLY (DEFINITELY!) MISSING SOMETHING (LOTS!) IMPORTANT!
"""
module AnovaFun

using DataFrames
using Distributions: FDist, TDist, Chisq, MvNormal, cdf, quantile
using GLM
using LinearAlgebra
using Logging
using Random

# Import Makie - backends are loaded/activated by users
using Makie
using PrettyTables
using Printf
using Statistics: mean, var, median, cov, std, quantile, cor
using StatsModels

# main functions user functions
export anova, emmeans, pairwise, check_homogeneity, sphericity_check, sphericity_correction
export p, f, sphericity, fstat, tstat
export m, ci, m_ci
export paired_ttest, independent_ttest
export anova_table, emmeans_table, pairwise_table
export plot_anova, plot_sample_size

# types
export AnovaResult, DesignInfo, EmmeansResult, PairwiseResult, PowerResult, SampleSizeResult

# accessor/helper methods
export factors, between_factors, within_factors, n_id, n_effects, design_type, model

# power analysis
export simulate_data, power_analysis, sample_size, within_correlation_matrix

# TODO: is there a better way to do this? But for now, seems to work fine,
# and as it is such a small dataset other solutions seem overkill!
const ExampleData = joinpath(@__DIR__, "..", "test", "test_data", "dat.csv")

# source files
# Core types and utilities
include("utils/errors.jl")
include("types/types.jl")
include("utils/utils.jl")

# ANOVA computation
include("anova/validation.jl")  # Load validation before anovas.jl
include("anova/ttests.jl")
include("anova/anovas.jl")
include("anova/anovas_between.jl")  # Specialized ANOVA implementations
include("anova/anovas_within.jl")
include("anova/anovas_mixed.jl")
include("anova/homogeneity.jl")
include("anova/sphericity.jl")

# Post-hoc analysis
include("emmeans/emmeans.jl")
include("emmeans/pairwise.jl")

# Power analysis
include("power/simulate.jl")
include("power/power.jl")
include("power/sample_size.jl")

# Output formatting
include("output/report.jl")
include("output/tables.jl")

# Plotting
include("plotting/plot_types.jl")  # Plot-related type definitions
include("plotting/plot_config.jl")  # Plot configuration and defaults
include("plotting/plot_utils.jl")  # Plot utility functions
include("plotting/plot_data.jl")  # Data preparation functions
include("plotting/plot_facets.jl")  # Faceting functions
include("plotting/plot_preparation.jl")  # Parameter preparation
include("plotting/plot_panels.jl")  # Panel plotting
include("plotting/plot_postprocessing.jl")  # Post-processing
include("plotting/plot.jl")  # Main plot_anova function
include("plotting/primitives/common.jl")  # Common utilities for primitives
include("plotting/primitives/distribution_base.jl")  # Base for distribution plots
include("plotting/primitives/line_bar.jl")  # Line and bar plots
include("plotting/primitives/violin.jl")  # Violin plots
include("plotting/primitives/boxplot.jl")  # Box plots
include("plotting/primitives/component_renderer.jl")  # Unified raincloud component rendering
include("plotting/primitives/raincloud.jl")  # Raincloud plots

# Precompilation
include("precompile.jl")

end # module AnovaFun
