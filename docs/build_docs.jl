using Logging
using Pkg
using Printf

# Define minimal warning macro
macro minimal_warning(msg)
    quote
        @warn $(esc(msg)) _module = nothing _file = nothing _line = nothing
    end
end

# Load documentation packages from docs environment
Pkg.activate(@__DIR__)
Pkg.develop(PackageSpec(path=pwd()))
Pkg.instantiate()

# load the required packages
using Documenter
using DocumenterTools
using JuliaFormatter

"""
Documentation Manager for AnovaFun

This is a comprehensive documentation management tool that provides:
- Building documentation with Documenter.jl
- Documentation coverage analysis
- Code formatting with JuliaFormatter
- Cleanup and maintenance tasks
- Interactive menu system

Usage:
    julia --project=. docs/build_docs.jl [command] [options]

Commands:
    build                    - Build documentation
    coverage                 - Check documentation coverage
    clean                    - Clean build artifacts
    interactive              - Show interactive menu
    all                      - Run complete documentation workflow

If no command is provided, shows interactive menu.
"""
function build_documentation(project_root::String)
    @info "Building documentation with Documenter.jl..."
    try
        # Build documentation
        build_jl_path = joinpath(project_root, "docs", "make.jl")
        
        old_logger = global_logger()
        try
            logger = ConsoleLogger(stderr, Logging.Error)
            global_logger(logger)
            include(build_jl_path)
        finally
            global_logger(old_logger)
        end
        @info "✓ Documentation built successfully"
        
    catch e
        @error "Error building documentation: $e"
        return false
    end
    
    println()
    return true
end


function check_doc_coverage(project_root::String; skip_build_check::Bool = false)
    @info "=== Documentation Coverage Check ==="
    println()
    try
        # Check for basic documentation files
        @info "Checking for required documentation files..."
        doc_files = [
            ("index.md", joinpath(project_root, "docs", "src", "index.md")),
            ("api.md", joinpath(project_root, "docs", "src", "api.md")),
            ("make.jl", joinpath(project_root, "docs", "make.jl")),
        ]
        missing_files = []
        
        for (name, file) in doc_files
            if isfile(file)
                @info "  ✓ $name found"
            else
                @error "  ✗ $name missing"
                push!(missing_files, file)
            end
        end
        
        if !isempty(missing_files)
            @error "\nMissing documentation files:"
            for file in missing_files
                println("  - $file")
            end
            return false
        end
        
        # Check make.jl configuration
        @info "\nChecking make.jl configuration..."
        build_jl_path = joinpath(project_root, "docs", "make.jl")
        build_jl_content = read(build_jl_path, String)
        if occursin("checkdocs = :all", build_jl_content)
            @info "  ✓ checkdocs=:all is enabled (all exported functions must have docstrings)"
        else
            @minimal_warning "  ⚠ checkdocs=:all not found in make.jl"
        end
        
        # Check if documentation has been built (only if not skipping)
        if !skip_build_check
            @info "\nChecking build status..."
            build_dir = joinpath(project_root, "docs", "build")
            if !isdir(build_dir)
                @minimal_warning "  ⚠ Documentation not built yet"
                @info "\nTo check docstring coverage, run:"
                @info "  julia --project=. docs/build_docs.jl build"
                @info "\nDocumenter will verify all exported functions have docstrings during the build."
            else
                @info "  ✓ Documentation build directory exists"
                index_html = joinpath(build_dir, "index.html")
                if isfile(index_html)
                    @info "  ✓ Documentation HTML files generated"
                else
                    @minimal_warning "  ⚠ index.html not found in build directory"
                end
            end
        end
        
        println()
        @info "=== Summary ==="
        @info "Documentation setup looks good!"
        @info "Note: Actual docstring coverage is checked by Documenter during the build process."
        @info "If checkdocs=:all is enabled, the build will fail if any exported function lacks a docstring."
        
    catch e
        @error "Error checking documentation coverage: $e"
        return false
    end
    
    println()
    return true
end


function clean_docs(project_root::String)
    @info "Cleaning documentation build artifacts..."
    
    # Clean build directory
    build_dir = joinpath(project_root, "docs", "build")
    if isdir(build_dir)
        rm(build_dir, recursive=true)
        @info "✓ Removed docs/build directory"
    else
        @minimal_warning "No build directory found"
    end
    
    # Clean other common build artifacts
    artifacts = ["site", ".documenter", "Manifest.toml"]
    for artifact in artifacts
        artifact_path = joinpath(project_root, "docs", artifact)
        if isdir(artifact_path) || isfile(artifact_path)
            rm(artifact_path, recursive=true)
            @info "✓ Removed docs/$artifact"
        end
    end
    
    @info "✓ Documentation cleanup completed"
    println()
end


