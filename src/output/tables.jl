"""
    anova_table(result::AnovaResult; backend=:text, include_intercept=false, include_ss=false, include_mse=false, include_es=true, include_sig=true, title="ANOVA Table", io=stdout)

Print an ANOVA table using PrettyTables.

# Arguments
- `result::AnovaResult`: An `AnovaResult` object
- `backend::Symbol`: Output format. Options: `:markdown`, `:latex`, `:text` (default: `:text`)
- `include_intercept::Bool`: Whether to include the Intercept row (default: `false`)
- `include_ss::Bool`: Whether to include sum of squares columns (default: `false`)
- `include_mse::Bool`: Whether to include MSE column (default: `false`)
- `include_es::Bool`: Whether to include effect size columns (default: `true`)
- `include_sig::Bool`: Whether to include significance column (default: `true`)
- `title::String`: Table title (default: `"ANOVA Table"`)
- `io::IO`: Output stream (default: `stdout`)

# Returns
Nothing (prints to `io`)

# Examples
```julia
result = anova(data, :dv, :id, within=[:time])
anova_table(result, backend=:markdown)
anova_table(result, backend=:latex)
anova_table(result, backend=:text)

# Minimal table
anova_table(result, include_ss=false, include_mse=false, include_es=false)
```
"""
function anova_table(
    result::AnovaResult;
    backend::Symbol = :text,
    include_intercept::Bool = false,
    include_ss::Bool = false,
    include_mse::Bool = false,
    include_es::Bool = true,
    include_sig::Bool = true,
    title::String = "ANOVA Table",
    io::IO = stdout,
)

    backends = [:markdown, :latex, :text]
    backend ∉ backends &&
        throw(ArgumentError("backend must be one of: $(join(backends, ", "))."))

    aov_table = copy(result.table)
    if backend == :latex
        tf = LatexTableFormat(; @latex__no_vertical_lines)
    elseif backend == :markdown
        tf = MarkdownTableFormat()
    else # :text
        tf = TextTableFormat(; @text__no_vertical_lines)
    end

    # deal with rows
    if !include_intercept
        aov_table = filter(row -> row.Effect != "Intercept", aov_table)
    end

    # Remove columns based on options
    !include_ss && _remove_columns!(aov_table, [:SSn, :SSd])
    !include_mse && _remove_columns!(aov_table, [:MSE])
    !include_es && _remove_columns!(aov_table, [:η², :η²ₚ, :ω²])
    !include_sig && _remove_columns!(aov_table, [:sig])

    # Format numeric columns
    anova_format_map = Dict(
        :SSn => 2,
        :SSd => 2,
        :MSE => 2,
        :F => 2,
        :η²ₚ => 3,
        :η² => 3,
        :ω² => 3,
        :ε => 3,
    )
    anova_special_cases = Dict(:p => (p -> p < 0.001 ? "< .001" : @sprintf("%.3f", p)))
    _format_columns!(aov_table, anova_format_map; special_cases = anova_special_cases)

    # Find the column index of "sig" for the footnote
    sig_col_idx = findfirst(==(:sig), propertynames(aov_table))
    footnote_text = "* = p < .05, ** = p < .01, *** = p < .001, n.s. = not significant"
    if !isnothing(sig_col_idx)
        footnotes = [(:column_label, 1, sig_col_idx) => footnote_text]
    else
        footnotes = nothing
    end

    return pretty_table(
        io,
        aov_table,
        backend = backend,
        title = title,
        show_column_labels = true,
        column_labels = names(aov_table),
        table_format = tf,
        footnotes = footnotes,
    )

end

