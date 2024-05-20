str(error::Error) = error.details * "\n" * build_scopes(error) * color_line(error)

function build_scopes(error::Error)::String
    returns = "in $(error.position.start_position.file) in line $(error.position.start_position.line)\n"
    !isnothing(error.scope.parent_scope) &&
        return build_scopes(error.scope.parent_scope) * returns
    return returns
end

function color_line(error::Error)::String
    returns = "    "
    line = strip(error.position.start_position.code[error.position.start_position.line])
    for i ∈ eachindex(line)
        i == error.position.start_position.position && (returns *= "\033[31m")
        returns *= line[i]
        i == error.position.end_position.position &&
            error.position.end_position.line == error.position.start_position.line &&
            (returns *= "\033[0m")
    end
    return returns * "\033[0m"
end
