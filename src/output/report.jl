"""
    p(p::Real; format::Symbol=:markdown)
    p(result::AnovaResult, effect::String; format::Symbol=:markdown)

Format a p-value string according to APA style.
Supported formats: :markdown, :latex, :text.
"""
function p(p::Real; format::Symbol = :markdown)
    symbols = _get_symbols(format)

    p < 0.001 && return "$(symbols.p) < .001"

    str = @sprintf("%.3f", p)
    # Remove leading "0" for APA style (e.g., "0.012" -> ".012")
    if startswith(str, "0.")
        str = str[2:end]  # Skip "0" (keep the decimal point)
    end

    return "$(symbols.p) = $str"
end

function p(result::AnovaResult, effect::String; format::Symbol = :markdown)
    row = _get_anova_row(result, effect)
    isnothing(row) && throw(ArgumentError("Effect $effect not found in ANOVA table"))
    return p(row.p; format = format)
end

"""
    f(result::AnovaResult, effect::String; format::Symbol=:markdown)

Format F-statistic string according to APA style.
"""
function f(result::AnovaResult, effect::String; format::Symbol = :markdown)
    row = _get_anova_row(result, effect)
    isnothing(row) && throw(ArgumentError("Effect $effect not found in ANOVA table"))

    # Format degrees of freedom (might be non-integer if corrected)
    df1, df2, F_val = row.DFn, row.DFd, row.F
    df1_str = isinteger(df1) ? string(Int(df1)) : @sprintf("%.2f", df1)
    df2_str = isinteger(df2) ? string(Int(df2)) : @sprintf("%.2f", df2)
    F_str = @sprintf("%.2f", F_val)

    symbols = _get_symbols(format)
    return "$(symbols.f)($df1_str, $df2_str) = $F_str"
end

"""
    sphericity(result::AnovaResult, effect::String; format::Symbol=:markdown)

Format sphericity epsilon (ε) string for an effect.

Returns an empty string if the effect does not have sphericity correction applied (ε = 1.0 or missing).

# Arguments
- `result::AnovaResult`: ANOVA result object
- `effect::String`: Name of the effect from the ANOVA table
- `format::Symbol`: Output format. Options: `:markdown` (default), `:latex`, `:text`

# Returns
A formatted string with the epsilon value, or an empty string if no correction was applied.

# Examples
```julia
result = anova(data, :dv, :subject, within=[:time], correction=:GG)
sphericity(result, "time", format=:markdown)  # Returns "*ε* = 0.85" (example)
```
"""
function sphericity(result::AnovaResult, effect::String; format::Symbol = :markdown)
    row = _get_anova_row(result, effect)
    isnothing(row) && return ""
    hasproperty(row, :ε) || return ""

    symbols = _get_symbols(format)
    return "$(symbols.epsilon) = $(@sprintf("%.2f", row.ε))"
end

"""
    fstat(result::AnovaResult, effect::String; format::Symbol=:markdown)

Return full APA formatted statistics string for an ANOVA effect.

Combines F-statistic, p-value, effect size, and sphericity correction (if applicable) into a single formatted string.

# Arguments
- `result::AnovaResult`: ANOVA result object
- `effect::String`: Name of the effect from the ANOVA table
- `format::Symbol`: Output format. Options: `:markdown` (default), `:latex`, `:text`

# Returns
A formatted string containing F-statistic, p-value, effect size, and sphericity correction (if applicable), separated by commas.

# Examples
```julia
result = anova(data, :dv, :subject, within=[:time], correction=:GG)
fstat(result, "time", format=:markdown)
# Returns: "*F*(2, 18) = 5.43, *p* = .012, *η²ₚ* = 0.38, *ε* = 0.85" (example)
```
"""
function fstat(result::AnovaResult, effect::String; format::Symbol = :markdown)
    row = _get_anova_row(result, effect)
    isnothing(row) && throw(ArgumentError("Effect $effect not found in ANOVA table"))

    # F-statistic
    parts = String[]
    push!(parts, f(result, effect; format = format))

    # p-value
    push!(parts, p(row.p; format = format))

    # Effect size
    es_label, es_val = "", NaN

    symbols = _get_symbols(format)
    if hasproperty(row, :pes)
        es_val = row.pes
        es_label = symbols.eta_p2
    elseif hasproperty(row, :ges)
        es_val = row.ges
        es_label = symbols.eta_g2
    elseif hasproperty(row, :eta2)
        es_val = row.eta2
        es_label = symbols.eta2
    elseif hasproperty(row, :omega2)
        es_val = row.omega2
        es_label = symbols.omega2
    elseif hasproperty(row, :SSn) && hasproperty(row, :SSd)
        es_val = row.SSn / (row.SSn + row.SSd)
        es_label = symbols.eta_p2
    end

    if !isnan(es_val) && !isempty(es_label)
        push!(parts, "$es_label = $(@sprintf("%.2f", es_val))")
    end

    # Sphericity
    sph_str = sphericity(result, effect; format = format)
    if !isempty(sph_str)
        push!(parts, sph_str)
    end

    return join(parts, ", ")
