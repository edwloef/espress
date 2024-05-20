using Match
import Base.^

function interpret(nodes::Vector{Node}, scope::Scope)
    for node ∈ nodes
        result = interpret(node, scope)
        isa(result, Error) && return result
    end
    return NoneNode(nodes[1].position)
end

function interpret(node::ReferenceNode, scope::Scope)::Union{Node,Error}
    value = get(scope, node.name, node.position)
    isa(value, Error) && return value
    if isnothing(node.arguments)
        return interpret(value, scope)
    end
    if length(value.arguments) == length(node.arguments)
        function_scope = Scope(scope, Dict{String,Node}(), 0)
        for (name, val) ∈ zip(value.arguments, node.arguments)
            argument_value = interpret(val, scope)
            isa(argument_value, Error) && return argument_value
            set!(function_scope, name.name, val)
        end
        return interpret(value.actions, function_scope)
    end
    return Error(
        "Too $(length(value.arguments) < length(node.arguments) ? "many" : "few") arguments given.",
        scope,
        node.position,
    )
end

function interpret(node::VariableNode, scope::Scope)::Union{Node,Error}
    value = interpret(node.value, scope)
    isa(value, Error) && return value
    set!(scope, node.name, value)
    return value
end

function interpret(node::ModificationNode, scope::Scope)::Union{Node,Error}
    value = interpret(node.value, scope)
    isa(value, Error) && return value
    left = get(scope, node.name, node.position)
    isa(left, Error) && return left
    new_value = NumberNode(value.position, @match node.type begin
        '+' => left.value + value.value
        '-' => left.value - value.value
        '*' => left.value * value.value
        '/' => left.value / value.value
        '%' => left.value % value.value
        '^' => left.value^value.value
        _ => value.value
    end)
    set!(scope, node.name, new_value)
    return new_value
end

function interpret(node::FunctionNode, scope::Scope)::Union{Node,Error}
    set!(scope, node.name, node)
end

function interpret(node::DeletionNode, scope::Scope)::Union{Nothing,Error}
    return delete!(scope, node.name, node.position)
end

function interpret(node::ActionsNode, scope::Scope)::Union{Node,Error}
    for action ∈ node.actions
        result = interpret(action, scope)
        if isa(result, Error) ||
           isa(result, ReturnNode) ||
           isa(result, BreakNode) ||
           isa(result, ContinueNode)
            return result
        end
    end
    return NoneNode(node.position)
end

function interpret(node::IfNode, scope::Scope)::Union{Node,Error}
    condition = interpret(node.condition, scope)
    if isa(condition, Error)
        return condition
    elseif !isa(condition, BooleanNode)
        return Error("Expected boolean condition!", scope, node.condition.position)
    elseif condition.value
        return interpret(node.if_node, scope)
    end
    isnothing(node.else_node) && return NoneNode(node.position)
    return interpret(node.else_node, scope)
end

function interpret(node::LoopNode, scope::Scope)::Union{Node,Error}
    scope.loops += 1
    while true
        for action ∈ node.actions
            result = interpret(action, scope)
            if isa(result, Error) || isa(result, ReturnNode)
                scope.loops -= 1
                return result
            elseif isa(result, BreakNode)
                scope.loops -= 1
                return NoneNode(node.position)
            end
            isa(result, ContinueNode) && break
        end
    end
end

function interpret(node::BreakNode, scope::Scope)::Union{Node,Error}
    scope.loops > 0 && return node
    return Error("\"break\" can only be used in a loop!", scope, node.position)
end

function interpret(node::ContinueNode, scope::Scope)::Union{Node,Error}
    scope.loops > 0 && return node
    return Error("\"continue\" can only be used in a loop!", scope, node.position)
end

function interpret(node::TryNode, scope::Scope)::Union{Node,Error}
    try_block = interpret(node.try_node, scope)
    if isa(try_block, Error)
        if !isnothing(node.catch_node)
            catch_block = interpret(node.catch_node, scope)
            return catch_block
        end
        return NoneNode(node.position)
    end
    return try_block
end

function interpret(node::ReturnNode, scope::Scope)::Union{Node,Error}
    result = interpret(node.value, scope)
    isa(result, Error) || isa(result, ReturnNode) && return result
    return ReturnNode(node.position, result)
end

function interpret(node::BuiltinNode, scope::Scope)::Union{Node,Error}
    value = interpret(node.value, scope)
    isa(value, Error) && return value
    if (node.name == "print")
        print(str(value))
    elseif (node.name == "println")
        println(str(value))
    else
        @assert false
    end
    return value
end

function interpret(node::NumberOperationNode, scope::Scope)::Union{Node,Error}
    right = interpret(node.right, scope)
    isa(right, Error) && return right
    if isnothing(node.left)
        if node.operation == "-"
            return NumberNode(node.position, -1 * right.value)
        end
        return Error("Unsupported operation '$(node.operation)'", scope, node.position)
    end
    left = interpret(node.left, scope)
    isa(left, Error) && return left
    if !isa(left, NumericalValueNode) || !isa(right, NumericalValueNode)
        return Error("Unsupported operation '$(node.operation)'", scope, node.position)
    end
    if isa(left, CharacterNode) || isa(right, CharacterNode)
        return CharacterNode(
            Range(left.position.start_position, right.position.end_position),
            @match node.operation begin
                "+" => (left.value + right.value)
                "-" => (left.value - right.value)
                "*" => (left.value * right.value)
                "/" => (left.value / right.value)
                "%" => (left.value % right.value)
                "^" => (left.value^right.value)
                _ => @assert false
            end
        )
    end
    return NumberNode(
        Range(left.position.start_position, right.position.end_position),
        @match node.operation begin
            "+" => (left.value + right.value)
            "-" => (left.value - right.value)
            "*" => (left.value * right.value)
            "/" => (left.value / right.value)
            "%" => (left.value % right.value)
            "^" => (left.value^right.value)
            _ => @assert false
        end
    )
end

function interpret(node::LogicalOperationNode, scope::Scope)::Union{Node,Error}
    left = interpret(node.left, scope)
    isa(left, Error) && return left
    right = interpret(node.right, scope)
    isa(right, Error) && return right
    if !isa(left, BooleanNode) || !isa(right, BooleanNode)
        return Error("Unsupported operation '$(node.operation)'", scope, node.position)
    end
    return BooleanNode(
        Range(left.position.start_position, right.position.end_position),
        @match node.operation begin
            "and" => (left.value && right.value)
            "or" => (left.value || right.value)
            _ => @assert false
        end
    )
end

function interpret(node::ComparisonNode, scope::Scope)::Union{Node,Error}
    left = interpret(node.left, scope)
    isa(left, Error) && return left
    right = interpret(node.right, scope)
    isa(right, Error) && return right
    node.operation == "==" && return BooleanNode(node.position, left.value == right.value)
    node.operation == "!=" && return BooleanNode(node.position, left.value != right.value)
    if !isa(left, NumericalValueNode) || !isa(right, NumericalValueNode)
        return Error("Unsupported operation '$(node.operation)'", scope, node.position)
    end
    @match node.operation begin
        ">" => return BooleanNode(node.position, left.value > right.value)
        ">=" => return BooleanNode(node.position, left.value >= right.value)
        "<" => return BooleanNode(node.position, left.value < right.value)
        "<=" => return BooleanNode(node.position, left.value <= right.value)
        _ => @assert false
    end
end

interpret(node, scope) = node

#####################################################
# https://github.com/JuliaMath/Decimals.jl/issues/2 #
#####################################################

^(x::Decimal, y::Decimal)::Decimal = Decimal(BigFloat(x)^BigFloat(y))