function format_source_files(project_root::String)
    @info "Formatting Julia source files..."
    try

        src_dir = joinpath(project_root, "src")
        julia_files = String[]
        for (root, _, files) in walkdir(src_dir)
            for file in files
                if endswith(file, ".jl")
                    push!(julia_files, joinpath(root, file))
                end
            end
        end
        if isempty(julia_files)
            @minimal_warning "No Julia files found in src directory"
            return true
        end
        @info "Found $(length(julia_files)) Julia file(s) to format:"
        for file in julia_files
            @info "  - $file"
        end
        formatted_count = 0
        for file in julia_files
            try
                JuliaFormatter.format_file(file)
                formatted_count += 1
            catch e
                @error "Error formatting $file: $e"
            end
        end
        @info "✓ Successfully formatted $formatted_count/$(length(julia_files)) file(s)"

        # Also format test files
        test_dir = joinpath(project_root, "test")
        test_files = String[]
        for (root, dirs, files) in walkdir(test_dir)
            for file in files
                if endswith(file, ".jl") && !endswith(file, ".cov")
                    push!(test_files, joinpath(root, file))
                end
            end
        end
        if isempty(test_files)
            @minimal_warning "No test files found in test directory"
            return true
        end
        @info "Found $(length(test_files)) test file(s) to format:"
        for file in test_files
            @info "  - $file"
        end
        formatted_count = 0
        for file in test_files
            try
                JuliaFormatter.format_file(file)
                formatted_count += 1
            catch e
                @error "Error formatting $file: $e"
            end
        end
        @info "✓ Successfully formatted $formatted_count/$(length(test_files)) file(s)"

    catch e
        @error "Error during formatting: $e"
        return false
    end

    println()
    return true
end

function format_and_check(project_root::String)
    @info "Formatting and checking Julia files..."

    !format_source_files(project_root) && return false

    # Run a quick syntax check
    @info "Running syntax check..."
    try
        Pkg.precompile()
        @info "✓ Syntax check passed"
    catch e
        @error "Syntax check failed: $e"
        return false
    end

    @info "✓ Formatting and syntax check completed"
    println()
    return true
end


function run_all_docs(project_root::String)
    @info "Running complete documentation workflow..."
    println()
    
    # Step 1: Format source files
    @info "Step 1: Formatting source files..."
    if !format_source_files(project_root)
        @error "Formatting failed"
        return false
    end
    
    # Step 2: Build documentation
    @info "Step 2: Building documentation..."
    if !build_documentation(project_root)
        @error "Documentation build failed"
        return false
    end
    
    # Step 3: Check documentation coverage
    @info "Step 3: Checking documentation coverage..."
    check_doc_coverage(project_root)
    
    @info "=== Documentation Workflow Complete ==="
    println("Next steps:")
    println("1. Review the built documentation in docs/build/")
    println("2. Open docs/build/index.html in your browser to view documentation")
    println("3. Deploy to GitHub Pages when ready")
    
    return true
end

function show_interactive_menu(project_root::String)
    @info "=== AnovaFun Documentation Manager ==="
    println()
    
    while true
        println("\nChoose an option:")
        println("1. Build documentation")
        println("2. Check documentation coverage")
        println("3. Format source files")
        println("4. Format and check syntax")
        println("5. Clean build artifacts")
        println("6. Run complete workflow")
        println("7. Exit")
        
        print("\nEnter your choice (1-7): ")
        choice = readline()
        
        if choice == "1"
            build_documentation(project_root)
            if isfile(joinpath(project_root, "docs", "build", "index.html"))
                @info "✓ Documentation built successfully!"
                println("Open docs/build/index.html in your browser to view the documentation")
            end
        elseif choice == "2"
            check_doc_coverage(project_root)
        elseif choice == "3"
            format_source_files(project_root)
        elseif choice == "4"
            format_and_check(project_root)
        elseif choice == "5"
            clean_docs(project_root)
        elseif choice == "6"
            run_all_docs(project_root)
        elseif choice == "7"
            break
        else
            @error "Invalid choice. Please enter 1-7."
        end
    end
end

function main()
    project_root = dirname(@__DIR__)
    
    if length(ARGS) == 0
        command = "interactive"
    elseif length(ARGS) == 1
        command = ARGS[1]
    else
        command = ARGS[1]
    end
    
    if command == "build"
        build_documentation(project_root)
    elseif command == "coverage"
        check_doc_coverage(project_root)
    elseif command == "format"
        format_source_files(project_root)
    elseif command == "format-check"
        format_and_check(project_root)
    elseif command == "clean"
        clean_docs(project_root)
    elseif command == "all"
        run_all_docs(project_root)
    elseif command == "interactive"
        show_interactive_menu(project_root)
    else
        @info "=== AnovaFun Documentation Manager ==="
        println()
        println("Usage: julia --project=. docs/build_docs.jl [command]")
        println()
        println("Commands:")
        println("  build        - Build documentation")
        println("  coverage     - Check documentation coverage")
        println("  format       - Format Julia source files")
        println("  format-check - Format files and run syntax check")
        println("  clean        - Clean build artifacts")
        println("  interactive  - Show interactive menu")
        println("  all          - Run complete documentation workflow")
        println()
        println("Examples:")
        println("  julia --project=. docs/build_docs.jl build")
        println("  julia --project=. docs/build_docs.jl format")
        println("  julia --project=. docs/build_docs.jl clean")
        println("  julia --project=. docs/build_docs.jl interactive")
    end
end

main()