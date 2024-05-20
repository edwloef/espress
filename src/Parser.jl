using Match

advance!(parser::Parser) = parser.current_token = parser.tokens[parser.index+=1]

function parse(parser::Parser)::Union{Vector{Node},Error}
    parse_result = Node[]
    while advance!(parser).type != EOF
        result = parse_keywords!(parser)
        isa(result, Error) && return result
        parser.current_token.type != EOL &&
            return Error("Expected newline", parser.scope, parser.current_token.position)
        push!(parse_result, result)
    end
    return parse_result
end

function parse_keywords!(parser::Parser)::Union{Node,Error}
    parser.current_token.type == Keyword && return @match parser.current_token.value begin
        "fn" => parse_fn!(parser)
        "del" => parse_del!(parser)
        "if" => parse_if!(parser)
        "loop" => parse_loop!(parser)
        "return" => parse_return!(parser)
        "break" => parse_break!(parser)
        "continue" => parse_continue!(parser)
        "try" => parse_try_catch!(parser)
        "print" || "println" => parse_builtin!(parser)
        "end" => Error("Unexpected 'end'", parser.scope, parser.current_token.position)
    end
    return parse_or!(parser)
end

function parse_fn!(parser::Parser)::Union{FunctionNode,Error}
    advance!(parser).type == Identifier ||
        return Error("Expected identifier", parser.scope, parser.current_token.position)
    identifier = parser.current_token
    arguments = ReferenceNode[]
    if advance!(parser).type == LeftParenthesis
        advance!(parser)
        while parser.current_token.type != RightParenthesis
            parser.current_token.type != Identifier && return Error(
                "Expected parameter identifier",
                parser.scope,
                parser.current_token.position,
            )
            push!(
                arguments,
                ReferenceNode(
                    parser.current_token.position,
                    parser.current_token.value,
                    Node[],
                ),
            )
            advance!(parser).type == EOL && advance!(parser)
        end
        advance!(parser)
    end
    actions = Node[]
    if parser.current_token.value == '='
        advance!(parser)
        action = parse_keywords!(parser)
        isa(action, Error) && return action
        push!(actions, ReturnNode(action.position, action))
    elseif parser.current_token.type == EOL
        while !(advance!(parser).value == "end")
            action = parse_keywords!(parser)
            isa(action, Error) && return action
            push!(actions, action)
        end
        advance!(parser)
    else
        return Error(
            "Expected newline after function definition",
            parser.scope,
            parser.current_token.position,
        )
    end
    return FunctionNode(identifier.position, identifier.value, arguments, actions)
end

function parse_del!(parser::Parser)::Union{DeletionNode,Error}
    keyword = parser.current_token
    advance!(parser).type != Identifier &&
        return Error("Expected identifier", parser.scope, parser.current_token.position)
    identifier = parser.current_token
    advance!(parser).type != EOL && return Error(
        "Expected newline after deletion",
        parser.scope,
        parser.current_token.position,
    )
    return DeletionNode(
        Range(keyword.position.start_position, identifier.position.end_position),
        identifier.value,
    )
end

function parse_if!(parser::Parser)::Union{IfNode,Error}
    if_token = parser.current_token
    advance!(parser)
    condition = parse_keywords!(parser)
    isa(condition, Error) && return condition
    parser.current_token.type != EOL && return Error(
        "Expected newline after 'if'-condition",
        parser.scope,
        parser.current_token.position,
    )
    actions = Node[]
    while !(advance!(parser).value == "end" || parser.current_token.value == "else")
        action = parse_keywords!(parser)
        isa(action, Error) && return action
        push!(actions, action)
    end
    if_node = ActionsNode(if_token.position, actions)
    else_node = nothing
    if parser.current_token.value == "else"
        else_token = parser.current_token
        actions = Node[]
        advance!(parser).type != EOL && return Error(
            "Expected newline after 'else'",
            parser.scope,
            parser.current_token.position,
        )
        if parser.current_token.value == "if"
            action = parse_if!(parser)
            isa(action, Error) && return action
            push!(actions, action)
        else
            while advance!(parser).value != "end"
                action = parse_keywords!(parser)
                isa(action, Error) && return action
                push!(actions, action)
            end
        end
        else_node = ActionsNode(else_token.position, actions)
    else
        advance!(parser)
    end
    return IfNode(
        Range(if_node.position.start_position, if isnothing(else_node)
            if_node.position.end_position
        else
            else_node.position.end_position
        end),
        condition,
        if_node,
        else_node,
    )
