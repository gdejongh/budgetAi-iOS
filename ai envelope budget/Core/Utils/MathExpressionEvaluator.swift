import Foundation

/// Safely evaluates a simple arithmetic expression string (no parentheses).
/// Supports +, -, *, / with standard operator precedence.
/// Strips $ and , characters before evaluation.
/// Returns the result rounded to 2 decimal places, or nil for invalid input.
///
/// Examples:
///   "5+10"       → 15
///   "5+10*2"     → 25   (standard precedence)
///   "$1,000+500" → 1500
///   "100/3"      → 33.33
///   ""           → nil
///   "5+"         → nil
///   "10/0"       → nil
///   "abc"        → nil
func evaluateMathExpression(_ input: String) -> Decimal? {
    // Strip currency symbols, commas, and whitespace
    let cleaned = input
        .replacingOccurrences(of: "$", with: "")
        .replacingOccurrences(of: ",", with: "")
        .replacingOccurrences(of: " ", with: "")

    guard !cleaned.isEmpty else { return nil }

    // Tokenize
    guard let tokens = tokenize(cleaned) else { return nil }

    // Evaluate with standard precedence
    guard let result = evaluate(tokens) else { return nil }

    // Round to 2 decimal places
    var rounded = result
    var original = result
    NSDecimalRound(&rounded, &original, 2, .bankers)
    return rounded
}

// MARK: - Token

private enum Token {
    case number(Decimal)
    case op(Character)
}

// MARK: - Tokenizer

private func tokenize(_ expr: String) -> [Token]? {
    var tokens: [Token] = []
    var chars = Array(expr)
    var i = 0

    while i < chars.count {
        let ch = chars[i]

        // Check for a number (possibly with leading minus for negative)
        let isLeadingNegative = ch == "-" && (tokens.isEmpty || {
            if case .op = tokens.last { return true }
            return false
        }())

        if ch.isNumber || ch == "." || isLeadingNegative {
            var numStr = ""
            if ch == "-" {
                numStr.append("-")
                i += 1
            }
            guard i < chars.count, chars[i].isNumber || chars[i] == "." else {
                return nil // trailing minus with no digit
            }
            var dotCount = 0
            while i < chars.count, chars[i].isNumber || chars[i] == "." {
                if chars[i] == "." { dotCount += 1 }
                if dotCount > 1 { return nil }
                numStr.append(chars[i])
                i += 1
            }
            guard let num = Decimal(string: numStr) else { return nil }
            tokens.append(.number(num))

        } else if isOperator(ch) {
            // Operator must follow a number
            guard !tokens.isEmpty, case .number = tokens.last else { return nil }
            tokens.append(.op(ch))
            i += 1

        } else {
            return nil // invalid character
        }
    }

    // Must end with a number
    guard !tokens.isEmpty, case .number = tokens.last else { return nil }
    return tokens
}

// MARK: - Evaluator

private func evaluate(_ tokens: [Token]) -> Decimal? {
    // First pass: resolve * and /
    var simplified: [Token] = []
    var i = 0

    while i < tokens.count {
        if case .op(let op) = tokens[i], op == "*" || op == "/" {
            guard case .number(let left) = simplified.last,
                  i + 1 < tokens.count,
                  case .number(let right) = tokens[i + 1] else { return nil }

            simplified.removeLast()

            if op == "*" {
                simplified.append(.number(left * right))
            } else {
                guard right != 0 else { return nil } // division by zero
                simplified.append(.number(left / right))
            }
            i += 2
        } else {
            simplified.append(tokens[i])
            i += 1
        }
    }

    // Second pass: resolve + and -
    guard case .number(var result) = simplified.first else { return nil }
    var j = 1
    while j < simplified.count {
        guard case .op(let op) = simplified[j],
              j + 1 < simplified.count,
              case .number(let val) = simplified[j + 1] else { return nil }

        if op == "+" {
            result += val
        } else if op == "-" {
            result -= val
        } else {
            return nil
        }
        j += 2
    }

    return result
}

// MARK: - Helpers

private func isOperator(_ ch: Character) -> Bool {
    ch == "+" || ch == "-" || ch == "*" || ch == "/"
}
