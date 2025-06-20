import Foundation

extension ABNF {
    /// Configuration options for ABNF validation operations.
    ///
    /// ValidationOptions allows customization of how input strings are validated against
    /// ABNF grammars, including encoding support and newline handling.
    ///
    /// ## Example
    /// ```swift
    /// var options = ABNF.ValidationOptions()
    /// options.encoding = .unicode
    /// options.allowUnixStyleNewlines = false
    ///
    /// try abnf.validate(string: "test input", options: options)
    /// ```
    public struct ValidationOptions: Sendable {
        /// Default validation options for ABNF.
        ///
        /// Provides sensible defaults: ASCII encoding with Unix-style newlines allowed.
        public static let defaultOptions = ValidationOptions()
        
        /// Allows `\n` as the end of a line rather than just `\r\n` as required by the ABNF specification.
        ///
        /// When enabled (default), both `\r\n` and `\n` are accepted as line endings.
        /// When disabled, only `\r\n` is accepted as per strict ABNF specification.
        ///
        /// - Note: This is enabled by default for maximum compatibility with modern text formats.
        public var allowUnixStyleNewlines: Bool = true
        
        /// Specifies the character encoding to use for parsing numeric values and quoted strings.
        ///
        /// The input string being validated should match the specified encoding.
        /// Different encodings affect the range of acceptable characters and how
        /// numeric values are interpreted.
        ///
        /// - Note: Defaults to `.ascii` for compatibility with original ABNF RFCs.
        public var encoding: Encoding = .ascii
        
        /// Creates validation options with the specified configuration.
        ///
        /// - Parameters:
        ///   - allowUnixStyleNewlines: Whether to accept `\n` as line endings in addition to `\r\n`.
        ///     Defaults to `true` for maximum compatibility with modern text formats.
        ///   - encoding: The character encoding to use for parsing numeric values and quoted strings.
        ///     Defaults to `.ascii` for compatibility with original ABNF RFCs.
        public init(allowUnixStyleNewlines: Bool = true, encoding: Encoding = .ascii) {
            self.allowUnixStyleNewlines = allowUnixStyleNewlines
            self.encoding = encoding
        }
    }
    
    private static let coreRules: [ABNF.Encoding: [Bool: [String: Element]]] = ABNF.Encoding.allCases.reduce(into: [:]) { dict, encoding in
        for allowUnixStyleNewlines in [true, false] {
            dict[encoding, default: [:]][allowUnixStyleNewlines] = [
                "ALPHA": .alternating([
                    .hexadecimal(min: 0x41, max: 0x5a), // A-Z
                    .hexadecimal(min: 0x61, max: 0x7a), // a-z
                ]),
                "BIT": .alternating([
                    .string("0"),
                    .string("1"),
                ]),
                "CHAR": .hexadecimal(min: 0x01, max: 0x7f),
                "CR": .hexadecimal(0x0d),
                "CRLF": {
                    if allowUnixStyleNewlines {
                        return .alternating([
                            .concatenating([
                                .ruleName("CR"),
                                .ruleName("LF"),
                            ]),
                            .ruleName("CR"),
                            .ruleName("LF"),
                        ])
                    } else {
                        return .concatenating([
                            .ruleName("CR"),
                            .ruleName("LF"),
                        ])
                    }
                }(),
                "CTL": .alternating([
                    .hexadecimal(min: 0x00, max: 0x1f),
                    .hexadecimal(0x7f),
                ]),
                "DIGIT": .hexadecimal(min: 0x30, max: 0x39),
                "DQUOTE": .hexadecimal(0x22),
                "HEXDIG": .alternating([
                    .ruleName("DIGIT"),
                    .string("A"),
                    .string("B"),
                    .string("C"),
                    .string("D"),
                    .string("E"),
                    .string("F"),
                ]),
                "HTAB": .hexadecimal(0x09),
                "LF": .hexadecimal(0x0a),
                "LWSP": .repeating(.alternating([
                    .ruleName("WSP"),
                    .concatenating([
                        .ruleName("CRLF"),
                        .ruleName("WSP"),
                    ]),
                ])),
                "OCTET": .hexadecimal(min: 0x00, max: 0xff),
                "SP": .hexadecimal(0x20),
                "VCHAR": {
                    switch encoding {
                    case .ascii:
                        return .hexadecimal(min: 0x21, max: 0x7e)
                    case .latin1:
                        return .alternating([
                            .hexadecimal(min: 0x21, max: 0x7e),
                            .hexadecimal(min: 0xa0, max: 0xff),
                        ])
                    case .unicode:
                        return .alternating([
                            .hexadecimal(min: 0x21, max: 0x7e),
                            .hexadecimal(min: 0xa0, max: 0x10fffd),
                        ])
                    }
                }(),
                "WSP": .alternating([
                    .ruleName("SP"),
                    .ruleName("HTAB"),
                ]),
            ]
        }
    }
    
