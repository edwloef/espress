mutable struct Position
    file::String
    code::Vector{String}
    line::Int
    position::Int
    current_character::Union{Char,Nothing}
end

struct Range
    start_position::Position
    end_position::Position
end

function Base.show(io::Core.IO, range::Range) end

@enum TokenType Identifier Keyword Equals Modification NumberOperation LogicalOperation Comparison Number Boolean Character LeftParenthesis RightParenthesis EOL EOF

struct Token{T}
    position::Range
    type::TokenType
    value::T
end

abstract type Node end

mutable struct Scope
    parent_scope::Union{Scope,Nothing}
    symbol_table::Dict{String,Node}
    loops::Int
end

struct Error
    details::String
    scope::Scope
    position::Range
end

struct Lexer
    scope::Scope
    position::Position
end

mutable struct Parser
    scope::Scope
    tokens::Vector{Token}
    current_token::Token
    index::Int
end
