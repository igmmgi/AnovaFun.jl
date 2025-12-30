
"""
    DesignInfo

Stores info about the ANOVA design.

# Fields
- `type::Symbol`: Design type. Options: `:between` (between-subjects only), `:within` (within-subjects/repeated measures only), or `:mixed` (combination of both)
- `between_factors::Vector{Symbol}`: Vector of between-subjects factor names
- `within_factors::Vector{Symbol}`: Vector of within-subjects (repeated measures) factor names
- `n_id::Int`: Number of unique subjects/participants in the design

# Examples
```julia
result = anova(data, :dv, :id, between=[:group])
design_type(result)  # Returns :between
between_factors(result)  # Returns [:group]
within_factors(result)  # Returns []
n_id(result)  # Returns number of subjects
```
"""
struct DesignInfo
    type::Symbol
    between_factors::Vector{Symbol}
    within_factors::Vector{Symbol}
    n_id::Int
end

# Simple factory functions for creating design info
between_design(factors::Vector{Symbol}, n::Int) = DesignInfo(:between, factors, Symbol[], n)
within_design(factors::Vector{Symbol}, n::Int) = DesignInfo(:within, Symbol[], factors, n)
mixed_design(between::Vector{Symbol}, within::Vector{Symbol}, n::Int) =
    DesignInfo(:mixed, between, within, n)

function _validate_factors(factors::AbstractVector{Symbol}, design_type::String)
    isempty(factors) &&
        throw(ArgumentError("$design_type design requires at least one factor"))
    length(factors) != length(unique(factors)) &&
        throw(ArgumentError("Duplicate factors not allowed: $(factors)"))
end

"""
    all_factors(design::DesignInfo)

Get all factors in canonical order (between factors first, then within factors).
This is a helper method to avoid repeating the `vcat` pattern throughout the codebase.

# Arguments
- `design::DesignInfo`: Design information

# Returns
A `Vector{Symbol}` containing all factors in order: between factors followed by within factors.
"""
all_factors(design::DesignInfo) = vcat(design.between_factors, design.within_factors)


"""
    AnovaResult

Results from an ANOVA analysis.

# Fields
- `data::DataFrame`: Original data used for analysis (in long format)
- `dv::Symbol`: Dependent variable column name
- `id::Symbol`: Subject/participant identifier column name
- `table::DataFrame`: ANOVA table with test statistics. Columns include: Effect, DFn, DFd, SSn, SSd, MSE, F, p, sig, and optionally ε (epsilon), η², η²ₚ, ω²
- `design::DesignInfo`: Design metadata containing type (`:between`, `:within`, or `:mixed`), factors, and number of subjects
- `model`: Fitted linear model (GLM.TableRegressionModel) for diagnostics. Use `model(result)` to access GLM functions like `residuals()`, `fitted()`, `coef()`, etc.

# Accessor Functions
Use these functions to extract information from an `AnovaResult`:
- `factors(result)`: Get all factors (between and within)
- `between_factors(result)`: Get between-subjects factors
- `within_factors(result)`: Get within-subjects factors
- `n_id(result)`: Get number of subjects
- `n_effects(result)`: Get number of effects (excluding Intercept)
- `design_type(result)`: Get design type (`:between`, `:within`, or `:mixed`)
- `data(result)`: Get original data
- `dv(result)`: Get dependent variable name
- `id(result)`: Get subject identifier name
- `model(result)`: Get fitted model

# Examples
```julia
result = anova(data, :dv, :id, within=[:time])
result.table  # Access ANOVA table
factors(result)  # Get all factors
design_type(result)  # Get design type
```
"""
struct AnovaResult
    data::DataFrame
    dv::Symbol
    id::Symbol
    table::DataFrame
    design::DesignInfo
    model::Any
end

# Accessor methods
"""
    factors(result::AnovaResult)

Get all factors in the design (both between and within).

# Arguments
- `result::AnovaResult`: ANOVA result object

# Returns
A `Vector{Symbol}` containing all factor names (between-subjects and within-subjects combined).

# Examples
```julia
result = anova(data, :dv, :id, between=[:group], within=[:time])
factors(result)  # Returns [:group, :time]
```
"""
factors(aov::AnovaResult) = all_factors(aov.design)

