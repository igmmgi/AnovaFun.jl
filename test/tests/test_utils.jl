using AnovaFun
using CSV
using DataFrames
using GLM
using LinearAlgebra
using Statistics
using Test

# values extracted from the R output within the file test_data.R
const TEST_DATA_DIR = joinpath(@__DIR__, "..", "test_data")

# tolerance 
const RTOL = 0.001
const RTOL_EMMEANS = 0.005 # needs more relaxed criterion as decimal places reported in R!

# function to compute sort key for effect names
# Order: (Intercept) first, then main effects, then interactions by complexity
function effect_sort_key(effect_name::String)
    effect_name == "Intercept" && return (0, 0, "")  # First

    # Split by × to get individual factors
    factors = [strip(f) for f in split(effect_name, "×")]
    n_factors = length(factors)

    # Sort factors alphabetically for consistent ordering
    sorted_factors = sort(factors)

    # Return tuple: (interaction_order, n_factors, sorted_factor_string)
    # interaction_order: 1 for main effects, 2 for two-way, 3 for three-way, etc.
    return (n_factors, n_factors, join(sorted_factors, " × "))
end

function create_expected_table(expected_effects)
    expected_rows = []
    for (effect_name, expected) in expected_effects
        row = Dict{Symbol,Any}(:Effect => effect_name)
        haskey(expected, :DFn) && (row[:DFn] = expected[:DFn])
        haskey(expected, :DFd) && (row[:DFd] = expected[:DFd])
        haskey(expected, :SSn) && (row[:SSn] = expected[:SSn])
        haskey(expected, :SSd) && (row[:SSd] = expected[:SSd])
        haskey(expected, :F) && (row[:F] = expected[:F])
        haskey(expected, :p) && (row[:p] = expected[:p])
        # Compute pes from SSn and SSd
        if haskey(expected, :SSn) && haskey(expected, :SSd)
            row[:pes] = expected[:SSn] / (expected[:SSn] + expected[:SSd])
        end
        push!(expected_rows, row)
    end

    # Sort rows by effect name using sort key
    sort!(expected_rows, by = row -> effect_sort_key(row[:Effect]))

    # Ensure consistent column order: Effect, DFn, DFd, SSn, SSd, F, p, pes
    df = DataFrame(expected_rows)
    col_order = [:Effect, :DFn, :DFd, :SSn, :SSd, :F, :p, :pes]
    existing_cols = Symbol[]
    df_names = [Symbol(n) for n in names(df)]
    for col in col_order
        col in df_names && push!(existing_cols, col)
    end
    for col in df_names
        col ∉ existing_cols && push!(existing_cols, col)
    end
    return isempty(existing_cols) ? df : df[!, existing_cols]
end

# function to format design summary
function format_design_summary(design::DesignInfo)
    design_type =
        design.type == :between ? "Between-Subjects" :
        design.type == :within ? "Within-Subjects" : "Mixed Design"

    parts = String[]
    push!(parts, design_type)

    if !isempty(design.between_factors)
        push!(parts, "Between: $(join(string.(design.between_factors), ", "))")
    end
    if !isempty(design.within_factors)
        push!(parts, "Within: $(join(string.(design.within_factors), ", "))")
    end

    return join(parts, " | ")
end

# function to check DataFrame results match expected values
function check_anova_result(
    result,
    expected_effects,
    emmeans_result = nothing,
    pairwise_result = nothing;
    print_tables = false,
)
    result_df = result.table
    design_info = result.design

    # Create expected table and reorder to match Julia's result order
    expected_table = create_expected_table(expected_effects)

    # Reorder expected table to match Julia's result order
    julia_order = result_df.Effect
    expected_dict = Dict(row.Effect => row for row in eachrow(expected_table))
    reordered_rows =
        [expected_dict[name] for name in julia_order if haskey(expected_dict, name)]
    # Add any effects in expected but not in Julia (shouldn't happen, but be safe)
    for row in eachrow(expected_table)
        row.Effect ∉ julia_order && push!(reordered_rows, row)
    end
    expected_table = DataFrame(reordered_rows)

    if print_tables
        design_summary = format_design_summary(design_info)
        println("\n" * "="^80)
        println("R ANOVA TABLE (Expected) - $design_summary")
        println("="^80)
        display(expected_table)
        println("\n" * "="^80)
        println("JULIA ANOVA TABLE (Computed) - $design_summary")
        println("="^80)
        display(result_df)
        println("="^80)

        if !isnothing(emmeans_result)
            println("\nESTIMATED MARGINAL MEANS")
            println("="^80)
            display(emmeans_result)
            println("="^80 * "\n")
        end

        if !isnothing(pairwise_result)
            println("\nPAIRWISE COMPARISONS")
            println("="^80)
            display(pairwise_result)
            println("="^80 * "\n")
        end
    end

    for (effect_name, expected) in expected_effects
        row = filter(row -> row.Effect == effect_name, result_df)
        if nrow(row) == 0
            error(
                "Effect '$effect_name' not found in results. Available effects: $(unique(result_df.Effect))",
            )
        end

        row = row[1, :]
        if haskey(expected, :DFn)
            if row.DFn != expected[:DFn]
                println(
                    "FAIL: $effect_name DFn: got $(row.DFn), expected $(expected[:DFn])",
                )
            end
            @test row.DFn == expected[:DFn]
        end
        if haskey(expected, :DFd)
            if row.DFd != expected[:DFd]
                println(
                    "FAIL: $effect_name DFd: got $(row.DFd), expected $(expected[:DFd])",
                )
            end
            @test row.DFd == expected[:DFd]
        end
        if haskey(expected, :SSn)
            if !isapprox(row.SSn, expected[:SSn], rtol = RTOL, nans = true)
                println(
                    "FAIL: $effect_name SSn: got $(row.SSn), expected $(expected[:SSn]), diff=$(abs(row.SSn - expected[:SSn]))",
                )
            end
            @test isapprox(row.SSn, expected[:SSn], rtol = RTOL, nans = true)
        end
        if haskey(expected, :SSd)
            if !isapprox(row.SSd, expected[:SSd], rtol = RTOL, nans = true)
                println(
                    "FAIL: $effect_name SSd: got $(row.SSd), expected $(expected[:SSd]), diff=$(abs(row.SSd - expected[:SSd]))",
                )
            end
            @test isapprox(row.SSd, expected[:SSd], rtol = RTOL, nans = true)
        end
        if haskey(expected, :F)
            if !isapprox(row.F, expected[:F], rtol = RTOL, nans = true)
                println(
                    "FAIL: $effect_name F: got $(row.F), expected $(expected[:F]), diff=$(abs(row.F - expected[:F]))",
                )
            end
            @test isapprox(row.F, expected[:F], rtol = RTOL, nans = true)
        end
        if haskey(expected, :p)
            if !isapprox(row.p, expected[:p], rtol = RTOL, nans = true)
                println(
                    "FAIL: $effect_name p: got $(row.p), expected $(expected[:p]), diff=$(abs(row.p - expected[:p]))",
                )
            end
            @test isapprox(row.p, expected[:p], rtol = RTOL, nans = true)
        end
    end
end
