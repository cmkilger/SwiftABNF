import Foundation

extension ABNF {
    private struct WorkFrame {
        let element: Element
        let position: String.Index
        let continuation: [Element]
        let continuationIndex: Int
        let partialTree: ValidationResult?
        
        init(element: Element, position: String.Index, continuation: [Element] = [], continuationIndex: Int = 0, partialTree: ValidationResult? = nil) {
            self.element = element
            self.position = position
            self.continuation = continuation
            self.continuationIndex = continuationIndex
            self.partialTree = partialTree
        }
    }

    private struct ValidationState {
        var validResults: [ValidationResult] = []
        var allErrors: [ValidationError] = []
        var frameStack: [WorkFrame] = []
    }
    
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
        let rules = coreRules.merging(self.rules.reduce(into: [:]) { $0[$1.name] = $1.element }) { $1 }
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
        var state = ValidationState()
        state.frameStack.append(WorkFrame(element: element, position: startPosition))
        
        while !state.frameStack.isEmpty {
            let frame = state.frameStack.removeLast()
            
            do {
                let results = try process(frame: frame, input: input, rules: rules)
                
                if frame.continuation.isEmpty {
                    state.validResults.append(contentsOf: results)
                } else {
                    for result in results {
                        if frame.continuationIndex < frame.continuation.count {
                            let nextElement = frame.continuation[frame.continuationIndex]
                            let updatedContinuation = Array(frame.continuation[(frame.continuationIndex + 1)...])
                            state.frameStack.append(WorkFrame(
                                element: nextElement,
                                position: result.endIndex,
                                continuation: updatedContinuation,
                                continuationIndex: 0,
                                partialTree: result
                            ))
                        } else {
                            state.validResults.append(result)
                        }
                    }
                }
            } catch let error as ValidationError {
                state.allErrors.append(error)
            } catch let errorCollection as ErrorCollection {
                state.allErrors.append(contentsOf: errorCollection.errors.compactMap { $0 as? ValidationError })
            }
        }
        
        if state.validResults.isEmpty {
            if state.allErrors.count > 1 {
                throw ErrorCollection(errors: state.allErrors)
            } else if let firstError = state.allErrors.first {
                throw firstError
            } else {
                throw ValidationError(index: startPosition, message: "Validation failed")
            }
        }
        
