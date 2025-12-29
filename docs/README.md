# Building Documentation Locally

## Recommended Method: Using build_docs.jl

The easiest way to build and manage documentation is using the `build_docs.jl` script:

### Interactive Menu
```bash
julia --project=. docs/build_docs.jl
```
or
```bash
julia --project=. docs/build_docs.jl interactive
```

### Command Line Options
```bash
# Build documentation
julia --project=. docs/build_docs.jl build

# Check documentation coverage
julia --project=. docs/build_docs.jl coverage

# Format source files
julia --project=. docs/build_docs.jl format

# Clean build artifacts
julia --project=. docs/build_docs.jl clean

# Run complete workflow (format, build, check coverage)
julia --project=. docs/build_docs.jl all
```

### View the Documentation
After building, open `docs/build/index.html` in your web browser.

## Alternative Method: Direct Build

1. **Activate the docs environment:**
   ```julia
   using Pkg
   Pkg.activate("docs")
   Pkg.instantiate()
   ```

2. **Build the documentation:**
   ```julia
   include("build.jl")
   ```

Or from command line:
```bash
julia --project=docs docs/build.jl
```

## Troubleshooting

- If you get package errors, make sure you've run `Pkg.instantiate()` in the docs environment
- The built documentation will be in `docs/build/`
- To rebuild, just run the build script again (it will overwrite the previous build)
- The `build_docs.jl` script automatically handles package installation in a temporary environment

