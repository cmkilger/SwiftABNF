import Foundation

private struct Repeat: Equatable, Sendable {
    var atLeast: Int?
    var upTo: Int?
    
    private init(atLeast: Int?, upTo: Int?) {
        self.atLeast = atLeast
        self.upTo = upTo
    }
    
    init(string: String) {
        if string.contains("*") {
            let components = string.components(separatedBy: "*").map { Int($0) }
            self.init(atLeast: components[0], upTo: components[1])
        } else {
            let num = Int(string)!
            self.init(atLeast: num, upTo: num)
        }
    }
}

extension ABNF {
    /// Configuration options for parsing ABNF grammar strings.
    ///
    /// ParsingOptions controls how ABNF grammar text is parsed into rule structures,
    /// including handling of newlines, encoding, and format strictness.
    ///
    /// ## Example
    /// ```swift
    /// var options = ABNF.ParsingOptions()
    /// options.allowUnixStyleNewlines = false
    /// options.allowOmittingFinalNewline = false
    /// options.encoding = .unicode
    ///
    /// let abnf = try ABNF(string: grammarText, options: options)
    /// ```
    public struct ParsingOptions: Sendable {
        /// Default parsing options for ABNF grammars.
        ///
        /// Provides lenient defaults: Unix newlines allowed, final newline optional, ASCII encoding.
        public static let defaultOptions = ParsingOptions()
        
        /// Allows `\n` as the end of a line rather than just `\r\n` as required by the ABNF specification.
        ///
        /// When enabled (default), both `\r\n` and `\n` are accepted as line endings in grammar text.
        /// When disabled, only `\r\n` is accepted as per strict ABNF specification.
        ///
        /// - Note: Enabled by default for compatibility with modern text formats.
        public var allowUnixStyleNewlines: Bool = true
        
        /// Allows omitting the final newline in the grammar string.
        ///
        /// When enabled (default), grammar strings don't need to end with a newline character.
        /// When disabled, grammar strings must end with a proper newline as per ABNF specification.
        ///
        /// - Note: Enabled by default for flexibility when parsing grammar fragments.
        public var allowOmittingFinalNewline: Bool = true
        
        /// Specifies the character encoding to use for parsing hex values and quoted strings.
        ///
        /// The grammar string should be encoded using the specified encoding.
        /// This affects the interpretation of hex values and character ranges in quoted strings.
        ///
        /// - Note: Defaults to `.ascii` for compatibility with original ABNF RFCs.
        public var encoding: Encoding = .ascii
        
        /// Creates parsing options with the specified configuration.
        ///
        /// - Parameters:
        ///   - allowUnixStyleNewlines: Whether to accept `\n` as line endings in addition to `\r\n`.
        ///     Defaults to `true` for compatibility with modern text formats.
        ///   - allowOmittingFinalNewline: Whether grammar strings can omit the final newline character.
        ///     Defaults to `true` for flexibility when parsing grammar fragments.
        ///   - encoding: The character encoding to use for parsing hex values and quoted strings.
        ///     Defaults to `.ascii` for compatibility with original ABNF RFCs.
        public init(allowUnixStyleNewlines: Bool = true, allowOmittingFinalNewline: Bool = true, encoding: Encoding = .ascii) {
            self.allowUnixStyleNewlines = allowUnixStyleNewlines
            self.allowOmittingFinalNewline = allowOmittingFinalNewline
            self.encoding = encoding
        }
    }
    