end

function parse_loop!(parser::Parser)::Union{LoopNode,Error}
    loop_token = parser.current_token
    advance!(parser).type != EOL && return Error(
        "Expected newline after 'loop'",
        parser.scope,
        parser.current_token.position,
    )
    actions = Node[]
    while !(advance!(parser).value == "end")
        action = parse_keywords!(parser)
        isa(action, Error) && return action
        push!(actions, action)
    end
    advance!(parser)
    return LoopNode(loop_token.position, actions)
end

function parse_return!(parser::Parser)::Union{ReturnNode,Error}
    return_token = parser.current_token
    advance!(parser).type == EOL && return ReturnNode(
        return_token.position,
        NoneNode(
            Range(return_token.position.end_position, return_token.position.end_position),
        ),
    )
    value = parse_keywords!(parser)
    isa(value, Error) && return value
    return ReturnNode(
        Range(return_token.position.start_position, value.end_position),
        value,
    )
end

function parse_break!(parser::Parser)::BreakNode
    break_token = parser.current_token
    advance!(parser)
    return BreakNode(break_token.position)
end

function parse_continue!(parser::Parser)::ContinueNode
    continue_token = parser.current_token
    advance!(parser)
    return ContinueNode(continue_token.position)
end

function parse_try_catch!(parser::Parser)::Union{TryNode,Error}
    try_token = parser.current_token
    advance!(parser)
    actions = Node[]
    while !(advance!(parser).value == "end" || parser.current_token.value == "catch")
        action = parse_keywords!(parser)
        isa(action, Error) && return action
        push!(actions, action)
    end
    try_node = ActionsNode(try_token.position, actions)
    catch_node = nothing
    if parser.current_token.value == "catch"
        catch_token = parser.current_token
        actions = Node[]
        advance!(parser).type != EOL && return Error(
            "Expected newline after 'catch'",
            parser.scope,
            parser.current_token.position,
        )
        while advance!(parser).value != "end"
            action = parse_keywords!(parser)
            isa(action, Error) && return action
            push!(actions, action)
        end
        catch_node = ActionsNode(catch_token.position, actions)
    else
        advance!(parser)
    end
    return TryNode(
        Range(try_node.position.start_position, if isnothing(catch_node)
            try_node.position.end_position
        else
            catch_node.position.end_position
        end),
        try_node,
        catch_node,
    )
end

function parse_builtin!(parser::Parser)::Union{Node,Error}
    builtin_token = parser.current_token
    value = NoneNode(
        Range(builtin_token.position.end_position, builtin_token.position.end_position),
    )
    advance!(parser).type == EOL &&
        return BuiltinNode(builtin_token.position, builtin_token.value, value)
    value = parse_keywords!(parser)
    isa(value, Error) && return value
    return BuiltinNode(builtin_token.position, builtin_token.value, value)
end

function parse_or!(parser::Parser)::Union{Node,Error}
    left = parse_and!(parser)
    (isa(left, Error) || parser.current_token.value != "or") && return left
    advance!(parser)
    right = parse_or!(parser)
    isa(right, Error) && return right
    return LogicalOperationNode(
        Range(left.position.start_position, right.position.end_position),
        "or",
        left,
        right,
    )
end

function parse_and!(parser::Parser)::Union{Node,Error}
    left = parse_not!(parser)
    (isa(left, Error) || parser.current_token.value != "and") && return left
    advance!(parser)
    right = parse_and!(parser)
    isa(right, Error) && return right
    return LogicalOperationNode(
        Range(left.position.start_position, right.position.end_position),
        "and",
        left,
        right,
    )
end

function parse_not!(parser::Parser)::Union{Node,Error}
    (
        parser.current_token.type != LogicalOperation ||
        parser.current_token.value != "not"
    ) && return parse_comparison!(parser)
    not_token = advance!(parser)
    node = parse_not!(parser)
    isa(node, Error) && return node
    return LogicalOperationNode(
        Range(not_token.start_position, node.end_position),
        "not",
        nothing,
        node,
    )
end

function parse_comparison!(parser::Parser)::Union{Node,Error}
    left = parse_plus_minus!(parser)
    (isa(left, Error) || parser.current_token.type != Comparison) && return left
    comparison_token = parser.current_token
    advance!(parser)
    right = parse_comparison!(parser)
    isa(right, Error) && return right
    return ComparisonNode(
        Range(left.position.start_position, right.position.end_position),
        comparison_token.value * "",
        left,
        right,
    )
