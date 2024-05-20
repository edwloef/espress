function advance!(position::Position)::Union{Char,Nothing}
    if position.position >= length(position.code[position.line])
        if position.line >= length(position.code)
            position.current_character = nothing
        else
            position.line += 1
            position.position = 0
            position.current_character = '\n'
        end
    else
        position.position += 1
        position.current_character = position.code[position.line][position.position]
    end
    return position.current_character
end

function clone(position::Position)::Position
    return Position(
        position.file,
        position.code,
        position.line,
        position.position,
        position.current_character,
    )
end