    /// Creates an ABNF grammar by parsing a string containing ABNF rules.
    ///
    /// Parses the provided string as ABNF grammar text and constructs the corresponding
    /// rule structures. The string should contain valid ABNF syntax as defined in RFC 5234.
    ///
    /// - Parameters:
    ///   - string: The ABNF grammar text to parse.
    ///   - options: Parsing options controlling how the grammar is interpreted. Defaults to `.defaultOptions`.
    ///
    /// - Throws: `ParserError` if the grammar string contains syntax errors or is malformed.
    ///
    /// ## Example
    /// ```swift
    /// let grammarText = """
    /// greeting = "hello" SP name
    /// name = 1*ALPHA
    /// """
    ///
    /// let abnf = try ABNF(string: grammarText)
    /// ```
    ///
    /// ## Supported ABNF Constructs
    /// - Rule definitions with `=` and `=/` operators
    /// - String literals with optional case sensitivity (`"text"`, `%s"text"`, `%i"text"`)
    /// - Numeric values in binary (`%b`), decimal (`%d`), and hexadecimal (`%x`) formats
    /// - Repetition with `*`, `n*`, `*n`, `n*m`, and `n` notation
    /// - Alternation with `/` operator
    /// - Concatenation (space-separated elements)
    /// - Optional elements with `[...]` notation
    /// - Grouping with `(...)` notation
    /// - Comments starting with `;`
    public init(string: String, options: ParsingOptions = .defaultOptions) throws {
        var cursor = string.startIndex
        self.init(rules: try Self.parseRuleList(from: string, options: options, cursor: &cursor))
    }
    
    private static func parseRuleList(from input: any StringProtocol, options: ParsingOptions, cursor: inout String.Index) throws -> [Rule] {
        var ruleDict = [String: Element]()
        var ruleOrder = [String]()
        var internalCursor = cursor
        
        if let rule = try? parseRule(from: input, options: options, cursor: &internalCursor) {
            ruleDict[rule.name] = rule.element
            ruleOrder.append(rule.name)
        } else {
            while let cursor = try? parseCWSP(from: input, options: options, cursor: internalCursor) {
                internalCursor = cursor
            }
            internalCursor = try parseCNL(from: input, options: options, cursor: internalCursor)
        }
        
        while internalCursor < input.endIndex {
            var errors = [any Error]()
            do {
                let rule = try parseRule(from: input, options: options, cursor: &internalCursor)
                
                // Combine rules with same name into alternation
                if let existing = ruleDict[rule.name] {
                    if case let .alternating(existingElements) = existing {
                        ruleDict[rule.name] = .alternating(existingElements + [rule.element])
                    } else {
                        ruleDict[rule.name] = .alternating([existing, rule.element])
                    }
                } else {
                    ruleDict[rule.name] = rule.element
                    ruleOrder.append(rule.name)
                }
                continue
            } catch {
                errors.append(error)
            }
            do {
                while let cursor = try? parseCWSP(from: input, options: options, cursor: internalCursor) {
                    internalCursor = cursor
                }
                internalCursor = try parseCNL(from: input, options: options, cursor: internalCursor)
            } catch {
                errors.append(error)
            }
            if errors.count == 2 {
                throw ParserError(message: "Failed to parse rule or comment and whitespace")
            }
        }
        
        cursor = internalCursor
        
        // Convert back to array maintaining order
        return ruleOrder.map { name in
            Rule(name: name, element: ruleDict[name]!)
        }
    }
    
    private static func parseRule(from input: any StringProtocol, options: ParsingOptions, cursor: inout String.Index) throws -> Rule {
        var internalCursor = cursor
        let name = try parseRuleName(from: input, options: options, cursor: &internalCursor)
        _ = try parseDefinedAs(from: input, options: options, cursor: &internalCursor)
        let elements = try parseElements(from: input, options: options, cursor: &internalCursor)
        internalCursor = try parseCNL(from: input, options: options, cursor: internalCursor)
        cursor = internalCursor
        return Rule(name: name, element: elements)
    }
    
