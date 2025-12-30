"""
    sample_size(; target_power=80, within=nothing, between=nothing, mu, sd, r=nothing, method=:binary, n_sims=1000, alpha=0.05, min_n=5, max_n=500, step=1, n_anchors=10)

Estimate the required sample size to achieve a target power level using simulation.

# Arguments
- `target_power::Real`: Target power level (e.g., 80 for 80% power) on 0-100 scale (default: 80)
- `within::Union{Dict{Symbol, Vector}, Nothing}`: Dictionary mapping within-subjects factor names to level labels
- `between::Union{Dict{Symbol, Vector}, Nothing}`: Dictionary mapping between-subjects factor names to level labels
- `mu::Union{Real, Vector{<:Real}}`: Cell means. Single value for all cells, or vector (one per cell, matching cell order)
- `sd::Union{Real, Vector{<:Real}}`: Standard deviation. Single value for all cells, or vector (one per cell, matching `mu` order)
- `r::Union{Real, Vector{<:Real}, Nothing}`: Correlation for within-subjects factors (default: nothing)
- `method::Symbol`: Search method. Options:
  - `:binary` (default): Binary search with independent per-effect search and anchor points
  - `:sequential`: Sequential search from min_n to max_n (slower, dense results for plotting)
- `step::Int`: Step size for sequential search (default: 1). Use larger values (e.g., 5-10) for faster sequential search
- `n_anchors::Int`: Number of evenly-spaced anchor points to test initially (binary method only, default: 10). Higher values give smoother plots but take longer
- `n_sims::Int`: Number of simulations per sample size tested (default: 1000)
- `alpha::Float64`: Significance level (default: 0.05)
- `min_n::Int`: Minimum sample size to test (default: 5)
  - For between-subjects designs: minimum number of subjects **per group**
  - For within-subjects designs: minimum total number of subjects
  - For mixed designs: minimum number of subjects **per between-subjects group**
- `max_n::Int`: Maximum sample size to test (default: 500)
  - For between-subjects designs: maximum number of subjects **per group**
  - For within-subjects designs: maximum total number of subjects
  - For mixed designs: maximum number of subjects **per between-subjects group**


# Returns
A `SampleSizeResult` object containing:
- `power::DataFrame`: Power estimates for each effect at the recommended sample size (columns: n, Effect, Power, EffectSize)
  - `n` represents per-group sample size for between-subjects designs, total sample size for within-subjects designs
- `results::DataFrame`: DataFrame with columns `n` and one column per effect/interaction showing power values for each tested sample size
  - `n` represents per-group sample size for between-subjects designs, total sample size for within-subjects designs

# Examples
```julia
# Within-subjects design
result = sample_size(target_power=80,  # 80% power
                     within=Dict(:factor1 => [1, 2], :factor2 => [1, 2]),
                     mu=[1.0, 1.0, 1.0, 2.0], 
                     sd=1.0, 
                     r=0.5, 
                     n_sims=100,
                     method=:binary)

# Sequential search with larger step size (faster, coarser)
result = sample_size(target_power=80,  # 80% power
                     within=Dict(:factor1 => [1, 2], :factor2 => [1, 2]),
                     mu=[1.0, 1.0, 1.0, 2.0], 
                     sd=1.0, 
                     r=0.5,
                     method=:sequential, 
                     min_n=10, 
                     max_n=100,
                     step=5)  # Test every 5th sample size for speed
```
"""
function sample_size(;
    target_power::Real = 80,
    within::Union{Dict{Symbol, <:Vector}, Nothing} = nothing,
    between::Union{Dict{Symbol, <:Vector}, Nothing} = nothing,
    mu::Union{Real, Vector{<:Real}},
    sd::Union{Real, Vector{<:Real}},
    r::Union{Real, Vector{<:Real}, Nothing} = nothing,
    method::Symbol = :binary,
    n_sims::Int = 1000,
    alpha::Float64 = 0.05,
    min_n::Int = 5,
    max_n::Int = 500,
    step::Int = 1,
    n_anchors::Int = 10,
)
    
    (target_power <= 0 || target_power >= 100) && throw(ArgumentError("invalid target_power"))
    method ∉ [:binary, :sequential] && throw(ArgumentError("Unknown method: $method"))
    
    # Extract factor names and convert labels to strings
    between_factors, within_factors, labelnames, factor_levels = _process_factors(within, between)
    
    mu_vec, sd_vec, r_vec, _ = _normalize_sim_inputs(
        between_factors,
        within_factors,
        mu,
        sd,
        r,
        factor_levels,
        labelnames,
    )

    if method == :binary
        return _sample_size_binary(between_factors, within_factors, mu_vec, sd_vec, r_vec, labelnames, target_power, n_sims, alpha, min_n, max_n, n_anchors, factor_levels)
    elseif method == :sequential
        return _sample_size_sequential(between_factors, within_factors, mu_vec, sd_vec, r_vec, labelnames, target_power, n_sims, alpha, min_n, max_n, step, factor_levels)
    end