    /// Validates an input string against a specific rule in the grammar.
    ///
    /// Performs complete validation of the input string, ensuring it fully matches
    /// the specified rule. Returns a detailed parse tree showing how the input
    /// was matched against the grammar.
    ///
    /// - Parameters:
    ///   - string: The input string to validate.
    ///   - ruleName: The name of the rule to validate against. If nil, uses the first rule in the grammar.
    ///   - options: Validation options including encoding and newline handling. Defaults to `.defaultOptions`.
    ///
    /// - Returns: A `ValidationResult` containing the parse tree and position information.
    ///
    /// - Throws:
    ///   - `ValidationError` if the input doesn't match the rule or if the rule is not found.
    ///   - `ErrorCollection` if multiple validation paths fail.
    ///
    /// ## Example
    /// ```swift
    /// let abnf = try ABNF(string: "greeting = \"hello\" SP name\nname = 1*ALPHA")
    /// let result = try abnf.validate(string: "hello world", ruleName: "greeting")
    /// print("Matched: '\(result.parseTree.matchedText)'")
    /// ```
    ///
    /// - Note: The input must completely match the rule. Partial matches will result in a validation error.
    @discardableResult public func validate(string: String, ruleName: String? = nil, options: ABNF.ValidationOptions = .defaultOptions) throws -> ValidationResult {
        guard let ruleName = ruleName ?? rules.first?.name else {
            throw ValidationError(index: string.startIndex, message: "No rule specified for validation")
        }
        
        let coreRules = ABNF.coreRules[options.encoding]![options.allowUnixStyleNewlines]!
        // Parser has already handled rule merging properly, just convert to dictionary
        let userRules = self.rules.reduce(into: [:]) { $0[$1.name] = $1.element }
        let rules = coreRules.merging(userRules) { $1 }
        guard rules[ruleName] != nil else {
            throw ValidationError(index: string.startIndex, message: "Rule '\(ruleName)' not found")
        }
        
        let results = try ABNF.validate(element: .ruleName(ruleName), input: string, startPosition: string.startIndex, rules: rules)
        guard let fullMatch = results.first(where: { $0.endIndex == string.endIndex }) else {
            throw ValidationError(index: string.startIndex, message: "Input does not fully match rule '\(ruleName)'")
        }
        
        return fullMatch
    }
    