"""
    emmeans_table(result::EmmeansResult; backend=:text, title="Estimated Marginal Means", io=stdout)

Print an estimated marginal means table using PrettyTables.

# Arguments
- `result::EmmeansResult`: An `EmmeansResult` object
- `backend::Symbol`: Output format. Options: `:markdown`, `:latex`, `:text` (default: `:text`)
- `title::String`: Table title (default: `"Estimated Marginal Means"`)
- `io::IO`: Output stream (default: `stdout`)

# Returns
Nothing (prints to `io`)

# Examples
```julia
result = anova(data, :dv, :id, within=[:time])
em = emmeans(result)
emmeans_table(em, backend=:markdown)
emmeans_table(em, backend=:latex)
emmeans_table(em, backend=:text)
```
"""
function emmeans_table(
    result::EmmeansResult;
    backend::Symbol = :text,
    title::String = "Estimated Marginal Means",
    io::IO = stdout,
)

    backends = [:markdown, :latex, :text]
    backend ∉ backends &&
        throw(ArgumentError("backend must be one of: $(join(backends, ", "))."))

    # Set up table format (common for both grouped and ungrouped)
    if backend == :latex
        tf = LatexTableFormat(; @latex__no_vertical_lines)
    elseif backend == :markdown
        tf = MarkdownTableFormat()
    else # :text
        tf = TextTableFormat(; @text__no_vertical_lines)
    end

    # Format map (common for both grouped and ungrouped)
    emmeans_format_map = Dict(:Mean => 2, :SD => 2, :SE => 2, :Lower => 2, :Upper => 2)

    # If grouping is specified, display grouped output
    if !isnothing(result.group)
        group_data = _group_emmeans_data(result.means, result.group)

        # Display each group (sort by group key for consistent ordering)
        sorted_group_keys = sort(collect(keys(group_data)))
        first_group = true
        for group_key in sorted_group_keys
            group_df = group_data[group_key]
            _format_columns!(group_df, emmeans_format_map)

            # Create title with group information
            group_info =
                "(" *
                join(
                    [
                        string(result.group[i]) * " = " * group_key[i] for
                        i = 1:length(result.group)
                    ],
                    ", ",
                ) *
                ")"
            group_title = title * " " * group_info

            !first_group && println(io)

            pretty_table(
                io,
                group_df,
                backend = backend,
                title = group_title,
                show_column_labels = true,
                column_labels = names(group_df),
                table_format = tf,
            )

            first_group = false
        end
    else # Standard (ungrouped) display
        mm_table = copy(result.means)
        _format_columns!(mm_table, emmeans_format_map)

        pretty_table(
            io,
            mm_table,
            backend = backend,
            title = title,
            show_column_labels = true,
            column_labels = names(mm_table),
            table_format = tf,
        )
    end

    # println(io)
    println(io, "Confidence level used: $(result.level)")

    return nothing
end


"""
    _group_emmeans_data(means_table, group_factors)

Group emmeans data by specified factors, returning a Dict mapping group combinations to DataFrames.
Modifies Effect and Level columns to exclude grouped factors.
"""
function _group_emmeans_data(means_table::DataFrame, group_factors::Vector{Symbol})

    effect_name = first(unique(means_table.Effect))
    effect_factors = Symbol.(strip.(split(effect_name, " × ")))

    # Find indices of group factors and remaining factors
    group_indices = [findfirst(==(f), effect_factors) for f in group_factors]
    remaining_factors = [f for f in effect_factors if f ∉ group_factors]
    remaining_indices = [findfirst(==(f), effect_factors) for f in remaining_factors]

    # Group data by group factor combinations
    group_data = Dict{Tuple{Vararg{String}},DataFrame}()

    for row in eachrow(means_table)
        level_parts = strip.(split(row.Level, ","))
        length(level_parts) != length(effect_factors) && continue  # Skip Grand Mean, etc.

        # Extract group and remaining values
        group_values = [level_parts[i] for i in group_indices]
        remaining_values =
            length(remaining_indices) > 0 ? [level_parts[i] for i in remaining_indices] :
            String[]

        # Create modified row (Effect and Level exclude grouped factors)
        new_effect =
            length(remaining_factors) > 0 ? join(string.(remaining_factors), " × ") : ""
        new_level = length(remaining_values) > 0 ? join(remaining_values, ", ") : ""

        new_row = (
            Effect = new_effect,
            Level = new_level,
            N = row.N,
            Mean = row.Mean,
            SD = row.SD,
            SE = row.SE,
            Lower = row.Lower,
            Upper = row.Upper,
            error = row.error,
        )

        # Store in grouped dictionary
        group_key = tuple(group_values...)
        if !haskey(group_data, group_key)
            group_data[group_key] = DataFrame(
                Effect = String[],
                Level = String[],
                N = Int[],
                Mean = Float64[],
                SD = Float64[],
                SE = Float64[],
                Lower = Float64[],
                Upper = Float64[],
                error = Float64[],
            )
        end
        push!(group_data[group_key], new_row)
    end

    return group_data