end

"""
    _sort_effects_by_order(power_df)

Sort effects: main effects first (single factor), then interactions (multiple factors).
"""
function _sort_effects_by_order(power_df::DataFrame)
    sort(power_df, :Effect, by=effect -> (count("×", effect) + 1, effect))
end

"""
    _build_power_row(n, sorted_power_df)

Build a row for the results DataFrame.
Returns a Dict with n and effect power values.
"""
function _build_power_row(n::Int, sorted_power_df::DataFrame)
    effect_cols = [Symbol(row.Effect) for row in eachrow(sorted_power_df)]
    power_values = [row.Power for row in eachrow(sorted_power_df)]
    row_data = Dict{Symbol, Union{Int, Float64}}(:n => n)
    for (effect, power) in zip(effect_cols, power_values)
        row_data[effect] = power
    end
    return row_data
end

"""
    _sample_size_binary(between_factors, within_factors, mu_vec, sd_vec, r_vec, labelnames, target_power, n_sims, alpha, min_n, max_n, n_anchors, factor_levels)

Binary search for sample size with independent search per effect.
Searches for the n needed for each effect separately, but caches all results
so the final DataFrame includes power values for all effects at all tested n values.
"""
function _sample_size_binary(
    between_factors,
    within_factors,
    mu_vec::Vector{Float64},
    sd_vec::Vector{Float64},
    r_vec::Union{Vector{Float64}, Nothing},
    labelnames,
    target_power::Real,
    n_sims::Int,
    alpha::Float64,
    min_n::Int,
    max_n::Int,
    n_anchors::Int,
    factor_levels::Dict{Symbol, Int},
)
    between_dict = isempty(between_factors) ? nothing : Dict(factor => labelnames[factor] for factor in between_factors)
    within_dict = isempty(within_factors) ? nothing : Dict(factor => labelnames[factor] for factor in within_factors)
    
    # Cache power results by n (per-group n) to avoid re-running simulations
    power_cache = Dict{Int, PowerResult}()
    
    # Helper function to run or retrieve simulation
    # n is per-group n, convert to total n for simulation
    function get_power_at_n(n_per_group::Int)
        if !haskey(power_cache, n_per_group)
            total_n = _calculate_total_n(n_per_group, between_factors, factor_levels)
            power_result = _power_simulation(total_n, between_factors, within_factors, mu_vec, sd_vec, r_vec, n_sims, alpha, false, between_dict, within_dict, labelnames, factor_levels)
            # Update power_df to show per-group n instead of total n
            power_result.power.n .= n_per_group
            power_cache[n_per_group] = power_result
        end
        return power_cache[n_per_group]
    end
    
    # PHASE 1: "anchors" for smoother plots
    step = div((max_n - min_n), n_anchors - 1)  
    anchor_points = [min_n + i * step for i in 0:(n_anchors-1)]
    anchor_points[end] = max_n
    anchor_points = unique(anchor_points)
    
    @info "Pre-search: Testing $(length(anchor_points)) anchor points (n_sims=$n_sims)"
    for test_n_per_group in anchor_points
        @info "  Anchor point: n=$test_n_per_group (per group)"
        get_power_at_n(test_n_per_group)
    end
    
    # Get effect names from first simulation
    first_result = power_cache[anchor_points[1]]
    effect_names = first_result.power.Effect
    
    @info "Found $(length(effect_names)) effects: $(effect_names)"
    
    # PHASE 2: binary search peer effect
    effect_n_solutions = Dict{String, Union{Int, Nothing}}()
    for effect in effect_names
        @info "Binary search for effect: $effect"
        
        # Use anchor points to find better low/high
        n_low, n_high = min_n, max_n
        for i in 1:(length(anchor_points)-1)
            n1, n2 = anchor_points[i], anchor_points[i+1]
            power1 = power_cache[n1].power[power_cache[n1].power.Effect .== effect, :Power][1]
            power2 = power_cache[n2].power[power_cache[n2].power.Effect .== effect, :Power][1]
            
            # Check if this effect crosses target in this interval
            if power1 < target_power && power2 >= target_power
                n_low = n1
                n_high = n2
                @info "  Anchor points bracket crossing: [$n_low, $n_high] (power: $power1% → $power2%)"
                break
            elseif power2 < target_power
                n_low = n2
            end
        end
        
        # If effect already meets target at min anchor, search below (but can't go below min_n)
        if power_cache[anchor_points[1]].power[power_cache[anchor_points[1]].power.Effect .== effect, :Power][1] >= target_power
            n_high = anchor_points[1]  # This is min_n
            n_low = 0  # Set to 0 to allow binary search to converge to min_n
            @info "  Effect already meets target at min anchor (n=$n_high), searching below"
        end
        
        # If effect never meets target in anchors, search up to max
        if n_low >= n_high || n_high == max_n
            @info "  No crossing found in anchors, will search full range or use max"
        end
        
        effect_best_n = nothing
        # Check if anchors already bracketed tightly enough (adjacent n values)
        # If so, skip binary search and check if n_high meets target
        if n_high - n_low <= 1
            @info "  Anchor points already bracket solution tightly, skipping binary search"
            power_at_high = power_cache[n_high].power[power_cache[n_high].power.Effect .== effect, :Power][1]
            if power_at_high >= target_power
                effect_best_n = n_high
            end
        end
        
        while n_high - n_low > 1

            @info "  Binary search: n_low=$n_low, n_high=$n_high"
            test_n = div(n_low + n_high, 2)
            
            # Get or compute power at this n
            power_result = get_power_at_n(test_n)
            
            # Get power for THIS specific effect
            effect_row = power_result.power[power_result.power.Effect .== effect, :]
            effect_power = effect_row.Power[1]
            
            if effect_power >= target_power # This effect meets target, try smaller n
                n_high = test_n
                if isnothing(effect_best_n) || test_n < effect_best_n
                    effect_best_n = test_n
                end
            else # This effect doesn't meet target yet, need larger n
                n_low = test_n
            end
        end
        
        effect_n_solutions[effect] = effect_best_n
        
        if !isnothing(effect_best_n)
            @info "  → $effect: Minimum n = $effect_best_n"
        else
            @info "  → $effect: Did not achieve target power"
        end
    end
    
    # PHASE 3: What is recommended N?
    valid_solutions = [n for n in values(effect_n_solutions) if !isnothing(n)]
    
    if isempty(valid_solutions) # No effect reached target power
        @minimal_warning "Could not achieve target power $(target_power)% for any effect with n up to $(max_n)."
        best_n = max_n
    else
        best_n = maximum(valid_solutions)
        @info "Recommended n = $best_n (ensures ALL effects meet target power)"
    end
    
    # Build results 
    results = DataFrame()
    for test_n in sort(collect(keys(power_cache)))
        power_result = power_cache[test_n]
        sorted_power = _sort_effects_by_order(power_result.power)
        row_data = _build_power_row(test_n, sorted_power)
        
        if isempty(results)
            results = DataFrame(row_data)
        else
            push!(results, row_data)
        end
    end
    
    # Get the power DataFrame for the recommended n
    best_power_df = power_cache[best_n].power
    
    # Reorder columns: n first, then main effects, then interactions
    if !isempty(results)
        effect_cols = [col for col in propertynames(results) if col != :n]
        main_effects = [col for col in effect_cols if !occursin("×", string(col))]
        interactions = [col for col in effect_cols if occursin("×", string(col))]
        ordered_cols = [:n, sort(main_effects)..., sort(interactions)...]
        results = results[:, ordered_cols]
    end
    
    return SampleSizeResult(best_power_df, results, Float64(target_power))
