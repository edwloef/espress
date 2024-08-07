module espress

include("Types.jl")
include("Node.jl")
include("Scope.jl")
include("Position.jl")
include("Error.jl")
include("Lexer.jl")
include("Parser.jl")
include("Interpreter.jl")

export espress_run

function espress_run(file::String)::Cint
    code = String[]
    open(file) do file
        while !eof(file)
            push!(code, strip(readline(file, keep = true)))
        end
    end
    global_scope = Scope(nothing, Dict{String, Node}(), 0)
    tokens = get_tokens(Lexer(global_scope, Position(ARGS[1], code, 1, 1, code[1][1])))
    if !ok(tokens)
        println(str(tokens))
        return 1
    end
    ast = parse(Parser(global_scope, tokens, tokens[1], 0))
    if !ok(ast)
        println(str(ast))
        return 1
    end
    result = interpret(ast, global_scope)
    if !ok(result)
        println(str(result))
        return 1
    end
    return 0
end

end