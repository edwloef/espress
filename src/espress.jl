include("Types.jl")
include("Position.jl")
include("Error.jl")
include("Lexer.jl")
include("Parser.jl")
include("Interpreter.jl")

function julia_main()::Cint
    if length(ARGS) != 1
        println("Please provide an espress file.")
        return 1
    end
    code = String[]
    open(ARGS[1]) do file
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

julia_main()

# using Profile
# @time @profile julia_main()
# Profile.print(format = :flat)