end


"""
    _sample_size_sequential(between_factors, within_factors, mu_vec, sd_vec, r_vec, labelnames, target_power, n_sims, alpha, min_n, max_n, step, factor_levels)

Sequential search for sample size from min_n to max_n with configurable step size 

For each sample size from min_n to max_n:
1. Rebuilds design parameters with that sample size
2. Runs power analysis
3. Records the power estimate
4. Returns the first sample size that achieves target power
"""
function _sample_size_sequential(
    between_factors,
    within_factors,
    mu_vec::Vector{Float64},
    sd_vec::Vector{Float64},
    r_vec::Union{Vector{Float64}, Nothing},
    labelnames,
    target_power::Real,
    n_sims::Int,
    alpha::Float64,
    min_n::Int,
    max_n::Int,
    step::Int,
    factor_levels::Dict{Symbol, Int},
)
    results = DataFrame()  # Will be initialized with n and effect columns
    best_n = nothing
    best_power_df = nothing
    
    between_dict = isempty(between_factors) ? nothing : Dict(factor => labelnames[factor] for factor in between_factors)
    within_dict = isempty(within_factors) ? nothing : Dict(factor => labelnames[factor] for factor in within_factors)
    
    # Test each sample size from min_n to max_n (with early stopping)
    # test_n is per-group n, convert to total n for simulation
    last_power_result = nothing  # Cache last result to avoid re-running
    for test_n_per_group in min_n:step:max_n
        @info "Sequential search: Testing sample size $test_n_per_group (per group, step=$step)"
        
        # Calculate power (convert per-group n to total n)
        total_n = _calculate_total_n(test_n_per_group, between_factors, factor_levels)
        power_result = _power_simulation(total_n, between_factors, within_factors, mu_vec, sd_vec, r_vec, n_sims, alpha, false, between_dict, within_dict, labelnames, factor_levels)
        # Update power_df to show per-group n instead of total n
        power_result.power.n .= test_n_per_group
        last_power_result = power_result  # Cache for potential reuse
        
        # Sort effects: main effects first, then interactions
        sorted_power = _sort_effects_by_order(power_result.power)
        
        # Build row (using per-group n)
        row_data = _build_power_row(test_n_per_group, sorted_power)
        
        # Initialize results DataFrame structure on first iteration
        if isempty(results)
            results = DataFrame(row_data)
        else
            push!(results, row_data)
        end
        
        # Track the first sample size where all effects achieve target power
        if isnothing(best_n) && all(power_result.power.Power .>= target_power)
            best_n = test_n_per_group
            best_power_df = power_result.power
            break  
        end
    end
    
    # If no sample size achieved target power, use the maximum tested
    if isnothing(best_n)
        @minimal_warning "Could not achieve target power $(target_power)% with n up to $(max_n)."
        best_n = max_n
        
        # Use cached result from last iteration (max_n) instead of re-running
        # Ensure it shows per-group n
        if !isnothing(last_power_result)
            last_power_result.power.n .= max_n
            best_power_df = last_power_result.power
        end
    end
    
    # Reorder columns: n first, then main effects, then interactions
    if !isempty(results)
        effect_cols = [col for col in propertynames(results) if col != :n]
        # Sort effect columns: main effects first (no ×), then interactions
        main_effects = [col for col in effect_cols if !occursin("×", string(col))]
        interactions = [col for col in effect_cols if occursin("×", string(col))]
        ordered_cols = [:n, sort(main_effects)..., sort(interactions)...]
        results = results[:, ordered_cols]
    end
    
    return SampleSizeResult(best_power_df, results, Float64(target_power))
end
