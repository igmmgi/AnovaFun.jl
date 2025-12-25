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

    pretty_table(
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

    mm_table = copy(result.means)
    if backend == :latex
        tf = LatexTableFormat(; @latex__no_vertical_lines)
    elseif backend == :markdown
        tf = MarkdownTableFormat()
    else # :text
        tf = TextTableFormat(; @text__no_vertical_lines)
    end

    # Format decimal places
    emmeans_format_map = Dict(:Mean => 2, :SE => 2, :Lower => 2, :Upper => 2)
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

    pretty_table(
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