end

function parse_plus_minus!(parser::Parser)::Union{Node,Error}
    left = parse_times_divided_modulo!(parser)
    (isa(left, Error) || parser.current_token.value ∉ ['+', '-']) && return left
    while parser.current_token.value ∈ ['+', '-']
        operation_token = parser.current_token
        advance!(parser)
        right = parse_times_divided_modulo!(parser)
        isa(right, Error) && return right
        left = NumberOperationNode(
            Range(left.position.start_position, right.position.end_position),
            operation_token.value * "",
            left,
            right,
        )
    end
    return left
end

function parse_times_divided_modulo!(parser::Parser)::Union{Node,Error}
    left = parse_power!(parser)
    (isa(left, Error) || parser.current_token.value ∉ ['*', '/', '%']) && return left
    while parser.current_token.value ∈ ['*', '/', '%']
        operation_token = parser.current_token
        advance!(parser)
        right = parse_power!(parser)
        isa(right, Error) && return right
        left = NumberOperationNode(
            Range(left.position.start_position, right.position.end_position),
            operation_token.value * "",
            left,
            right,
        )
    end
    return left
end

function parse_power!(parser::Parser)::Union{Node,Error}
    left = parse_negative!(parser)
    (isa(left, Error) || parser.current_token.value != '^') && return left
    advance!(parser)
    right = parse_power!(parser)
    isa(right, Error) && return right
    return NumberOperationNode(
        Range(left.position.start_position, right.position.end_position),
        "^",
        left,
        right,
    )
end

function parse_negative!(parser::Parser)::Union{Node,Error}
    !(parser.current_token.value == '+' || parser.current_token.value == '-') &&
        return parse_parentheses!(parser)
    operation_token = parser.current_token
    advance!(parser)
    node = parse_negative!(parser)
    isa(node, Error) && return node
    return NumberOperationNode(
        Range(
            operation_token.position.start_position,
            operation_token.position.end_position,
        ),
        operation_token.value * "",
        nothing,
        node,
    )
end

function parse_parentheses!(parser::Parser)::Union{Node,Error}
    parser.current_token.type != LeftParenthesis && return parse_values!(parser)
    advance!(parser)
    node = parse_keywords!(parser)
    (isa(node, Error) || parser.current_token.type != RightParenthesis) &&
        return Error("Expected ')'", parser.scope, parser.current_token.position)
    advance!(parser)
    return node
end

function parse_values!(parser::Parser)::Union{Node,Error}
    parser.current_token.type == Identifier && return parse_identifiers!(parser)
    value_token = parser.current_token
    advance!(parser)
    value_token.type == Character &&
        return CharacterNode(value_token.position, value_token.value)
    value_token.type == Number && return NumberNode(value_token.position, value_token.value)
    value_token.type == Boolean &&
        return BooleanNode(value_token.position, value_token.value)
    return Error("Expected value", parser.scope, parser.current_token.position)
end

function parse_identifiers!(parser::Parser)::Union{Node,Error}
    identifier_token = parser.current_token
    if advance!(parser).type == Equals
        advance!(parser)
        value = parse_keywords!(parser)
        isa(value, Error) && return value
        return VariableNode(
            Range(identifier_token.position.start_position, value.position.end_position),
            identifier_token.value * "",
            value,
        )
    elseif parser.current_token.type == Modification
        operation = parser.current_token.value[1]
        advance!(parser)
        value = parse_keywords!(parser)
        isa(value, Error) && return value
        return ModificationNode(
            Range(identifier_token.position.start_position, value.position.end_position),
            identifier_token.value * "",
            operation,
            value,
        )
    end
    ending_token = identifier_token
    arguments = nothing
    if parser.current_token.type == LeftParenthesis
        arguments = Node[]
        advance!(parser)
        while parser.current_token.type != RightParenthesis
            argument = parse_keywords!(parser)
            isa(argument, Error) && return argument
            push!(arguments, argument)
            parser.current_token.type == EOF &&
                advance!(parser).type == EOL &&
                advance!(parser)
        end
        ending_token = parser.current_token
        advance!(parser)
    end
    return ReferenceNode(
        Range(identifier_token.position.start_position, ending_token.position.end_position),
        identifier_token.value * "",
        arguments,
    )
end
