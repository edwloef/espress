function get(scope::Scope, reference::String, position::Range)::Union{Node,Error}
    result = Base.get(scope.symbol_table, reference, nothing)
    !isnothing(result) && return result
    !isnothing(scope.parent_scope) && return get(scope.parent_scope, reference, position)
    return Error("Can't find variable \"$reference\" in current scope", scope, position)
end

function delete!(scope::Scope, reference::String, position::Range)::Union{Nothing,Error}
    if !isnothing(get(scope.symbol_table, reference, nothing))
        delete!(scope.symbol_table, reference, position)
        return nothing
    end
    !isnothing(scope.parent_scope) && return delete!(scope.parent_scope, Ref, position)
    return Error("Can't find variable \"$reference\" in current scope", scope, position)
end

set!(scope::Scope, reference::String, value::Node) = scope.symbol_table[reference] = value