"""
    between_factors(result::AnovaResult)

Get between-subjects factors.

# Arguments
- `result::AnovaResult`: ANOVA result object

# Returns
A `Vector{Symbol}` containing between-subjects factor names.

# Examples
```julia
result = anova(data, :dv, :id, between=[:group])
between_factors(result)  # Returns [:group]
```
"""
between_factors(aov::AnovaResult) = aov.design.between_factors

"""
    within_factors(result::AnovaResult)

Get within-subjects (repeated measures) factors.

# Arguments
- `result::AnovaResult`: ANOVA result object

# Returns
A `Vector{Symbol}` containing within-subjects factor names.

# Examples
```julia
result = anova(data, :dv, :id, within=[:time])
within_factors(result)  # Returns [:time]
```
"""
within_factors(aov::AnovaResult) = aov.design.within_factors

"""
    n_id(result::AnovaResult)

Get number of subjects/participants in the design.

# Arguments
- `result::AnovaResult`: ANOVA result object

# Returns
An `Int` representing the number of unique subjects.

# Examples
```julia
result = anova(data, :dv, :id, within=[:time])
n_id(result)  # Returns number of subjects (e.g., 20)
```
"""
n_id(aov::AnovaResult) = aov.design.n_id

"""
    n_effects(result::AnovaResult)

Get number of effects in the ANOVA table (excluding Intercept).

# Arguments
- `result::AnovaResult`: ANOVA result object

# Returns
An `Int` representing the number of effects (main effects and interactions, excluding Intercept).

# Examples
```julia
result = anova(data, :dv, :id, between=[:group], within=[:time])
n_effects(result)  # Returns number of effects (e.g., 3 for group, time, group×time)
```
"""
n_effects(aov::AnovaResult) = count(row -> row.Effect != "Intercept", eachrow(aov.table))

"""
    design_type(result::AnovaResult)

Get the design type.

# Arguments
- `result::AnovaResult`: ANOVA result object

# Returns
A `Symbol` indicating the design type: `:between`, `:within`, or `:mixed`.

# Examples
```julia
result = anova(data, :dv, :id, between=[:group])
design_type(result)  # Returns :between

result = anova(data, :dv, :id, within=[:time])
design_type(result)  # Returns :within

result = anova(data, :dv, :id, between=[:group], within=[:time])
design_type(result)  # Returns :mixed
```
"""
design_type(aov::AnovaResult) = aov.design.type

"""
    data(result::AnovaResult)

Get the original data used for the ANOVA.

# Arguments
- `result::AnovaResult`: ANOVA result object

# Returns
The original `DataFrame` used for the analysis.

# Examples
```julia
result = anova(data, :dv, :id, within=[:time])
original_data = data(result)
```
"""
data(aov::AnovaResult) = aov.data

"""
    dv(result::AnovaResult)

Get the dependent variable name.

# Arguments
- `result::AnovaResult`: ANOVA result object

# Returns
A `Symbol` representing the dependent variable column name.

# Examples
```julia
result = anova(data, :dv, :id, within=[:time])
dv(result)  # Returns :dv
```
"""
dv(aov::AnovaResult) = aov.dv

"""
    id(result::AnovaResult)

Get the subject identifier name.

# Arguments
- `result::AnovaResult`: ANOVA result object

# Returns
A `Symbol` representing the subject identifier column name.

# Examples
```julia
result = anova(data, :dv, :id, within=[:time])
id(result)  # Returns :id
```
"""
id(aov::AnovaResult) = aov.id

# Model accessor methods
"""
    model(result::AnovaResult)

Get the fitted linear model (always available).

Use this to access GLM functionality directly, e.g.:
- `GLM.residuals(model(result))`
- `GLM.fitted(model(result))`
- `GLM.coef(model(result))`
- `GLM.vcov(model(result))`
- `GLM.stderror(model(result))`
- `GLM.r2(model(result))`
- `GLM.adjr2(model(result))`
"""
model(aov::AnovaResult) = aov.model