        return state.validResults
    }
    
    private static func process(frame: WorkFrame, input: any StringProtocol, rules: [String: Element]) throws -> [ValidationResult] {
        switch frame.element {
        case let .ruleName(ruleName):
            guard let ruleElement = rules[ruleName] else {
                throw ValidationError(index: frame.position, message: "Undefined rule name: \(ruleName)")
            }
            let results = try validate(element: ruleElement, input: input, startPosition: frame.position, rules: rules)
            // Wrap in rule name trees
            return results.map { result in
                let substring = input[frame.position..<result.endIndex]
                return ValidationResult(
                    element: frame.element,
                    startIndex: frame.position,
                    endIndex: result.endIndex,
                    children: [result],
                    matchedText: String(substring)
                )
            }
            
        case let .alternating(elements):
            var allResults: [ValidationResult] = []
            var allErrors: [any Error] = []
            
            for element in elements {
                do {
                    let results = try validate(element: element, input: input, startPosition: frame.position, rules: rules)
                    for result in results {
                        let substring = input[frame.position..<result.endIndex]
                        let altTree = ValidationResult(
                            element: frame.element,
                            startIndex: frame.position,
                            endIndex: result.endIndex,
                            children: [result],
                            matchedText: String(substring)
                        )
                        allResults.append(altTree)
                    }
                } catch {
                    allErrors.append(error)
                    continue
                }
            }
            
            if allResults.isEmpty {
                if allErrors.count > 1 {
                    throw ErrorCollection(errors: allErrors)
                } else if let firstError = allErrors.first {
                    throw firstError
                } else {
                    throw ValidationError(index: frame.position, message: "No valid alternation found")
                }
            }
            return allResults
            
        case let .concatenating(elements):
            guard !elements.isEmpty else {
                let emptyTree = ValidationResult(
                    element: frame.element,
                    startIndex: frame.position,
                    endIndex: frame.position,
                    children: [],
                    matchedText: ""
                )
                return [emptyTree]
            }
            
            return try process(concatenating: elements, position: frame.position, input: input, rules: rules, parentElement: frame.element)
            
        case let .repeating(element, atLeast, upTo):
            return try process(repeating: element, atLeast: atLeast, upTo: upTo, position: frame.position, input: input, rules: rules, parentElement: frame.element)
            
        case let .optional(element):
            var results: [ValidationResult] = []
            
            // Always include the "skip" option
            let skipTree = ValidationResult(
                element: frame.element,
                startIndex: frame.position,
                endIndex: frame.position,
                children: [],
                matchedText: ""
            )
            results.append(skipTree)
            
            // Try to match the optional element
            do {
                let elementResults = try validate(element: element, input: input, startPosition: frame.position, rules: rules)
                for result in elementResults {
                    let substring = input[frame.position..<result.endIndex]
                    let optTree = ValidationResult(
                        element: frame.element,
                        startIndex: frame.position,
                        endIndex: result.endIndex,
                        children: [result],
                        matchedText: String(substring)
                    )
                    results.append(optTree)
                }
            } catch {}
            
            return results
            
        case let .string(string, caseSensitive):
            return try process(string: string, caseSensitive: caseSensitive, position: frame.position, input: input, element: frame.element)
            
        case let .numeric(number, numericType):
            return try process(number: number, numericType: numericType, position: frame.position, input: input, element: frame.element)
            
        case let .numericSeries(series, _):
            return try process(series: series, position: frame.position, input: input, element: frame.element)
            
        case let .numericRange(min, max, _):
            return try process(min: min, max: max, position: frame.position, input: input, element: frame.element)
        }
    }
    
    private static func process(concatenating elements: [Element], position: String.Index, input: any StringProtocol, rules: [String: Element], parentElement: Element) throws -> [ValidationResult] {
        var allResults: [ValidationResult] = []
        var allErrors: [any Error] = []
        
        func tryConcatenation(elementIndex: Int, currentPos: String.Index, children: [ValidationResult]) {
            if elementIndex >= elements.count {
                let substring = input[position..<currentPos]
                let concatTree = ValidationResult(
                    element: parentElement,
                    startIndex: position,
                    endIndex: currentPos,
                    children: children,
                    matchedText: String(substring)
                )
                allResults.append(concatTree)
                return
            }
            
            let element = elements[elementIndex]
            do {
                let nextResults = try validate(element: element, input: input, startPosition: currentPos, rules: rules)
                for result in nextResults {
                    tryConcatenation(elementIndex: elementIndex + 1, currentPos: result.endIndex, children: children + [result])
                }
            } catch {
                allErrors.append(error)
            }
        }
        
        tryConcatenation(elementIndex: 0, currentPos: position, children: [])
        
        if allResults.isEmpty {
            if allErrors.count > 1 {
                throw ErrorCollection(errors: allErrors)
            } else if let firstError = allErrors.first {
                throw firstError
            } else {
                throw ValidationError(index: position, message: "Concatenation failed")
            }
        }
        
        return allResults
    }
    
    private static func process(repeating element: Element, atLeast: Int?, upTo: Int?, position: String.Index, input: any StringProtocol, rules: [String: Element], parentElement: Element) throws -> [ValidationResult] {
        let minCount = atLeast ?? 0
        let maxCount = upTo
        
        var allResults: [ValidationResult] = []
        var currentLevel: [(String.Index, [ValidationResult])] = [(position, [])]
        var count = 0
        
        // If minimum is 0, the starting position is always valid
        if minCount == 0 {
            let emptyTree = ValidationResult(
                element: parentElement,
                startIndex: position,
                endIndex: position,
                children: [],
                matchedText: ""
            )
            allResults.append(emptyTree)
        }
        
        while count < (maxCount ?? .max) {
            var nextLevel: [(String.Index, [ValidationResult])] = []
            
            for (pos, children) in currentLevel {
                do {
                    let elementResults = try validate(element: element, input: input, startPosition: pos, rules: rules)
                    for result in elementResults {
                        nextLevel.append((result.endIndex, children + [result]))
                    }
                } catch {
                    continue
                }
            }
            
            if nextLevel.isEmpty {
                break
            }
            
            count += 1
            if count >= minCount {
                for (endPos, children) in nextLevel {
                    let substring = input[position..<endPos]
                    let repeatTree = ValidationResult(
                        element: parentElement,
                        startIndex: position,
                        endIndex: endPos,
                        children: children,
                        matchedText: String(substring)
                    )
                    allResults.append(repeatTree)
                }
            }
            
            currentLevel = nextLevel
        }
        
        if count < minCount {
            throw ValidationError(index: position, message: "Minimum repetition count not met")
        }
        
        return allResults
    }
    
    private static func process(string: String, caseSensitive: Bool, position: String.Index, input: any StringProtocol, element: Element) throws -> [ValidationResult] {
        if input.distance(from: position, to: input.endIndex) >= string.count {
            let endPosition = input.index(position, offsetBy: string.count)
            let substring = input[position..<endPosition]
            
            let matches = caseSensitive ?
                String(substring) == string :
                substring.lowercased() == string.lowercased()
            
            if matches {
                let tree = ValidationResult(
                    element: element,
                    startIndex: position,
                    endIndex: endPosition,
                    children: [],
                    matchedText: String(substring)
                )
                return [tree]
            }
        }
        throw ValidationError(index: position, message: "Not a valid quoted string")
    }
    
    private static func process(number: UInt32, numericType: Element.NumericType, position: String.Index, input: any StringProtocol, element: Element) throws -> [ValidationResult] {
        guard position < input.endIndex, let value = input[position].unicodeScalars.first?.value else {
            throw ValidationError(index: position, message: "End of file")
        }
        guard value == number else {
            throw ValidationError(index: position, message: "\(numericType.prefix)\(numericType.string(value)) != \(numericType.prefix)\(numericType.string(number))")
        }
        let endPosition = input.index(after: position)
        let substring = input[position..<endPosition]
        let tree = ValidationResult(
            element: element,
            startIndex: position,
            endIndex: endPosition,
            children: [],
            matchedText: String(substring)
        )
        return [tree]
    }
    
    private static func process(series: [UInt32], position: String.Index, input: any StringProtocol, element: Element) throws -> [ValidationResult] {
        guard position < input.endIndex else {
            throw ValidationError(index: position, message: "End of file")
        }
        guard input[position...].unicodeScalars.count >= series.count,
              zip(series, input[position...].unicodeScalars.map({ $0.value })).allSatisfy({ $0.0 == $0.1 }) else {
            throw ValidationError(index: position, message: "Not a valid numeric value")
        }
        let endPosition = input.index(position, offsetBy: series.count)
        let substring = input[position..<endPosition]
        let tree = ValidationResult(
            element: element,
            startIndex: position,
            endIndex: endPosition,
            children: [],
            matchedText: String(substring)
        )
        return [tree]
    }
    
    private static func process(min: UInt32, max: UInt32, position: String.Index, input: any StringProtocol, element: Element) throws -> [ValidationResult] {
        guard position < input.endIndex else {
            throw ValidationError(index: position, message: "End of file")
        }
        guard let value = input[position].unicodeScalars.first?.value, min <= value, value <= max else {
            throw ValidationError(index: position, message: "Not a valid numeric value")
        }
        let endPosition = input.index(after: position)
        let substring = input[position..<endPosition]
        let tree = ValidationResult(
            element: element,
            startIndex: position,
            endIndex: endPosition,
            children: [],
            matchedText: String(substring)
        )
        return [tree]
    }
}
