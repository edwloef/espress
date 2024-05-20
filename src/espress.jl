include("Types.jl")
include("Node.jl")
include("Scope.jl")
include("Position.jl")
include("Error.jl")
include("Lexer.jl")
include("Parser.jl")
include("Interpreter.jl")

function main(ARGS)
    code = String[]
    open(ARGS[1]) do file
        while !eof(file)
            push!(code, strip(readline(file)) * '\n')
        end
    end
    global_scope = Scope(nothing, Dict{String,Node}(), 0)
    tokens = get_tokens(Lexer(global_scope, Position(ARGS[1], code, 1, 1, code[1][1])))
    if isa(tokens, Error)
        println(str(tokens))
        return
    end
    ast = parse(Parser(global_scope, tokens, tokens[1], 0))
    if isa(ast, Error)
        println(str(ast))
        return
    end
    result = interpret(ast, global_scope)
    if isa(result, Error)
        println(str(result))
        return
    end
end

@main