# Helper function to format factors with their levels
function _format_factors_with_levels(data::DataFrame, factors::Vector{Symbol})
    factor_strings = String[]
    for factor in factors
        n_levels = length(unique(skipmissing(data[!, factor])))
        push!(factor_strings, "$(factor) ($n_levels)")
    end
    return join(factor_strings, " × ")
end

# Pretty printing - dispatch on design type
function Base.show(io::IO, ::MIME"text/plain", r::AnovaResult)
    if r.design.type == :between
        println(io, "Between-Subjects ANOVA")
        factors_str = _format_factors_with_levels(r.data, between_factors(r))
        println(io, "  N subjects: ", n_id(r))
        println(io, "  Factors (levels): ", factors_str)
    elseif r.design.type == :within
        println(io, "Within-Subjects ANOVA")
        factors_str = _format_factors_with_levels(r.data, within_factors(r))
        println(io, "  N subjects: ", n_id(r))
        println(io, "  Factors (levels): ", factors_str)
    else # :mixed
        println(io, "Mixed-Design ANOVA")
        between_str = _format_factors_with_levels(r.data, between_factors(r))
        within_str = _format_factors_with_levels(r.data, within_factors(r))
        println(io, "  N subjects: ", n_id(r))
        println(io, "  Between (levels): ", between_str)
        println(io, "  Within (levels): ", within_str)
    end
    println(io)
    anova_table(r)
end

# Compact printing (for arrays, etc.)
function Base.show(io::IO, r::AnovaResult)
    if r.design.type == :between
        print(io, "Anova Between(", join(string.(between_factors(r)), "×"), ")")
    elseif r.design.type == :within
        print(io, "Anova Within(", join(string.(within_factors(r)), "×"), ")")
    else # :mixed
        print(io, "Anova Between(", join(string.(between_factors(r)), "×"), ")& ")
        print(io, "Anova Within(", join(string.(within_factors(r)), "×"), ")")
    end
end

"""
    EmmeansResult

Results from estimated marginal means computation.

# Fields
- `means::DataFrame`: Marginal means table with columns:
  - `Effect`: Name of the effect (e.g., "time", "time × condition")
  - `Level`: Level combination (e.g., "T1" or "T1, Condition1")
  - `N`: Number of subjects contributing to this mean
  - `Mean`: Estimated marginal mean
  - `SD`: Standard deviation
  - `SE`: Standard error of the mean
  - `Lower`: Lower bound of confidence interval
  - `Upper`: Upper bound of confidence interval
- `anova::AnovaResult`: The original ANOVA result object used to compute the means
- `level::Float64`: Confidence level used for intervals (e.g., 0.95 for 95% CI)

Note: The original data can be accessed via `result.anova.data`.

# Examples
```julia
result = anova(data, :dv, :id, within=[:time])
em = emmeans(result)
em.means  # Access marginal means table
em.level  # Get confidence level (e.g., 0.95)
em.anova  # Access original ANOVA result
```
"""
struct EmmeansResult
    means::DataFrame
    anova::AnovaResult
    level::Float64
end

# Custom show method for EmmeansResult
Base.show(io::IO, ::MIME"text/plain", em::EmmeansResult) = emmeans_table(em);

# Compact printing (for arrays, etc.)
Base.show(io::IO, em::EmmeansResult) = print(io, "EmmeansResult (level = $(em.level))")

"""
    PairwiseResult

Results from pairwise comparisons computation.

# Fields
- `table::DataFrame`: Pairwise comparisons table with columns:
  - `Effect`: Name of the effect being compared
  - `Contrast`: Description of the comparison (e.g., "Level1 - Level2")
  - `Estimate`: Mean difference
  - `SE`: Standard error of the difference
  - `df`: Degrees of freedom
  - `t`: t-statistic
  - `p`: Unadjusted p-value
  - `p_adj`: Adjusted p-value (if adjustment method specified)
  - `Lower`: Lower bound of confidence interval
  - `Upper`: Upper bound of confidence interval

# Examples
```julia
result = anova(data, :dv, :id, within=[:time])
em = emmeans(result)
pw = pairwise(em)
pw.table  # Access pairwise comparisons table
```
"""
struct PairwiseResult
    table::DataFrame
