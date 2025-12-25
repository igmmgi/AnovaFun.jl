#!/usr/bin/env julia
"""
Test Runner and Coverage Analysis Tool for AnovaFun

This is a pure Julia equivalent of test.sh that provides:
- Running tests with coverage
- Coverage analysis and reporting
- HTML report generation
- Cleanup of .cov files
- Interactive menu system

Usage:
    julia --project=. test/test_manager.jl [command] [options]

Commands:
    test                    - Run tests with coverage
    summary                 - Show coverage summary
    detailed                - Show detailed analysis
    file FILENAME           - Analyze specific file
    missed FILENAME         - Show missed code branches
    html                    - Generate HTML report
    clean                   - Remove all .cov files
    interactive             - Show interactive menu
    all                     - Run complete workflow

If no command is provided, shows interactive menu.
"""

using Printf
using Pkg
using Logging

# Ensure coverage packages are available
# Activate a temporary environment and add packages if needed
Pkg.activate(; temp = true)
for pkg in ["Coverage", "CoverageTools"]
    Pkg.add(pkg)
end

# Now we can safely use the packages
using Coverage
using CoverageTools

# Constants
const SRC_DIR = "src"
const COV_EXT = ".cov"
const LCOV_FILE = "test/coverage.lcov"
const HTML_OUTPUT_DIR = "test/coverage_html"

# Helper functions
function calculate_coverage_stats(coverage_data)
    """Calculate coverage statistics from coverage data array."""
    covered = count(x -> !isnothing(x) && x > 0, coverage_data)
    uncovered = count(x -> !isnothing(x) && x == 0, coverage_data)
    not_executable = count(x -> isnothing(x), coverage_data)
    total = length(coverage_data)
    executable = covered + uncovered

    percentage = executable > 0 ? round(covered / executable * 100, digits = 2) : 0.0

    return (; covered, uncovered, not_executable, total, executable, percentage)
end

function get_uncovered_lines(coverage_data)
    """Get list of uncovered line numbers."""
    uncovered = Int[]
    for (i, cov) in enumerate(coverage_data)
        if !isnothing(cov) && cov == 0
            push!(uncovered, i)
        end
    end
    return uncovered
end

function find_coverage_file(coverage, target_file::String)
    """Find coverage data for a specific file."""
    matches = filter(c -> occursin(target_file, c.filename), coverage)
    return isempty(matches) ? nothing : matches[1]
end

function handle_coverage_error(e, context = "")
    """Standard error handling for coverage operations."""
    context_str = isempty(context) ? "" : " in $context"
    @error "Error$context_str: $e"
    println("Make sure you've run tests with coverage first!")
    println()
end

function run_tests_with_coverage()
    @info "Step 1: Running Tests with Coverage"
    try
        run(`julia --project=. -e 'using Pkg; Pkg.test(coverage=true)'`)
        @info "✓ Tests completed successfully"
    catch e
        @error "Error running tests: $e"
        exit(1)
    end
    println()
end

function show_coverage_summary()
    @info "Step 2: Coverage Summary"
    try
        coverage = process_folder(SRC_DIR)

        println("Coverage Summary:")
        println("=================")

        total_covered = 0
        total_uncovered = 0

        for c in coverage
            if !isnothing(c.coverage)
                stats = calculate_coverage_stats(c.coverage)

                if stats.executable > 0
                    filename = replace(c.filename, "$SRC_DIR/" => "")
                    println(
                        "$filename: $(stats.percentage)% ($(stats.covered)/$(stats.executable) lines)",
                    )

                    total_covered += stats.covered
                    total_uncovered += stats.uncovered
                end
            end
        end

        if total_covered + total_uncovered > 0
            overall_percentage =
                round(total_covered / (total_covered + total_uncovered) * 100, digits = 2)
            @info "Overall Coverage: $overall_percentage% ($total_covered/$(total_covered + total_uncovered) lines)"
        end
    catch e
        handle_coverage_error(e, "coverage summary")
    end
    println()
end