    private static func validate(element: Element, input: any StringProtocol, startPosition: String.Index, rules: [String: Element]) throws -> [ValidationResult] {
        // Memo table for Packrat memoization: (element hash, position offset) -> Result
        var memo: [String: Result<[ValidationResult], any Error>] = [:]
        var errors: [any Error] = []
        
        func memoKey(element: Element, position: String.Index) -> String {
            let offset = input.distance(from: input.startIndex, to: position)
            // Create a more detailed key to avoid conflicts in complex grammars
            let elementHash = String(String(describing: element).hashValue)
            return "\(elementHash)_\(offset)"
        }
        
        func validateElement(element: Element, position: String.Index) throws -> [ValidationResult] {
            let key = memoKey(element: element, position: position)
            
            // Check memo table first
            if let cached = memo[key] {
                switch cached {
                case .success(let results): return results
                case .failure(let error): throw error
                }
            }
            
            // Validate element and memoize result
            let result: Result<[ValidationResult], any Error>
            do {
                let results = try validateElementImpl(element: element, position: position)
                result = .success(results)
                memo[key] = result
                return results
            } catch {
                result = .failure(error)
                memo[key] = result
                throw error
            }
        }
        
        func validateElementImpl(element: Element, position: String.Index) throws -> [ValidationResult] {
            guard position <= input.endIndex else {
                let error = ValidationError(index: position, message: "Unexpected end of input")
                errors.append(error)
                throw error
            }
            
            switch element {
            case .ruleName(let name):
                guard let ruleElement = rules[name] else {
                    let error = ValidationError(index: position, message: "Unknown rule: \(name)")
                    errors.append(error)
                    throw error
                }
                let results = try validateElement(element: ruleElement, position: position)
                return results.map { result in
                    ValidationResult(
                        element: .ruleName(name),
                        startIndex: result.startIndex,
                        endIndex: result.endIndex,
                        children: [result],
                        matchedText: result.matchedText
                    )
                }
                
            case .string(let str, let caseSensitive):
                guard str.count > 0 else {
                    let error = ValidationError(index: position, message: "Empty string pattern")
                    errors.append(error)
                    throw error
                }
                
                let endPos = input.index(position, offsetBy: str.count, limitedBy: input.endIndex) ?? input.endIndex
                guard input.distance(from: position, to: endPos) >= str.count else {
                    let error = ValidationError(index: position, message: "String '\(str)' extends beyond input")
                    errors.append(error)
                    throw error
                }
                
                let slice = input[position..<endPos]
                let substr = String(slice)
                let matches = caseSensitive ? substr == str : substr.lowercased() == str.lowercased()
                
                if matches {
                    return [ValidationResult(
                        element: element,
                        startIndex: position,
                        endIndex: endPos,
                        matchedText: substr
                    )]
                } else {
                    let error = ValidationError(index: position, message: "Expected '\(str)', found '\(substr)'")
                    errors.append(error)
                    throw error
                }
                
            case .numeric(let value, _):
                guard position < input.endIndex else {
                    let error = ValidationError(index: position, message: "Expected character with value \(value)")
                    errors.append(error)
                    throw error
                }
                
                let char = input[position]
                let scalar = char.unicodeScalars.first?.value ?? 0
                
                if UInt32(scalar) == value {
                    let endPos = input.index(after: position)
                    return [ValidationResult(
                        element: element,
                        startIndex: position,
                        endIndex: endPos,
                        matchedText: String(char)
                    )]
                } else {
                    let error = ValidationError(index: position, message: "Expected character with value \(value), found \(scalar)")
                    errors.append(error)
                    throw error
                }
                
            case .numericSeries(let values, _):
                var currentPos = position
                var matchedText = ""
                
                for value in values {
                    guard currentPos < input.endIndex else {
                        let error = ValidationError(index: currentPos, message: "Expected character with value \(value)")
                        errors.append(error)
                        throw error
                    }
                    
                    let char = input[currentPos]
                    let scalar = char.unicodeScalars.first?.value ?? 0
                    
                    if UInt32(scalar) == value {
                        matchedText.append(char)
                        currentPos = input.index(after: currentPos)
                    } else {
                        let error = ValidationError(index: currentPos, message: "Expected character with value \(value), found \(scalar)")
                        errors.append(error)
                        throw error
                    }
                }
                
                return [ValidationResult(
                    element: element,
                    startIndex: position,
                    endIndex: currentPos,
                    matchedText: matchedText
                )]
                
            case .numericRange(let min, let max, _):
                guard position < input.endIndex else {
                    let error = ValidationError(index: position, message: "Expected character in range \(min)-\(max)")
                    errors.append(error)
                    throw error
                }
                
                let char = input[position]
                let scalar = char.unicodeScalars.first?.value ?? 0
                
                
                if UInt32(scalar) >= min && UInt32(scalar) <= max {
                    let endPos = input.index(after: position)
                    return [ValidationResult(
                        element: element,
                        startIndex: position,
                        endIndex: endPos,
                        matchedText: String(char)
                    )]
                } else {
                    let error = ValidationError(index: position, message: "Expected character in range \(min)-\(max), found \(scalar)")
                    errors.append(error)
                    throw error
                }
                
            case .alternating(let alternatives):
                var alternativeErrors: [any Error] = []
                var allResults: [ValidationResult] = []
                
                for alternative in alternatives {
                    do {
                        let results = try validateElement(element: alternative, position: position)
                        let wrappedResults = results.map { result in
                            ValidationResult(
                                element: element,
                                startIndex: result.startIndex,
                                endIndex: result.endIndex,
                                children: [result],
                                matchedText: result.matchedText
                            )
                        }
                        allResults.append(contentsOf: wrappedResults)
                    } catch {
                        alternativeErrors.append(error)
                    }
                }
                
                if !allResults.isEmpty {
                    // Sort results by length of matched text (longer matches first)
                    allResults.sort { first, second in
                        first.matchedText.count > second.matchedText.count
                    }
                    return allResults
                }
                
                let error = ErrorCollection(errors: alternativeErrors)
                errors.append(error)
                throw error
                
            case .concatenating(let components):
                func tryValidateConcatenation(componentIndex: Int, currentPos: String.Index, childResults: [ValidationResult], matchedText: String) throws -> [ValidationResult] {
                    if componentIndex >= components.count {
                        return [ValidationResult(
                            element: element,
                            startIndex: position,
                            endIndex: currentPos,
                            children: childResults,
                            matchedText: matchedText
                        )]
                    }
                    
                    let component = components[componentIndex]
                    
                    // Special handling for optional elements - try both possibilities
                    if case .optional(let optionalElement) = component {
                        // Try matching the optional element first
                        do {
                            let optionalResults = try validateElement(element: optionalElement, position: currentPos)
                            if let optionalResult = optionalResults.first {
                                let wrappedResult = ValidationResult(
                                    element: component,
                                    startIndex: optionalResult.startIndex,
                                    endIndex: optionalResult.endIndex,
                                    children: [optionalResult],
                                    matchedText: optionalResult.matchedText
                                )
                                do {
                                    return try tryValidateConcatenation(
                                        componentIndex: componentIndex + 1,
                                        currentPos: optionalResult.endIndex,
                                        childResults: childResults + [wrappedResult],
                                        matchedText: matchedText + optionalResult.matchedText
                                    )
                                } catch {
                                    // If matching the optional element leads to failure later, try not matching it
                                }
                            }
                        } catch {
                            // Optional element failed to match, which is okay
                        }
                        
                        // Try not matching the optional element (zero-width match)
                        let emptyResult = ValidationResult(
                            element: component,
                            startIndex: currentPos,
                            endIndex: currentPos,
                            matchedText: ""
                        )
                        return try tryValidateConcatenation(
                            componentIndex: componentIndex + 1,
                            currentPos: currentPos,
                            childResults: childResults + [emptyResult],
                            matchedText: matchedText
                        )
                    } else {
                        // Regular component - must match
                        let componentResults = try validateElement(element: component, position: currentPos)
                        guard let result = componentResults.first else {
                            let error = ValidationError(index: currentPos, message: "Component validation failed")
                            errors.append(error)
                            throw error
                        }
                        
                        return try tryValidateConcatenation(
                            componentIndex: componentIndex + 1,
                            currentPos: result.endIndex,
                            childResults: childResults + [result],
                            matchedText: matchedText + result.matchedText
                        )
                    }
                }
                
                return try tryValidateConcatenation(componentIndex: 0, currentPos: position, childResults: [], matchedText: "")
                
            case .repeating(let repeatedElement, let atLeast, let upTo):
                let minCount = atLeast ?? 0
                let maxCount = upTo ?? Int.max
                
                var currentPos = position
                var childResults: [ValidationResult] = []
                var matchedText = ""
                var count = 0
                
                while count < maxCount && currentPos <= input.endIndex {
                    do {
                        let results = try validateElement(element: repeatedElement, position: currentPos)
                        guard let result = results.first else { break }
                        
                        // Prevent infinite loops with zero-width matches
                        if result.startIndex == result.endIndex && count > 0 {
                            break
                        }
                        
                        childResults.append(result)
                        matchedText += result.matchedText
                        currentPos = result.endIndex
                        count += 1
                    } catch {
                        break
                    }
                }
                
                if count < minCount {
                    let error = ValidationError(index: position, message: "Expected at least \(minCount) repetitions, found \(count)")
                    // Don't add to global errors array - throw directly
                    throw error
                }
                
                return [ValidationResult(
                    element: element,
                    startIndex: position,
                    endIndex: currentPos,
                    children: childResults,
                    matchedText: matchedText
                )]
                
            case .optional(let optionalElement):
                do {
                    let results = try validateElement(element: optionalElement, position: position)
                    return results.map { result in
                        ValidationResult(
                            element: element,
                            startIndex: result.startIndex,
                            endIndex: result.endIndex,
                            children: [result],
                            matchedText: result.matchedText
                        )
                    }
                } catch {
                    // Optional element can fail - return empty match
                    return [ValidationResult(
                        element: element,
                        startIndex: position,
                        endIndex: position,
                        matchedText: ""
                    )]
                }
            }
        }
        
        do {
            return try validateElement(element: element, position: startPosition)
        } catch {
            // If it's already a ValidationError and we only have one error, throw it directly
            if let validationError = error as? ValidationError, errors.count <= 1 {
                throw validationError
            }
            // Otherwise create an ErrorCollection
            if errors.isEmpty {
                errors.append(error)
            }
            throw ErrorCollection(errors: errors)
        }
    }
}
