using Decimals

struct ReferenceNode <: Node
    position::Range
    name::String
    arguments::Union{Vector{Node},Nothing}
end

struct VariableNode <: Node
    position::Range
    name::String
    value::Node
end

struct ModificationNode <: Node
    position::Range
    name::String
    type::Char
    value::Node
end

struct FunctionNode <: Node
    position::Range
    name::String
    arguments::Vector{ReferenceNode}
    actions::Vector{Node}
end

struct DeletionNode <: Node
    position::Range
    name::String
end

struct ActionsNode <: Node
    position::Range
    actions::Vector{Node}
end

struct IfNode <: Node
    position::Range
    condition::Node
    if_node::ActionsNode
    else_node::Union{ActionsNode,Nothing}
end

struct LoopNode <: Node
    position::Range
    actions::Vector{Node}
end

struct BreakNode <: Node
    position::Range
end

struct ContinueNode <: Node
    position::Range
end

struct TryNode <: Node
    position::Range
    try_node::ActionsNode
    catch_node::Union{ActionsNode,Nothing}
end

struct ReturnNode <: Node
    position::Range
    value::Node
end

struct BuiltinNode <: Node
    position::Range
    name::String
    value::Node
end

struct NumberOperationNode <: Node
    position::Range
    operation::String
    left::Union{Node,Nothing}
    right::Node
end

struct LogicalOperationNode <: Node
    position::Range
    operation::String
    left::Union{Node,Nothing}
    right::Node
end

struct ComparisonNode <: Node
    position::Range
    operation::String
    left::Node
    right::Node
end

abstract type NumericalValueNode <: Node end

struct NumberNode <: NumericalValueNode
    position::Range
    value::Decimal
end

struct CharacterNode <: NumericalValueNode
    position::Range
    value::Decimal
end

struct BooleanNode <: Node
    position::Range
    value::Bool
end

struct NoneNode <: Node
    position::Range
end

function str(node::NumberNode)::String
    return string(node.value)
end

function str(node::BooleanNode)::String
    return string(node.value)
end

function str(node::CharacterNode)::String
    return string(convert(Char, trunc(node.value)))
end

function str(node::Node)::String
    return ""
end