function show_detailed_analysis()
    @info "Step 3: Detailed Analysis"

    try
        coverage = process_folder(SRC_DIR)

        for c in coverage
            if !isnothing(c.coverage)
                stats = calculate_coverage_stats(c.coverage)

                if stats.executable > 0
                    filename = replace(c.filename, "$SRC_DIR/" => "")

                    println("\n--- $filename ---")
                    println("Total lines: $(stats.total)")
                    println("Covered lines: $(stats.covered)")
                    println("Uncovered lines: $(stats.uncovered)")
                    println("Not executable lines: $(stats.not_executable)")
                    println("Coverage percentage: $(stats.percentage)%")

                    uncovered_lines = get_uncovered_lines(c.coverage)
                    if !isempty(uncovered_lines)
                        println("Uncovered lines: $(join(uncovered_lines, ", "))")
                    end
                end
            end
        end
    catch e
        handle_coverage_error(e, "detailed analysis")
    end
    println()
end

function analyze_specific_file(target_file::String)
    @info "Analyzing: $target_file"

    try
        coverage = process_folder(SRC_DIR)
        c = find_coverage_file(coverage, target_file)

        if isnothing(c)
            println("No coverage data found for $target_file")
            return
        end

        stats = calculate_coverage_stats(c.coverage)

        println("File: $(c.filename)")
        println("Total lines: $(stats.total)")
        println("Covered lines: $(stats.covered)")
        println("Uncovered lines: $(stats.uncovered)")
        println("Not executable lines: $(stats.not_executable)")

        if stats.executable > 0
            println("Coverage percentage: $(stats.percentage)%")
        end

        uncovered_lines = get_uncovered_lines(c.coverage)
        if !isempty(uncovered_lines)
            println("\nUncovered line numbers:")
            println(join(uncovered_lines, ", "))
        end
    catch e
        handle_coverage_error(e, "file analysis")
    end
    println()
end

function show_missed_branches(target_file::String)
    @info "Missed Code Branches: $target_file"

    try
        coverage = process_folder(SRC_DIR)
        c = find_coverage_file(coverage, target_file)

        if isnothing(c)
            println("No coverage data found for $target_file")
            return
        end

        if !isfile(c.filename)
            println("Source file not found: $(c.filename)")
            return
        end

        lines = readlines(c.filename)
        println("File: $(c.filename)")
        println("Total lines: $(length(c.coverage))")

        uncovered_lines = get_uncovered_lines(c.coverage)

        for line_num in uncovered_lines
            if line_num <= length(lines)
                start_line = max(1, line_num - 2)
                end_line = min(length(lines), line_num + 2)

                println("\n--- Around line $line_num ---")
                for j = start_line:end_line
                    marker = j == line_num ? ">>> " : "    "
                    println("$marker$j: $(lines[j])")
                end
            end
        end
    catch e
        handle_coverage_error(e, "missed branches")
    end
    println()
end

function generate_html_report()
    @info "Step 4: Generating HTML Coverage Report"

    try
        coverage = process_folder(SRC_DIR)

        # Generate LCOV file
        CoverageTools.LCOV.writefile(LCOV_FILE, coverage)
        @info "✓ LCOV file generated: $LCOV_FILE"

        # Check if genhtml is available
        genhtml_check = try
            run(pipeline(`which genhtml`, stdout = devnull, stderr = devnull), wait = true)
            true
        catch
            false
        end

        if genhtml_check
            @info "✓ genhtml found, generating HTML report..."
            run(`genhtml $LCOV_FILE -o $HTML_OUTPUT_DIR`)
            @info "✓ HTML report generated: $HTML_OUTPUT_DIR/index.html"
            println("Open with: open $HTML_OUTPUT_DIR/index.html")
        else
            @minimal_warning "genhtml not found. Install with: brew install lcov"
            println("Then run: genhtml $LCOV_FILE -o $HTML_OUTPUT_DIR")
        end
    catch e
        handle_coverage_error(e, "HTML report generation")
    end
    println()
end

function clean_coverage_files()
    @info "Cleaning up .cov files..."

    # Find all .cov files recursively from current directory
    cov_files = String[]
    for (root, dirs, files) in walkdir(".")
        for file in files
            if endswith(file, COV_EXT)
                push!(cov_files, joinpath(root, file))
            end
        end
    end

    if isempty(cov_files)
        @info "No .cov files found to clean"
        return
    end

    println("Found $(length(cov_files)) .cov file(s) to remove:")
    for file in cov_files
        println("  - $file")
    end

    # Remove files
    for file in cov_files
        rm(file, force = true)
    end

    @info "✓ Successfully removed $(length(cov_files)) .cov file(s)"
    println()
