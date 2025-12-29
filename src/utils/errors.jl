"""
    @minimal_warning(msg)

Displays an error message and stops execution without showing a full stacktrace.
"""
macro minimal_warning(msg)
    quote
        @warn $(esc(msg)) _module = nothing _file = nothing _line = nothing
    end
end
