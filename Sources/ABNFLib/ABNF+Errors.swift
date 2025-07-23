import Foundation

extension ABNF {
    /// A collection of errors that occurred during validation or parsing.
    ///
    /// When multiple validation paths fail, their errors are collected into this type
    /// to provide comprehensive error information.
    public struct ErrorCollection: Error {
        /// The individual errors that make up this collection.
        ///
        /// Error collections are automatically flattened to avoid nested collections.
        public let errors: [any Error]
        
        /// Creates an error collection from an array of errors.
        ///
        /// Automatically flattens any nested ErrorCollection instances to maintain
        /// a flat structure of individual errors.
        ///
        /// - Parameter errors: The errors to collect.
        init(errors: [any Error]) {
            self.errors = errors.flatMap {
                if let error = $0 as? ErrorCollection {
                    return error.errors
                }
                return [$0]
            }
        }
    }
    
    /// An error that occurs during input validation against an ABNF grammar.
    ///
    /// ValidationError provides specific information about where and why validation failed,
    /// including the exact position in the input string and a descriptive message.
    public struct ValidationError: Error {
        /// The position in the input string where validation failed.
        ///
        /// This index points to the specific character or position that caused the validation to fail.
        public let index: Int
        
        /// A descriptive message explaining why validation failed.
        ///
        /// The message typically describes what was expected versus what was found.
        public let message: String
    }
    
    /// An error that occurs during ABNF grammar parsing.
    ///
    /// ParserError indicates that the ABNF grammar itself is malformed or contains syntax errors.
    public struct ParserError: Error {
        /// A descriptive message explaining the parsing error.
        ///
        /// The message describes what grammar construct was malformed or missing.
        public let message: String
    }
    
    /// The result of a successful validation operation.
    ///
    /// ValidationResult provides detailed information about how input was matched against
    /// the grammar, creating a hierarchical structure that shows the parsing process.
    /// It contains both the parse tree and position information needed for validation.
    ///
    /// ## Example
    /// ```swift
    /// let result = try abnf.validate(string: "hello world", ruleName: "greeting")
    /// print("Matched: '\(result.matchedText)'")
    /// print("Children: \(result.children.count)")
    /// ```
    public struct ValidationResult: Sendable {
        /// The grammar element that this validation result represents.
        ///
        /// This corresponds to the specific Element that was matched during parsing.
        public let element: Element
        
        /// The starting position in the input string for this match.
        public let startIndex: Int
        
        /// The ending position in the input string for this match.
        ///
        /// For a complete validation, this should be the end of the input string.
        /// For partial matches, this indicates how much of the input was consumed.
        public let endIndex: Int
        
        /// Child validation results representing sub-matches.
        ///
        /// For elements like concatenation and alternation, children represent
        /// the individual elements that were matched in the parsing process.
        public let children: [ValidationResult]
        
        /// The portion of the input string that was matched by this element.
        ///
        /// This is the substring from startIndex to endIndex.
        public let matchedText: String
        
        /// Creates a new validation result.
        ///
        /// - Parameters:
        ///   - element: The grammar element this result represents.
        ///   - startIndex: Starting position of the match.
        ///   - endIndex: Ending position of the match.
        ///   - children: Child validation results (empty by default).
        ///   - matchedText: The text that was matched.
        public init(element: Element, startIndex: Int, endIndex: Int, children: [ValidationResult] = [], matchedText: String) {
            self.element = element
            self.startIndex = startIndex
            self.endIndex = endIndex
            self.children = children
            self.matchedText = matchedText
        }
    }
}