end

"""
    pairwise_table(result::PairwiseResult; backend=:text, title="Pairwise Comparisons", io=stdout)

Print a pairwise comparisons table using PrettyTables.

# Arguments
- `result::PairwiseResult`: A `PairwiseResult` object
- `backend::Symbol`: Output format. Options: `:markdown`, `:latex`, `:text` (default: `:text`)
- `title::String`: Table title (default: `"Pairwise Comparisons"`)
- `io::IO`: Output stream (default: `stdout`)

# Returns
Nothing (prints to `io`)

# Examples
```julia
result = anova(data, :dv, :id, within=[:time])
em = emmeans(result)
pw = pairwise(em)
pairwise_table(pw, backend=:markdown)
```
"""
function pairwise_table(
    result::PairwiseResult;
    backend::Symbol = :text,
    title::String = "Pairwise Comparisons",
    io::IO = stdout,
)

    backends = [:markdown, :latex, :text]
    backend ∉ backends &&
        throw(ArgumentError("backend must be one of: $(join(backends, ", "))."))

    pw_table = copy(result.table)
    if backend == :latex
        tf = LatexTableFormat(; @latex__no_vertical_lines)
    elseif backend == :markdown
        tf = MarkdownTableFormat()
    else # :text
        tf = TextTableFormat(; @text__no_vertical_lines)
    end

    # Remove Context column if it's empty or all the same
    if hasproperty(pw_table, :Context)
        if all(isempty.(pw_table.Context)) || length(unique(pw_table.Context)) == 1
            _remove_columns!(pw_table, [:Context])
        end
    end

    # Remove p_adj column if it's the same as p
    if all(result.table.p .== result.table.p_adj)
        _remove_columns!(pw_table, [:p_adj])
    end

    # Format decimal places
    pairwise_format_map = Dict(:Estimate => 2, :SE => 2, :t => 2, :Lower => 2, :Upper => 2)
    pairwise_special_cases = Dict(
        :p => (p -> p < 0.001 ? "< .001" : @sprintf("%.3f", p)),
        :p_adj => (p -> p < 0.001 ? "< .001" : @sprintf("%.3f", p)),
    )
    _format_columns!(pw_table, pairwise_format_map; special_cases = pairwise_special_cases)

    return pretty_table(
        io,
        pw_table,
        backend = backend,
        title = title,
        show_column_labels = true,
        column_labels = names(pw_table),
        table_format = tf,
    )
end


function _remove_columns!(table::DataFrame, cols_to_remove::Vector{Symbol})
    table_cols = propertynames(table)
    existing_cols = [col for col in cols_to_remove if col in table_cols]
    if !isempty(existing_cols)
        select!(table, Not(existing_cols))
    end
    return table
end


function _format_columns!(
    table::DataFrame,
    format_map::Dict{Symbol,Int};
    special_cases::Dict = Dict{Symbol,Any}(),
)
    cols = propertynames(table)
    for (col, digits) in format_map
        if col in cols
            table[!, col] = round.(table[!, col], digits = digits)
        end
    end

    for (col, fmt_func) in special_cases
        if col in cols
            table[!, col] = map(fmt_func, table[!, col])
        end
    end

    return table
end
