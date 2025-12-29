__precompile__(true)

"""
    AnovaFun.jl

A Julia implementation of a traditional anova type analysis loosely based (inspired) by R's `ez`,
`afex`, and `emmeans` packages. NB: This is not a full implementation (many features are missing!),
but a simplified version implementing basic/standard anova functionality, and functionality that I
currently use. IT IS PROBABLY (DEFINITELY) MISSING SOMETHING (LOTS!) IMPORTANT!
"""
module AnovaFun

using DataFrames
using Distributions: FDist, TDist, Chisq, cdf, quantile
using GLM
using LinearAlgebra
using Makie
using PrettyTables
using Printf
using Statistics: mean, var, median, cov, std, quantile
using StatsModels

# main functions user functions
export anova, emmeans, pairwise, check_homogeneity, sphericity_check, sphericity_correction
export p, f, sphericity, fstat
export m, ci, m_ci
export anova_table, emmeans_table, pairwise_table
export plot_anova
export errorbar_limits!

# types
export AnovaResult, DesignInfo, EmmeansResult, PairwiseResult, AnovaValidationError

# accessor/helper methods
export factors, between_factors, within_factors, n_id, n_effects, design_type
export data, dv, id, model

# TODO: is there a better way to do this? But for now, seems to work fine,
# and as it is such a small dataset other solutions seem overkill!
const ExampleData = joinpath(@__DIR__, "..", "test", "test_data", "dat.csv")

# source files
# Core types and utilities
include("types/types.jl")
include("utils/utils.jl")

# ANOVA computation
include("anova/validation.jl")  # Load validation before anovas.jl
include("anova/anovas.jl")
include("anova/anovas_between.jl")  # Specialized ANOVA implementations
include("anova/anovas_within.jl")
include("anova/anovas_mixed.jl")
include("anova/homogeneity.jl")
include("anova/sphericity.jl")

# Post-hoc analysis
include("emmeans/emmeans.jl")
include("emmeans/pairwise.jl")

# Output formatting
include("output/report.jl")
include("output/tables.jl")

# Plotting
include("plotting/plot_types.jl")  # Plot-related type definitions
include("plotting/plot_config.jl")  # Plot configuration and defaults
include("plotting/plot_utils.jl")  # Plot utility functions
include("plotting/plot_data.jl")  # Data preparation functions
include("plotting/plot_facets.jl")  # Faceting functions
include("plotting/plot.jl")  # Main plot_anova function
include("plotting/primitives/helpers.jl")
include("plotting/primitives/line_bar.jl")
include("plotting/primitives/violin.jl")
include("plotting/primitives/boxplot.jl")
include("plotting/primitives/raincloud.jl")

# Precompilation
include("precompile.jl")

end # module AnovaFun
