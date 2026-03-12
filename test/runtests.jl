using Test

# Import the package
using AnovaFun

# Include shared test utilities first
include("tests/test_utils.jl")

println("Running AnovaFun.jl Test Suite")
println("="^40)

@testset "AnovaFun" begin
    # Core ANOVA Design Tests
    include("tests/between_subjects.jl")
    include("tests/within_subjects.jl")
    include("tests/mixed_designs.jl")

    # EMM and Pairwise Tests
    include("tests/emmeans.jl")
    include("tests/pairwise.jl")

    # Integration and Formatting Tests
    include("tests/model_integration.jl")
    include("tests/apa_formatting.jl")

    # Assumption Tests
    include("tests/homogeneity.jl")
    include("tests/sphericity.jl")

    # Effect Size Tests
    include("tests/effect_sizes.jl")

    # t-test utilities
    include("tests/ttests.jl")

    # Type and Table Tests
    include("tests/types.jl")
    include("tests/tables.jl")

    # Report Formatting Tests
    include("tests/report.jl")

    # Utils Tests
    include("tests/utils.jl")

    # Power Analysis Tests
    include("tests/power.jl")
    include("tests/simulate.jl")
    include("tests/sample_size.jl")

    # Plotting Tests
    include("tests/plot_config.jl")
    include("tests/plotting.jl")
end

println("\nAll tests completed!")