end

function run_all_analyses()
    @info "=== Complete Coverage Analysis Workflow ==="
    println()

    run_tests_with_coverage()
    show_coverage_summary()
    show_detailed_analysis()
    generate_html_report()

    @info "=== Analysis Complete ==="
end

function show_interactive_menu()
    @info "=== ANOVA Test Runner and Coverage Analysis ==="
    println()

    while true
        println("\nChoose an option:")
        println("1. Run tests with coverage")
        println("2. Show coverage summary")
        println("3. Show detailed analysis")
        println("4. Analyze specific file")
        println("5. Show missed code branches")
        println("6. Generate HTML report")
        println("7. Clean .cov files")
        println("8. Exit")

        print("\nEnter your choice (1-8): ")
        choice = strip(readline())

        if choice == "1"
            run_tests_with_coverage()
        elseif choice == "2"
            show_coverage_summary()
        elseif choice == "3"
            show_detailed_analysis()
        elseif choice == "4"
            print("Enter filename to analyze (e.g., utils/data.jl): ")
            filename = String(strip(readline()))
            if !isempty(filename)
                analyze_specific_file(filename)
            end
        elseif choice == "5"
            print("Enter filename to show missed branches (e.g., utils/data.jl): ")
            filename = String(strip(readline()))
            if !isempty(filename)
                show_missed_branches(filename)
            end
        elseif choice == "6"
            generate_html_report()
        elseif choice == "7"
            clean_coverage_files()
        elseif choice == "8"
            break
        else
            @error "Invalid choice. Please enter 1-8."
        end
    end
end

function main()
    # Simple command line argument parsing
    if length(ARGS) == 0
        command = "interactive"
        filename = ""
    elseif length(ARGS) == 1
        command = ARGS[1]
        filename = ""
    else
        command = ARGS[1]
        filename = ARGS[2]
    end

    if command == "test"
        run_tests_with_coverage()
    elseif command == "summary"
        show_coverage_summary()
    elseif command == "detailed"
        show_detailed_analysis()
    elseif command == "file"
        if isempty(filename)
            @error "Error: Please specify a filename"
            println("Usage: julia --project=. test/test_manager.jl file utils/data.jl")
        else
            analyze_specific_file(filename)
        end
    elseif command == "missed"
        if isempty(filename)
            @error "Error: Please specify a filename"
            println("Usage: julia --project=. test/test_manager.jl missed utils/data.jl")
        else
            show_missed_branches(filename)
        end
    elseif command == "html"
        generate_html_report()
    elseif command == "clean"
        clean_coverage_files()
    elseif command == "all"
        run_all_analyses()
    elseif command == "interactive"
        show_interactive_menu()
    else
        @info "=== AnovaFun Test Runner and Coverage Analysis ==="
        println()
        println("Usage: julia --project=. test/test_manager.jl [command] [options]")
        println()
        println("Commands:")
        println("  test                    - Run tests with coverage")
        println("  summary                 - Show coverage summary")
        println("  detailed                - Show detailed analysis")
        println("  file FILENAME           - Analyze specific file")
        println("  missed FILENAME         - Show missed code branches")
        println("  html                    - Generate HTML report")
        println("  clean                   - Remove all .cov files")
        println("  interactive             - Show interactive menu")
        println("  all                     - Run complete workflow")
        println()
        println("Output files are saved in the test/ directory:")
        println("  - $LCOV_FILE     - LCOV coverage data")
        println("  - $HTML_OUTPUT_DIR/    - HTML coverage report")
        println()
        println("Examples:")
        println("  julia --project=. test/test_manager.jl all")
        println("  julia --project=. test/test_manager.jl file utils/data.jl")
        println("  julia --project=. test/test_manager.jl missed utils/data.jl")
        println("  julia --project=. test/test_manager.jl clean")
    end
end

# Run the main function
main()