    private static let ruleNameRegex = try! NSRegularExpression(pattern: #"^[a-zA-Z][a-zA-Z0-9-]*\b"#, options: [])
    
    private static func parseRuleName(from input: any StringProtocol, options: ParsingOptions, cursor: inout String.Index) throws -> String {
        guard let match = ruleNameRegex.firstMatch(in: String(input), range: NSRange(location: cursor.utf16Offset(in: input), length: input.utf16.count - cursor.utf16Offset(in: input))) else {
            throw ParserError(message: "Not a valid rule name: \(input)")
        }
        let name = input[Range(match.range, in: input)!]
        cursor = input.index(cursor, offsetBy: name.count)
        return String(name)
    }
    
    private static func parseDefinedAs(from input: any StringProtocol, options: ParsingOptions, cursor: inout String.Index) throws {
        var internalCursor = cursor
        while let cursor = try? parseCWSP(from: input, options: options, cursor: internalCursor) {
            internalCursor = cursor
        }
        let slice = input[internalCursor...]
        if slice.hasPrefix("=/") {
            internalCursor = input.index(internalCursor, offsetBy: 2)
        } else if slice.hasPrefix("=") {
            internalCursor = input.index(after: internalCursor)
        } else {
            throw ParserError(message: "Expected '=' or '=/'.")
        }
        while let cursor = try? parseCWSP(from: input, options: options, cursor: internalCursor) {
            internalCursor = cursor
        }
        cursor = internalCursor
    }
    
    private static func parseElements(from input: any StringProtocol, options: ParsingOptions, cursor: inout String.Index) throws -> Element {
        var internalCursor = cursor
        let alternation = try parseAlternation(from: input, options: options, cursor: &internalCursor)
        while let cursor = try? parseCWSP(from: input, options: options, cursor: internalCursor) {
            internalCursor = cursor
        }
        cursor = internalCursor
        return alternation
    }
    
    private static func parseAlternation(from input: any StringProtocol, options: ParsingOptions, cursor: inout String.Index) throws -> Element {
        var concatenations = [try parseConcatenation(from: input, options: options, cursor: &cursor)]
        do {
            while true {
                var internalCursor = cursor
                while let cursor = try? parseCWSP(from: input, options: options, cursor: internalCursor) {
                    internalCursor = cursor
                }
                guard input[internalCursor...].hasPrefix("/") else {
                    throw ParserError(message: "Expected '/' after concatenation.")
                }
                internalCursor = input.index(after: internalCursor)
                while let cursor = try? parseCWSP(from: input, options: options, cursor: internalCursor) {
                    internalCursor = cursor
                }
                concatenations.append(try parseConcatenation(from: input, options: options, cursor: &internalCursor))
                cursor = internalCursor
            }
        } catch {}
        if concatenations.count == 1 {
            return concatenations[0]
        }
        return .alternating(concatenations)
    }
    
    private static func parseElement(from input: any StringProtocol, options: ParsingOptions, cursor: inout String.Index) throws -> Element {
        if let ruleName = try? parseRuleName(from: input, options: options, cursor: &cursor) {
            return .ruleName(ruleName)
        } else if let alternation = try? parseGroup(from: input, options: options, cursor: &cursor) {
            return alternation
        } else if let option = try? parseOption(from: input, options: options, cursor: &cursor) {
            return option
        } else if let charVal = try? parseCharVal(from: input, options: options, cursor: &cursor) {
            return charVal
        } else if let numVal = try? parseNumVal(from: input, options: options, cursor: &cursor) {
            return numVal
        }
        throw ParserError(message: "Not a valid ABNF element")
    }
    
    private static func parseGroup(from input: any StringProtocol, options: ParsingOptions, cursor: inout String.Index) throws -> Element {
        var internalCursor = cursor
        guard input[internalCursor...].hasPrefix("(") else {
            throw ParserError(message: "Not a valid group")
        }
        internalCursor = input.index(after: internalCursor)
        while let cursor = try? parseCWSP(from: input, options: options, cursor: internalCursor) {
            internalCursor = cursor
        }
        let alternation = try parseAlternation(from: input, options: options, cursor: &internalCursor)
        while let cursor = try? parseCWSP(from: input, options: options, cursor: internalCursor) {
            internalCursor = cursor
        }
        guard input[internalCursor...].hasPrefix(")") else {
            throw ParserError(message: "Not a valid group")
        }
        cursor = input.index(after: internalCursor)
        return alternation
    }
    
    private static func parseOption(from input: any StringProtocol, options: ParsingOptions, cursor: inout String.Index) throws -> Element {
        var internalCursor = cursor
        guard input[internalCursor...].hasPrefix("[") else {
            throw ParserError(message: "Not a valid option")
        }
        internalCursor = input.index(after: internalCursor)
        while let cursor = try? parseCWSP(from: input, options: options, cursor: internalCursor) {
            internalCursor = cursor
        }
        let alternation = try parseAlternation(from: input, options: options, cursor: &internalCursor)
        while let cursor = try? parseCWSP(from: input, options: options, cursor: internalCursor) {
            internalCursor = cursor
        }
        guard input[internalCursor...].hasPrefix("]") else {
            throw ParserError(message: "Not a valid option")
        }
        cursor = input.index(after: internalCursor)
        return .optional(alternation)
    }
    
    private static func parseConcatenation(from input: any StringProtocol, options: ParsingOptions, cursor: inout String.Index) throws -> Element {
        var repetitions = [try parseRepetition(from: input, options: options, cursor: &cursor)]
        do {
            while true {
                var internalCursor = try parseCWSP(from: input, options: options, cursor: cursor)
                while let cursor = try? parseCWSP(from: input, options: options, cursor: internalCursor) {
                    internalCursor = cursor
                }
                repetitions.append(try parseRepetition(from: input, options: options, cursor: &internalCursor))
                cursor = internalCursor
            }
        } catch {}
        if repetitions.count == 1 {
            return repetitions[0]
        }
        return .concatenating(repetitions)
    }
    
    private static func parseRepetition(from input: any StringProtocol, options: ParsingOptions, cursor: inout String.Index) throws -> Element {
        var internalCursor = cursor
        let repetition = try? parseRepeat(from: input, options: options, cursor: &internalCursor)
        let element = try parseElement(from: input, options: options, cursor: &internalCursor)
        cursor = internalCursor
        if let repetition {
            return .repeating(element, atLeast: repetition.atLeast, upTo: repetition.upTo)
        }
        return element
    }
    
    private static let repeatRegex = try! NSRegularExpression(pattern: #"^(?:[0-9]*\*[0-9]*|[0-9]+)"#)
    
    private static func parseRepeat(from input: any StringProtocol, options: ParsingOptions, cursor: inout String.Index) throws -> Repeat {
        guard let match = repeatRegex.firstMatch(in: String(input), range: NSRange(location: cursor.utf16Offset(in: input), length: input.utf16.count - cursor.utf16Offset(in: input))) else {
            throw ParserError(message: "Not a valid repeat")
        }
        let string = input[Range(match.range, in: input)!]
        cursor = input.index(cursor, offsetBy: string.count)
        return Repeat(string: String(string))
    }
    
    private static let charValRegexes: [Encoding: NSRegularExpression] = Encoding.allCases.reduce(into: [:]) { dict, encoding in
        dict[encoding] = {
            switch encoding {
            case .ascii:
                try! NSRegularExpression(pattern: #"^"([\u0020\\u0021\u0023-\u007E]*)""#)
            case .latin1:
                try! NSRegularExpression(pattern: #"^"([\u0020\\u0021\u0023-\u007E\u00A0-\u00FF]*)""#)
            case .unicode:
                try! NSRegularExpression(pattern: #"^"([\u0020\\u0021\u0023-\u007E\u00A0-\U0010FFFD]*)""#)
            }
        }()
    }
    
    private static func parseCharVal(from input: any StringProtocol, options: ParsingOptions, cursor: inout String.Index) throws -> Element {
        var internalCursor = cursor
        var caseSensitive = false
        if input[internalCursor...].hasPrefix("%s") {
            caseSensitive = true
            internalCursor = input.index(internalCursor, offsetBy: 2)
        } else if input[internalCursor...].hasPrefix("%i") {
            internalCursor = input.index(internalCursor, offsetBy: 2)
        }
        guard let match = charValRegexes[options.encoding]!.firstMatch(in: String(input), range: NSRange(location: internalCursor.utf16Offset(in: input), length: input.utf16.count - internalCursor.utf16Offset(in: input))) else {
            throw ParserError(message: "Not a valid quoted string")
        }
        let string = input[Range(match.range(at: 1), in: input)!]
        cursor = input.index(internalCursor, offsetBy: string.count + 2)
        return .string(String(string), caseSensitive: caseSensitive)
    }
    
    private static func parseNumVal(from input: any StringProtocol, options: ParsingOptions, cursor: inout String.Index) throws -> Element {
        var internalCursor = cursor
        guard input[internalCursor...].hasPrefix("%") else {
            throw ParserError(message: "Not a valid numeric value")
        }
        internalCursor = input.index(after: internalCursor)
        if let binVal = binParse(from: input, options: options, cursor: &internalCursor) {
            cursor = internalCursor
            return binVal
        } else if let decVal = decParse(from: input, options: options, cursor: &internalCursor) {
            cursor = internalCursor
            return decVal
        } else if let hexVal = hexParse(from: input, options: options, cursor: &internalCursor) {
            cursor = internalCursor
            return hexVal
        }
        throw ParserError(message: "Not a valid numeric value")
    }
    
    private static func numValue(string: any StringProtocol, numericType: Element.NumericType) -> Element {
        let radix = numericType.radix
        if string.contains(".") {
            return .numericSeries(string.split(separator: ".").map { UInt32($0, radix: radix)! }, type: numericType)
        } else if string.contains("-") {
            let components = string.split(separator: "-").map { UInt32($0, radix: radix)! }
            return .numericRange(min: components[0], max: components[1], type: numericType)
        }
        return .numeric(UInt32(string, radix: radix)!, type: numericType)
    }
    
    private static let binRegex = try! NSRegularExpression(pattern: #"^b([01]+(?:(?:\.[01]+)+|-[01]+)?)"#, options: [])
    
    private static func binParse(from input: any StringProtocol, options: ParsingOptions, cursor: inout String.Index) -> Element? {
        guard let match = binRegex.firstMatch(in: String(input), range: NSRange(location: cursor.utf16Offset(in: input), length: input.utf16.count - cursor.utf16Offset(in: input))) else {
            return nil
        }
        let string = input[Range(match.range(at: 1), in: input)!]
        cursor = input.index(cursor, offsetBy: match.range.length)
        return numValue(string: string, numericType: .binary)
    }
    
    private static let decRegex = try! NSRegularExpression(pattern: #"^d([0-9]+(?:(?:\.[0-9]+)+|-[0-9]+)?)"#, options: [])
    
    private static func decParse(from input: any StringProtocol, options: ParsingOptions, cursor: inout String.Index) -> Element? {
        guard let match = decRegex.firstMatch(in: String(input), range: NSRange(location: cursor.utf16Offset(in: input), length: input.utf16.count - cursor.utf16Offset(in: input))) else {
            return nil
        }
        let string = input[Range(match.range(at: 1), in: input)!]
        cursor = input.index(cursor, offsetBy: match.range.length)
        return numValue(string: string, numericType: .decimal)
    }
    
    private static let hexRegex = try! NSRegularExpression(pattern: #"^x([0-9A-F]+(?:(?:\.[0-9A-F]+)+|-[0-9A-F]+)?)"#, options: [])
    
    private static func hexParse(from input: any StringProtocol, options: ParsingOptions, cursor: inout String.Index) -> Element? {
        guard let match = hexRegex.firstMatch(in: String(input), range: NSRange(location: cursor.utf16Offset(in: input), length: input.utf16.count - cursor.utf16Offset(in: input))) else {
            return nil
        }
        let string = input[Range(match.range(at: 1), in: input)!]
        cursor = input.index(cursor, offsetBy: match.range.length)
        return numValue(string: string, numericType: .hexadecimal)
    }
    
    private static func parseCNL(from input: any StringProtocol, options: ParsingOptions, cursor: String.Index) throws -> String.Index {
        if let cursor = try? parseComment(from: input, options: options, cursor: cursor) {
            return cursor
        } else if let cursor = try? parseCRLF(from: input, options: options, cursor: cursor) {
            return cursor
        }
        throw ParserError(message: "Not a valid CNL")
    }
    
    private static func parseCWSP(from input: any StringProtocol, options: ParsingOptions, cursor: String.Index) throws -> String.Index {
        if let cursor = try? parseWSP(from: input, options: options, cursor: cursor) {
            return cursor
        } else if let cursor = try? parseCNL(from: input, options: options, cursor: cursor), let cursor = try? parseWSP(from: input, options: options, cursor: cursor) {
            return cursor
        }
        throw ParserError(message: "Not a valid CWSP")
    }
    
    private static func parseComment(from input: any StringProtocol, options: ParsingOptions, cursor: String.Index) throws -> String.Index {
        var internalCursor = cursor
        guard input[internalCursor...].hasPrefix(";") else {
            throw ParserError(message: "Not a valid comment")
        }
        internalCursor = input.index(internalCursor, offsetBy: 1)
        while true {
            if let cursor = try? parseWSP(from: input, options: options, cursor: internalCursor) {
                internalCursor = cursor
            } else if let cursor = try? parseVChar(from: input, options: options, cursor: internalCursor) {
                internalCursor = cursor
            } else {
                break
            }
        }
        return try parseCRLF(from: input, options: options, cursor: internalCursor)
    }
    
    private static let visibleCharacterSets: [Encoding: CharacterSet] = Encoding.allCases.reduce(into: [:]) { dict, encoding in
        dict[encoding] = {
            switch encoding {
            case .ascii:
                return CharacterSet(charactersIn: "\u{21}"..."\u{7E}")
            case .latin1:
                return CharacterSet(charactersIn: "\u{21}"..."\u{7E}").union(CharacterSet(charactersIn: "\u{A0}"..."\u{FF}"))
            case .unicode:
                return CharacterSet(charactersIn: "\u{21}"..."\u{7E}").union(CharacterSet(charactersIn: "\u{A0}"..."\u{10FFFD}"))
            }
        }()
    }
    
    private static func parseVChar(from input: any StringProtocol, options: ParsingOptions, cursor: String.Index) throws -> String.Index {
        let unicodeScalars = String(input).unicodeScalars
        guard cursor < unicodeScalars.endIndex else {
            throw ParserError(message: "End of file")
        }
        let character = unicodeScalars[cursor]
        guard visibleCharacterSets[options.encoding]!.contains(character) else {
            throw ParserError(message: "Not a valid VCHAR")
        }
        return unicodeScalars.index(after: cursor)
    }
    
    private static func parseWSP(from input: any StringProtocol, options: ParsingOptions, cursor: String.Index) throws -> String.Index {
        if input[cursor...].hasPrefix(" ") {
            return input.index(after: cursor)
        } else if input[cursor...].hasPrefix("\t") {
            return input.index(after: cursor)
        }
        throw ParserError(message: "Not a valid WSP")
    }
    
    private static func parseCRLF(from input: any StringProtocol, options: ParsingOptions, cursor: String.Index) throws -> String.Index {
        guard input[cursor...].hasPrefix("\r\n") || options.allowUnixStyleNewlines && input[cursor...].hasPrefix("\n") || options.allowOmittingFinalNewline && input[cursor...].isEmpty else {
            throw ParserError(message: "Not a valid CRLF")
        }
        var internalCursor = cursor
        if !input[cursor...].isEmpty {
            internalCursor = input.index(after: cursor)
        }
        return internalCursor
    }
}