end

"""
    tstat(result; format::Symbol=:markdown)

Return APA-style formatted statistics string for a t-test result.

Accepts a named tuple like the outputs of `paired_ttest` or `independent_ttest`, containing:
- `df`, `t`, `p`, and either `dz` (paired) or `d` (independent).

Examples:
```julia
res = paired_ttest(x, y)
tstat(res)  # "*t*(4) = -3.92, *p* = .017, dz = 1.75"
```
"""
function tstat(result; format::Symbol = :markdown)
    symbols = _get_symbols(format)

    df = getproperty(result, :df)
    t_val = getproperty(result, :t)
    p_val = getproperty(result, :p)

    df_str = if isnan(df)
        "NaN"
    elseif isinteger(df)
        string(Int(df))
    else
        @sprintf("%.2f", df)
    end

    t_str = isnan(t_val) ? "NaN" : @sprintf("%.2f", t_val)

    parts = String["$(symbols.t)($df_str) = $t_str"]

    # p-value (reuse p() formatting when finite)
    if isnan(p_val)
        push!(parts, "$(symbols.p) = NaN")
    else
        push!(parts, p(p_val; format = format))
    end

    # Effect size (paired: dz, independent: d)
    if hasproperty(result, :dz) && isfinite(getproperty(result, :dz))
        push!(parts, "$(symbols.dz) = $(@sprintf("%.2f", getproperty(result, :dz)))")
    elseif hasproperty(result, :d) && isfinite(getproperty(result, :d))
        push!(parts, "$(symbols.d) = $(@sprintf("%.2f", getproperty(result, :d)))")
    end

    return join(parts, ", ")
end

"""
    m(result::EmmeansResult, effect::String, level::String; unit::String="", format::Symbol=:markdown)

Format marginal mean string according to APA style.

# Arguments
- `result::EmmeansResult`: Emmeans result object
- `effect::String`: Name of the effect
- `level::String`: Level of the effect (e.g., "Level1" or "Level1, Level2" for interactions)
- `unit::String`: Optional unit to append to the mean value (default: `""`)
- `format::Symbol`: Output format. Options: `:markdown` (default), `:latex`, `:text`

# Returns
A formatted string with the mean value (e.g., "*M* = 25.43" in markdown format).

# Examples
```julia
result = anova(data, :dv, :id, within=[:time])
em = emmeans(result)
m(em, "time", "T1")             # Returns "*M* = 25.43"
m(em, "time", "T1", unit="ms")  # Returns "*M* = 25.43 ms"
```
"""
function m(
    result::EmmeansResult,
    effect::String,
    level::String;
    unit::String = "",
    format::Symbol = :markdown,
)
    row = _get_emmeans_row(result, effect, level)
    isnothing(row) && throw(ArgumentError("Effect $effect level $level not found!"))

    symbols = _get_symbols(format)
    return "$(symbols.m) = $(@sprintf("%.2f", row.Mean))$unit"
end

"""
    ci(lower::Real, upper::Real; format::Symbol=:markdown)
    ci(result::EmmeansResult, effect::String, level::String; format::Symbol=:markdown)

Format confidence interval string according to APA style.

# Arguments
- `lower::Real`: Lower bound of the confidence interval (for direct call)
- `upper::Real`: Upper bound of the confidence interval (for direct call)
- `result::EmmeansResult`: Emmeans result object (for method with result)
- `effect::String`: Name of the effect (for method with result)
- `level::String`: Level of the effect (for method with result)
- `format::Symbol`: Output format. Options: `:markdown` (default), `:latex`, `:text`

# Returns
A formatted string with the confidence interval (e.g., "*95% CI* [20.15, 30.71]" in markdown format).

# Examples
```julia
ci(20.15, 30.71)  # Returns "*95% CI* [20.15, 30.71]"

# From emmeans result
result = anova(data, :dv, :id, within=[:time])
em = emmeans(result)
ci(em, "time", "T1")  # Returns "*95% CI* [20.15, 30.71]"
```
"""
function ci(lower::Real, upper::Real; format::Symbol = :markdown)
    symbols = _get_symbols(format)
    return "$(symbols.ci_prefix) [$(@sprintf("%.2f", lower)), $(@sprintf("%.2f", upper))]"
