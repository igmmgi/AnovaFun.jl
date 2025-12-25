using AnovaFun
using DataFrames
using CSV
using Random

Random.seed!(123)

# Get the directory where this script is located
const TEST_DATA_DIR = joinpath(@__DIR__, "test_data")

# Ensure test_data directory exists
mkpath(TEST_DATA_DIR)

# Generate some test data
function generate_test_data(
    n_id::Int;
    within_levels::Vector{Int} = Int[],
    between_levels::Vector{Int} = Int[],
)
    @assert n_id > 0 "Expected at least one subject"

    within_counts = [level for level in within_levels if level > 0]
    n_conditions = isempty(within_counts) ? 1 : prod(within_counts)
    df = DataFrame(subject = repeat(1:n_id, inner = n_conditions))

    if !isempty(within_counts)
        within_level_labels =
            [["F$(i)_L$(j)" for j = 1:within_counts[i]] for i in eachindex(within_counts)]

        for (idx, labels) in enumerate(within_level_labels)
            inner_count = idx < length(within_counts) ? prod(within_counts[(idx+1):end]) : 1
            leading_count = idx > 1 ? prod(within_counts[1:(idx-1)]) : 1
            outer_count = n_id * leading_count
            column = repeat(labels; inner = inner_count, outer = outer_count)
            df[!, Symbol("WF$(idx)")] = column
        end
    end

    if !isempty(between_levels)
        between_counts = [level for level in between_levels if level > 0]
        if !isempty(between_counts)
            between_level_labels = [
                ["G$(i)_L$(j)" for j = 1:between_counts[i]] for
                i in eachindex(between_counts)
            ]
            between_combos =
                collect(Iterators.product((levels for levels in between_level_labels)...))
            assigned = [between_combos[mod1(i, length(between_combos))] for i = 1:n_id]

            for (idx, _) in enumerate(between_counts)
                subject_levels = [combo[idx] for combo in assigned]
                df[!, Symbol("BF$(idx)")] =
                    vec(repeat(subject_levels, inner = n_conditions))
            end
        end
    end

    df[!, :dv] = randn(n_id * n_conditions)

    return df
end

#########################
# Between-subjects designs
#########################
df_between_2 = generate_test_data(100; within_levels = Int[0], between_levels = Int[2])
CSV.write(joinpath(TEST_DATA_DIR, "data_between_2.csv"), df_between_2)
df_between_3 = generate_test_data(100; within_levels = Int[0], between_levels = Int[3])
CSV.write(joinpath(TEST_DATA_DIR, "data_between_3.csv"), df_between_3)
df_between_2x2 = generate_test_data(100; within_levels = Int[0], between_levels = [2, 2])
CSV.write(joinpath(TEST_DATA_DIR, "data_between_2x2.csv"), df_between_2x2)

#########################
# Within-subjects designs
#########################
df_within_2 = generate_test_data(100; within_levels = Int[2], between_levels = [0])
CSV.write(joinpath(TEST_DATA_DIR, "data_within_2.csv"), df_within_2)
df_within_3 = generate_test_data(100; within_levels = Int[3], between_levels = [0])
CSV.write(joinpath(TEST_DATA_DIR, "data_within_3.csv"), df_within_3)
df_within_2x2 = generate_test_data(100; within_levels = Int[2, 2], between_levels = [0])
CSV.write(joinpath(TEST_DATA_DIR, "data_within_2x2.csv"), df_within_2x2)
df_within_2x3 = generate_test_data(100; within_levels = Int[2, 3], between_levels = [0])
CSV.write(joinpath(TEST_DATA_DIR, "data_within_2x3.csv"), df_within_2x3)
df_within_2x2x2 =
    generate_test_data(100; within_levels = Int[2, 2, 2], between_levels = [0])
CSV.write(joinpath(TEST_DATA_DIR, "data_within_2x2x2.csv"), df_within_2x2x2)


#########################
# Mixed-subjects designs
#########################
df_mixed_WB_2x2 = generate_test_data(100; within_levels = Int[2], between_levels = [2])
CSV.write(joinpath(TEST_DATA_DIR, "data_mixed_WB_2x2.csv"), df_mixed_WB_2x2)
df_mixed_WB_3x2 = generate_test_data(100; within_levels = Int[3], between_levels = [2])
CSV.write(joinpath(TEST_DATA_DIR, "data_mixed_WB_3x2.csv"), df_mixed_WB_3x2)
df_mixed_WWB_2x2x3 =
    generate_test_data(100; within_levels = Int[2, 2], between_levels = [2])
CSV.write(joinpath(TEST_DATA_DIR, "data_mixed_WWB_2x2x3.csv"), df_mixed_WWB_2x2x3)
