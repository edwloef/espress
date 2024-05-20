using Match
using Decimals

const LETTERS = (
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'I',
    'J',
    'K',
    'L',
    'M',
    'N',
    'O',
    'P',
    'Q',
    'R',
    'S',
    'T',
    'U',
    'V',
    'W',
    'X',
    'Y',
    'Z',
    'a',
    'b',
    'c',
    'd',
    'e',
    'f',
    'g',
    'h',
    'i',
    'j',
    'k',
    'l',
    'm',
    'n',
    'o',
    'p',
    'q',
    'r',
    's',
    't',
    'u',
    'v',
    'w',
    'x',
    'y',
    'z',
)
const DIGITS = ('0', '1', '2', '3', '4', '5', '6', '7', '8', '9')
const KEYWORDS = (
    "fn",
    "del",
    "return",
    "if",
    "else",
    "loop",
    "break",
    "continue",
    "try",
    "catch",
    "end",
    "print",
    "println",
)

const BOOLEAN_VALUES = ("true", "false")
const LOGICAL_OPERATIONS = ("and", "or", "not")

function get_tokens(lexer::Lexer)::Union{Vector{Token},Error}
    tokens = Token[]
    while !isnothing(lexer.position.current_character)
        @match lexer.position.current_character begin
            '+' || '-' || '*' || '/' || '^' || '%' => begin
                start_position = clone(lexer.position)
                if advance!(lexer.position) == '='
                    push!(
                        tokens,
                        Token(
                            Range(start_position, clone(lexer.position)),
                            Modification,
                            start_position.current_character * "=",
                        ),
                    )
                    advance!(lexer.position)
                else
                    push!(
                        tokens,
                        Token(
                            Range(start_position, start_position),
                            NumberOperation,
                            start_position.current_character,
                        ),
                    )
                end
            end
            '=' || '!' || '<' || '>' => begin
                start_position = clone(lexer.position)
                if advance!(lexer.position) == '='
                    end_position = clone(lexer.position)
                    advance!(lexer.position)
                    push!(
                        tokens,
                        Token(
                            Range(start_position, end_position),
                            Comparison,
                            start_position.current_character * "=",
                        ),
                    )
                elseif start_position.current_character == '='
                    push!(tokens, Token(Range(start_position, start_position), Equals, '='))
                elseif start_position.current_character == '!'
                    return Error(
                        "Unexpected character '!'",
                        lexer.scope,
                        (start_position, start_position),
                    )
                else
                    push!(
                        tokens,
                        Token(
                            Range(start_position, start_position),
                            Comparison,
                            start_position.current_character * "",
                        ),
                    )
                end
            end
            '\'' => begin
                start_position = clone(lexer.position)
                (
                    isnothing(advance!(lexer.position)) ||
                    lexer.position.current_character == '\n'
                ) && return Error(
                    "Expected character",
                    lexer.scope,
                    (lexer.position, lexer.position),
                )
                character::Int = lexer.position.current_character
                advance!(lexer.position) != '\'' && return Error(
                    "Expected '",
                    lexer.scope,
                    (lexer.position, lexer.position),
                )
                end_position = clone(lexer.position)
                advance!(lexer.position)
                push!(
                    tokens,
                    Token(Range(start_position, end_position), Character, character),
                )
            end
            '(' => begin
                push!(
                    tokens,
                    Token(
                        Range(clone(lexer.position), clone(lexer.position)),
                        LeftParenthesis,
                        lexer.position.current_character,
                    ),
                )
                advance!(lexer.position)
            end
            ')' => begin
                push!(
                    tokens,
                    Token(
                        Range(clone(lexer.position), clone(lexer.position)),
                        RightParenthesis,
                        lexer.position.current_character,
                    ),
                )
                advance!(lexer.position)
            end
            '#' => begin
                while !isnothing(advance!(lexer.position)) &&
                          lexer.position.current_character != '\n' &&
                          lexer.position.current_character != '#'
                end
                tokens[end].type != EOL && push!(
                    tokens,
                    Token(
                        Range(clone(lexer.position), clone(lexer.position)),
                        EOL,
                        nothing,
                    ),
                )
                advance!(lexer.position)
            end
            '\n' || ';' => begin
                tokens[end].type != EOL && push!(
                    tokens,
                    Token(
                        Range(clone(lexer.position), clone(lexer.position)),
                        EOL,
                        nothing,
                    ),
                )
                advance!(lexer.position)
            end
            ' ' || '\t' || '\r' => advance!(lexer.position)
            _ => begin
                if lexer.position.current_character ∈ DIGITS
                    start_position = clone(lexer.position)
                    number = lexer.position.current_character * ""
                    decimal = false
                    while advance!(lexer.position) ∈ DIGITS ||
                        lexer.position.current_character == '.'
                        if lexer.position.current_character == '.'
                            decimal && return Error(
                                "Unexpected '.'",
                                lexer.scope,
                                (lexer.position, lexer.position),
                            )
                            decimal = true
                        end
                        number *= lexer.position.current_character
                    end
                    push!(
                        tokens,
                        Token(
                            Range(start_position, clone(lexer.position)),
                            Number,
                            Base.parse(Decimal, number),
                        ),
                    )
                elseif lexer.position.current_character ∈ LETTERS
                    start_position = clone(lexer.position)
                    identifier = start_position.current_character
                    last_position = start_position
                    while advance!(lexer.position) ∈ LETTERS ||
                              lexer.position.current_character ∈ DIGITS ||
                              lexer.position.current_character == '_'
                        identifier *= lexer.position.current_character
                        last_position = clone(lexer.position)
                    end
                    if identifier ∈ BOOLEAN_VALUES
                        push!(
                            tokens,
                            Token(
                                Range(start_position, last_position),
                                Boolean,
                                identifier == "true",
                            ),
                        )
                    elseif identifier ∈ LOGICAL_OPERATIONS
                        push!(
                            tokens,
                            Token(
                                Range(start_position, last_position),
                                LogicalOperation,
                                identifier,
                            ),
                        )
                    elseif identifier ∈ KEYWORDS
                        push!(
                            tokens,
                            Token(
                                Range(start_position, last_position),
                                Keyword,
                                identifier,
                            ),
                        )
                    else
                        push!(
                            tokens,
                            Token(
                                Range(start_position, last_position),
                                Identifier,
                                identifier,
                            ),
                        )
                    end
                else
                    return Error(
                        "Unexpected character '" * lexer.position.current_character * "'",
                        lexer.scope,
                        Range(lexer.position, lexer.position),
                    )
                end
            end
        end
    end
    tokens[end].type != EOL && push!(
        tokens,
        Token(Range(clone(lexer.position), clone(lexer.position)), EOL, nothing),
    )
    push!(tokens, Token(Range(clone(lexer.position), clone(lexer.position)), EOF, nothing))
    return tokens
end