end

function ci(
    result::EmmeansResult,
    effect::String,
    level::String;
    format::Symbol = :markdown,
)
    row = _get_emmeans_row(result, effect, level)
    isnothing(row) && throw(ArgumentError("Effect $effect level $level not found!"))
    if !hasproperty(row, :Lower) || !hasproperty(row, :Upper)
        throw(ArgumentError("CI columns not found!"))
    end
    return ci(row.Lower, row.Upper; format = format)
end

"""
    m_ci(result::EmmeansResult, effect::String, level::String; unit::String="", format::Symbol=:markdown)

Format marginal mean with confidence interval string according to APA style.

This is a convenience function that combines `m()` and `ci()` into a single formatted string.

# Arguments
- `result::EmmeansResult`: Emmeans result object
- `effect::String`: Name of the effect
- `level::String`: Level of the effect (e.g., "Level1" or "Level1, Level2" for interactions)
- `unit::String`: Optional unit to append to the mean value (default: `""`)
- `format::Symbol`: Output format. Options: `:markdown` (default), `:latex`, `:text`

# Returns
A formatted string combining mean and confidence interval (e.g., "*M* = 25.43, *95% CI* [20.15, 30.71]" in markdown format).

# Examples
```julia
result = anova(data, :dv, :id, within=[:time])
em = emmeans(result)
m_ci(em, "time", "T1")  # Returns "*M* = 25.43, *95% CI* [20.15, 30.71]" 
```
"""
function m_ci(
    result::EmmeansResult,
    effect::String,
    level::String;
    unit::String = "",
    format::Symbol = :markdown,
)
    row = _get_emmeans_row(result, effect, level)
    isnothing(row) &&
        throw(ArgumentError("Effect $effect level $level not found in Emmeans table"))

    parts = String[]
    push!(parts, m(result, effect, level; unit = unit, format = format))

    if hasproperty(row, :Lower) && hasproperty(row, :Upper)
        push!(parts, ci(row.Lower, row.Upper; format = format))
    end

    return join(parts, ", ")
end


# Helper to get format-specific symbols
function _get_symbols(format::Symbol)

    if format ∉ [:markdown, :latex, :text]
        throw(ArgumentError("Supported formats: :markdown, :latex, :text."))
    end

    if format == :markdown
        return (
            p = "*p*",
            f = "*F*",
            t = "*t*",
            m = "*M*",
            ci_prefix = "*95% CI*",
            epsilon = "\$\\epsilon\$",
            eta_p2 = "\$\\eta_p^2\$",
            eta_g2 = "\$\\eta_G^2\$",
            eta2 = "\$\\eta^2\$",
            omega2 = "\$\\omega^2\$",
            d = "*d*",
            dz = "\$d_z\$",
        )
    elseif format == :latex
        return (
            p = "\\textit{p}",
            f = "\\textit{F}",
            t = "\\textit{t}",
            m = "\\textit{M}",
            ci_prefix = "95\\% CI",
            epsilon = "\$\\epsilon\$",
            eta_p2 = "\$\\eta_p^2\$",
            eta_g2 = "\$\\eta_G^2\$",
            eta2 = "\$\\eta^2\$",
            omega2 = "\$\\omega^2\$",
            d = "\\textit{d}",
            dz = "\$d_z\$",
        )
    else # format == :text
        return (
            p = "p",
            f = "F",
            t = "t",
            m = "M",
            ci_prefix = "95% CI",
            epsilon = "epsilon",
            eta_p2 = "eta_p^2",
            eta_g2 = "eta_G^2",
            eta2 = "eta^2",
            omega2 = "omega^2",
            d = "d",
            dz = "dz",
        )
    end
end

function _get_anova_row(result::AnovaResult, effect::String)
    idx = findfirst(==(effect), result.table.Effect)
    isnothing(idx) && return nothing
    return result.table[idx, :]
end

function _get_emmeans_row(result::EmmeansResult, effect::String, level::String)
    matching_rows = filter(row -> row.Effect == effect && row.Level == level, result.means)
    isempty(matching_rows) && return nothing
    return first(matching_rows)
end
