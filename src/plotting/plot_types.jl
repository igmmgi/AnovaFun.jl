"""
Plot-related type definitions for AnovaFun plotting system.

This file contains struct definitions used throughout the plotting module.
"""

"""
Internal struct to hold plot specification for a single panel.
"""
struct PlotPanelSpec
    ax::Axis
    raw_data::DataFrame  # Filtered raw data for this panel
    emmeans_data::DataFrame  # Filtered emmeans for this panel
    x_levels::Vector
    y_levels::Union{Nothing,Vector}
    plot_kwargs::Dict{Symbol,Any}
    x_factors::Vector{Symbol}
    y_factors::Vector{Symbol}
    effect_factors::Vector{Symbol}
    dv::Union{Nothing,Symbol}
    id_col::Union{Nothing,Symbol}
end

"""
Facet specification struct. Specifies how to facet the plot.
"""
struct FacetSpec
    col_factors::Union{Nothing,Vector{Symbol}}
    row_factors::Union{Nothing,Vector{Symbol}}
    col_levels::Vector  # always a vector ([nothing] if no facets)
    row_levels::Vector  # always a vector ([nothing] if no facets)
    col_indices::Vector{Int}
    row_indices::Vector{Int}
end

"""
Manages a grid of axes for faceted plots.
"""
struct FacetGrid
    fig::Figure
    axes::Matrix{Axis}
    spec::FacetSpec
end

"""
Facet context bundling common parameters for plot functions.
Dramatically reduces parameter lists from 8+ params down to 3-4.
"""
struct FacetContext
    col_factors::Union{Nothing,Vector{Symbol}}
    col_levels::Union{Nothing,String}
    row_factors::Union{Nothing,Vector{Symbol}}
    row_levels::Union{Nothing,String}
    y_faceting::Bool
end