end

# Custom show method for PairwiseResult
Base.show(io::IO, ::MIME"text/plain", pw::PairwiseResult) = pairwise_table(pw)

# Compact printing (for arrays, etc.)
Base.show(io::IO, pw::PairwiseResult) = print(io, "PairwiseResult")


"""
    PowerResult

Results from a power analysis.

# Fields
- `power::DataFrame`: Power estimates for each effect with columns: n, Effect, Power, EffectSize
- `between::Union{Dict{Symbol, Vector{String}}, Nothing}`: Between-subjects factors and their levels
- `within::Union{Dict{Symbol, Vector{String}}, Nothing}`: Within-subjects factors and their levels
- `n_sims::Union{Int, Nothing}`: Number of simulations (if simulation method)
- `alpha::Float64`: Significance level used

# Examples
```julia
result = power_analysis(40,
                        between=Dict(:voice => [:human, :robot]),
                        within=Dict(:emotion => [:cheerful, :sad]),
                        mu=[1.03, 1.41, 0.98, 1.01],
                        sd=1.03,
                        r=0.8)
result.power        # Access power estimates and effect sizes DataFrame
result.power.n      # Access sample size from the DataFrame
result.between      # Access between-subjects factors
result.within       # Access within-subjects factors
```
"""
struct PowerResult
    between::Union{Dict{Symbol, Vector{String}}, Nothing}
    within::Union{Dict{Symbol, Vector{String}}, Nothing}
    power::DataFrame
    n_sims::Union{Int, Nothing}
    alpha::Float64
end

# Custom show method for PowerResult
function Base.show(io::IO, ::MIME"text/plain", pr::PowerResult)
    println(io, "Power Analysis Results")
    println(io, "  N: $(first(pr.power.n))")
    
    # Display design information
    if !isnothing(pr.between) && !isempty(pr.between)
        between_str = join(["$(k)($(join(v, ", ")))" for (k, v) in pr.between], ", ")
        println(io, "  Between: $between_str")
    end
    if !isnothing(pr.within) && !isempty(pr.within)
        within_str = join(["$(k)($(join(v, ", ")))" for (k, v) in pr.within], ", ")
        println(io, "  Within: $within_str")
    end
    if !isnothing(pr.n_sims)
        println(io, "  Simulations: $(pr.n_sims)")
    end
    println(io, "  Alpha: $(pr.alpha)")
    println(io)
    PrettyTables.pretty_table(io, pr.power)
end

Base.show(io::IO, pr::PowerResult) = print(io, "PowerResult")

"""
    SampleSizeResult

Results from a sample size calculation.

# Fields
- `power::DataFrame`: Power estimates for each effect at the recommended sample size (columns: n, Effect, Power, EffectSize)
- `results::DataFrame`: DataFrame with columns `n` and one column per effect/interaction showing power values for each tested sample size

# Examples
```julia
result = sample_size(80,
                     within=Dict(:factor1 => [1, 2], :factor2 => [1, 2]),
                     mu=[1.0, 1.0, 1.0, 2.0],
                     sd=1.0,
                     r=0.5)
result.power        # Recommended sample size and power for each effect
result.results      # Power for all tested sample sizes
```
"""
struct SampleSizeResult
    power::DataFrame
    results::DataFrame
    target_power::Float64
end

# Custom show method for SampleSizeResult
function Base.show(io::IO, ::MIME"text/plain", sr::SampleSizeResult)
    recommended_n = first(sr.power.n)
    println(io, "Sample Size Calculation Results")
    println(io, "  Recommended N: $recommended_n")
    println(io)
    println(io, "Power at recommended N:")
    PrettyTables.pretty_table(io, sr.power)
end

Base.show(io::IO, sr::SampleSizeResult) = print(io, "SampleSizeResult(n=$(first(sr.power.n)))")
