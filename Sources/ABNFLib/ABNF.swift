import Foundation

/// A named rule in an ABNF grammar, consisting of a rule name and its corresponding element definition.
///
/// Rules are the fundamental building blocks of ABNF grammars. Each rule associates a name with an element
/// that defines the syntax pattern for that rule.
///
/// ## Example
/// ```swift
/// let rule = Rule(name: "greeting", element: .string("hello"))
/// ```
///
/// - Note: Rule names are case-insensitive in ABNF but are stored as provided.
public struct Rule: Equatable, Sendable {
    /// The name of the rule.
    ///
    /// Rule names must start with a letter and can contain letters, digits, and hyphens.
    /// They are case-insensitive when referenced in ABNF grammars.
    public var name: String
    
    /// The element that defines the syntax pattern for this rule.
    ///
    /// This can be any valid ABNF element including strings, numeric values, 
    /// alternations, concatenations, repetitions, and references to other rules.
    public var element: Element
    
    /// Creates a new rule with the specified name and element.
    ///
    /// - Parameters:
    ///   - name: The name of the rule. Must be a valid ABNF rule name.
    ///   - element: The element that defines the rule's syntax pattern.
    public init(name: String, element: Element) {
        self.name = name
        self.element = element
    }
}

/// Represents all possible elements in an ABNF grammar.
///
/// Elements are the building blocks that define the structure and patterns within ABNF rules.
/// This recursive enum captures all the different types of constructs supported by ABNF.
///
/// ## Element Types
/// - **Rule Names**: References to other rules in the grammar
/// - **Alternation**: Choice between multiple elements (A / B / C)
/// - **Concatenation**: Sequence of elements (A B C)
/// - **Repetition**: Repeated elements with optional min/max constraints
/// - **Optional**: Elements that may or may not be present [A]
/// - **Strings**: Literal text matches, case-sensitive or insensitive
/// - **Numeric**: Single numeric values in binary, decimal, or hexadecimal
/// - **Numeric Series**: Sequences of specific numeric values
/// - **Numeric Ranges**: Ranges of acceptable numeric values
///
/// ## Example
/// ```swift
/// let element = Element.concatenating([
///     .string("hello"),
///     .string(" "),
///     .ruleName("name")
/// ])
/// ```
public indirect enum Element: Equatable, Sendable {
    /// Specifies the numeric base for ABNF numeric values.
    ///
    /// ABNF supports three numeric representations corresponding to different bases:
    /// - Binary (%b): Base 2 representation
    /// - Decimal (%d): Base 10 representation  
    /// - Hexadecimal (%x): Base 16 representation
    public enum NumericType: Equatable, Sendable {
        /// Binary (base 2) numeric values, prefixed with %b in ABNF notation.
        case binary
        /// Decimal (base 10) numeric values, prefixed with %d in ABNF notation.
        case decimal
        /// Hexadecimal (base 16) numeric values, prefixed with %x in ABNF notation.
        case hexadecimal
        
        /// The ABNF prefix string for this numeric type.
        var prefix: String {
            switch self {
            case .binary: return "%b"
            case .decimal: return "%d"
            case .hexadecimal: return "%x"
            }
        }
        
        /// The numeric radix (base) for this type.
        var radix: Int {
            switch self {
            case .binary: return 2
            case .decimal: return 10
            case .hexadecimal: return 16
            }
        }
        
        /// Converts a number to its string representation in this numeric base.
        ///
        /// - Parameter number: The number to convert.
        /// - Returns: String representation of the number in the appropriate base.
        func string(_ number: UInt32) -> String {
            switch self {
            case .binary: return String(number, radix: 2)
            case .decimal: return String(number)
            case .hexadecimal: return String(format: "%02X", number)
            }
        }
    }
    
    /// A reference to another rule by name.
    ///
    /// Rule names are resolved during validation against the complete grammar.
    /// - Parameter String: The name of the rule to reference.
    case ruleName(String)
    
    /// An alternation (choice) between multiple elements, equivalent to A / B / C in ABNF.
    ///
    /// During validation, each alternative is tried in order until one succeeds.
    /// - Parameter [Element]: Array of alternative elements to choose from.
    case alternating([Element])
    
    /// A concatenation (sequence) of elements, equivalent to A B C in ABNF.
    ///
    /// All elements must match in the specified order for the concatenation to succeed.
    /// - Parameter [Element]: Array of elements that must all match in sequence.
    case concatenating([Element])
    
    /// A repetition of an element with optional minimum and maximum constraints.
    ///
    /// Corresponds to ABNF repetition notation like `*element`, `2*5element`, etc.
    /// - Parameters:
    ///   - Element: The element to repeat.
    ///   - atLeast: Minimum number of repetitions (nil means 0).
    ///   - upTo: Maximum number of repetitions (nil means unlimited).
    case repeating(Element, atLeast: Int? = nil, upTo: Int? = nil)
    
    /// An optional element, equivalent to [element] in ABNF.
    ///
    /// The element may or may not be present in the input.
    /// - Parameter Element: The element that is optional.
    case optional(Element)
    
    /// A literal string that must be matched.
    ///
    /// - Parameters:
    ///   - String: The literal string to match.
    ///   - caseSensitive: Whether the match should be case-sensitive (default: false).
    case string(String, caseSensitive: Bool = false)
    
    /// A single numeric value in the specified base.
    ///
    /// Corresponds to ABNF notation like %d65, %x41, %b1000001.
    /// - Parameters:
    ///   - UInt32: The numeric value to match.
    ///   - type: The numeric base (binary, decimal, or hexadecimal).
    case numeric(UInt32, type: NumericType)
    
    /// A series of specific numeric values that must match in sequence.
    ///
    /// Corresponds to ABNF notation like %d65.66.67 (matches "ABC").
    /// - Parameters:
    ///   - [UInt32]: Array of numeric values that must match in sequence.
    ///   - type: The numeric base for all values.
    case numericSeries([UInt32], type: NumericType)
    
    /// A range of acceptable numeric values.
    ///
    /// Corresponds to ABNF notation like %d65-90 (matches A-Z).
    /// - Parameters:
    ///   - min: Minimum acceptable value (inclusive).
    ///   - max: Maximum acceptable value (inclusive).
    ///   - type: The numeric base for the range.
    case numericRange(min: UInt32, max: UInt32, type: NumericType)
}

extension Element {
    // MARK: - Binary Numeric Convenience Methods
    
    /// Creates a binary numeric element that matches a single value.
    ///
    /// Equivalent to `%b<value>` in ABNF notation.
    ///
    /// - Parameter single: The binary value to match.
    /// - Returns: An element that matches the specified binary value.
    ///
    /// ## Example
    /// ```swift
    /// let space = Element.binary(0b100000) // Matches ASCII space (32)
    /// ```
    public static func binary(_ single: UInt32) -> Element {
        .numeric(single, type: .binary)
    }
    
    /// Creates a binary numeric series element that matches a sequence of values.
    ///
    /// Equivalent to `%b<value1>.<value2>.<value3>` in ABNF notation.
    ///
    /// - Parameter series: Array of binary values that must match in sequence.
    /// - Returns: An element that matches the specified sequence of binary values.
    ///
    /// ## Example
    /// ```swift
    /// let hello = Element.binary(series: [0b1001000, 0b1100101, 0b1101100, 0b1101100, 0b1101111])
    /// ```
    public static func binary(series: [UInt32]) -> Element {
        .numericSeries(series, type: .binary)
    }
    
    /// Creates a binary numeric range element that matches values within a range.
    ///
    /// Equivalent to `%b<min>-<max>` in ABNF notation.
    ///
    /// - Parameters:
    ///   - min: Minimum binary value (inclusive).
    ///   - max: Maximum binary value (inclusive).
    /// - Returns: An element that matches binary values within the specified range.
    ///
    /// ## Example
    /// ```swift
    /// let letters = Element.binary(min: 0b1000001, max: 0b1011010) // A-Z
    /// ```
    public static func binary(min: UInt32, max: UInt32) -> Element {
        .numericRange(min: min, max: max, type: .binary)
    }
    
    // MARK: - Decimal Numeric Convenience Methods
    
    /// Creates a decimal numeric element that matches a single value.
    ///
    /// Equivalent to `%d<value>` in ABNF notation.
    ///
    /// - Parameter single: The decimal value to match.
    /// - Returns: An element that matches the specified decimal value.
    ///
    /// ## Example
    /// ```swift
    /// let space = Element.decimal(32) // Matches ASCII space
    /// ```
    public static func decimal(_ single: UInt32) -> Element {
        .numeric(single, type: .decimal)
    }
    
    /// Creates a decimal numeric series element that matches a sequence of values.
    ///
    /// Equivalent to `%d<value1>.<value2>.<value3>` in ABNF notation.
    ///
    /// - Parameter series: Array of decimal values that must match in sequence.
    /// - Returns: An element that matches the specified sequence of decimal values.
    ///
    /// ## Example
    /// ```swift
    /// let hello = Element.decimal(series: [72, 101, 108, 108, 111]) // "Hello"
    /// ```
    public static func decimal(series: [UInt32]) -> Element {
        .numericSeries(series, type: .decimal)
    }
    
    /// Creates a decimal numeric range element that matches values within a range.
    ///
    /// Equivalent to `%d<min>-<max>` in ABNF notation.
    ///
    /// - Parameters:
    ///   - min: Minimum decimal value (inclusive).
    ///   - max: Maximum decimal value (inclusive).  
    /// - Returns: An element that matches decimal values within the specified range.
    ///
    /// ## Example
    /// ```swift
    /// let digits = Element.decimal(min: 48, max: 57) // 0-9
    /// ```
    public static func decimal(min: UInt32, max: UInt32) -> Element {
        .numericRange(min: min, max: max, type: .decimal)
    }
    
    // MARK: - Hexadecimal Numeric Convenience Methods
    
    /// Creates a hexadecimal numeric element that matches a single value.
    ///
    /// Equivalent to `%x<value>` in ABNF notation.
    ///
    /// - Parameter single: The hexadecimal value to match.
    /// - Returns: An element that matches the specified hexadecimal value.
    ///
    /// ## Example
    /// ```swift
    /// let space = Element.hexadecimal(0x20) // Matches ASCII space
    /// ```
    public static func hexadecimal(_ single: UInt32) -> Element {
        .numeric(single, type: .hexadecimal)
    }
    
    /// Creates a hexadecimal numeric series element that matches a sequence of values.
    ///
    /// Equivalent to `%x<value1>.<value2>.<value3>` in ABNF notation.
    ///
    /// - Parameter series: Array of hexadecimal values that must match in sequence.
    /// - Returns: An element that matches the specified sequence of hexadecimal values.
    ///
    /// ## Example
    /// ```swift
    /// let hello = Element.hexadecimal(series: [0x48, 0x65, 0x6C, 0x6C, 0x6F]) // "Hello"
    /// ```
    public static func hexadecimal(series: [UInt32]) -> Element {
        .numericSeries(series, type: .hexadecimal)
    }
    
    /// Creates a hexadecimal numeric range element that matches values within a range.
    ///
    /// Equivalent to `%x<min>-<max>` in ABNF notation.
    ///
    /// - Parameters:
    ///   - min: Minimum hexadecimal value (inclusive).
    ///   - max: Maximum hexadecimal value (inclusive).
    /// - Returns: An element that matches hexadecimal values within the specified range.
    ///
    /// ## Example
    /// ```swift
    /// let upperCase = Element.hexadecimal(min: 0x41, max: 0x5A) // A-Z
    /// ```
    public static func hexadecimal(min: UInt32, max: UInt32) -> Element {
        .numericRange(min: min, max: max, type: .hexadecimal)
    }
    
    // MARK: - Repetition Methods
    
    /// Creates a repetition element with unlimited repetitions (0 or more).
    ///
    /// Equivalent to `*element` in ABNF notation.
    ///
    /// - Returns: An element that matches zero or more repetitions of the current element.
    ///
    /// ## Example
    /// ```swift
    /// let spaces = Element.hexadecimal(0x20).repeating() // Zero or more spaces
    /// ```
    public func repeating() -> Element {
        .repeating(self)
    }
    
    /// Creates a repetition element with a minimum number of repetitions.
    ///
    /// Equivalent to `<atLeast>*element` in ABNF notation.
    ///
    /// - Parameter atLeast: Minimum number of repetitions required.
    /// - Returns: An element that matches at least the specified number of repetitions.
    ///
    /// ## Example
    /// ```swift
    /// let digits = Element.decimal(min: 48, max: 57).repeating(atLeast: 1) // One or more digits
    /// ```
    public func repeating(atLeast: Int) -> Element {
        .repeating(self, atLeast: atLeast)
    }
    
    /// Creates a repetition element with a maximum number of repetitions.
    ///
    /// Equivalent to `*<upTo>element` in ABNF notation.
    ///
    /// - Parameter upTo: Maximum number of repetitions allowed.
    /// - Returns: An element that matches up to the specified number of repetitions.
    ///
    /// ## Example
    /// ```swift
    /// let fewSpaces = Element.hexadecimal(0x20).repeating(upTo: 5) // Zero to five spaces
    /// ```
    public func repeating(upTo: Int) -> Element {
        .repeating(self, upTo: upTo)
    }
    
    /// Creates a repetition element with both minimum and maximum constraints.
    ///
    /// Equivalent to `<atLeast>*<upTo>element` in ABNF notation.
    ///
    /// - Parameters:
    ///   - atLeast: Minimum number of repetitions required.
    ///   - upTo: Maximum number of repetitions allowed.
    /// - Returns: An element that matches between the specified number of repetitions.
    ///
    /// ## Example
    /// ```swift
    /// let someDigits = Element.decimal(min: 48, max: 57).repeating(atLeast: 2, upTo: 4) // 2-4 digits
    /// ```
    public func repeating(atLeast: Int, upTo: Int) -> Element {
        .repeating(self, atLeast: atLeast, upTo: upTo)
    }
    
    /// Creates a repetition element that matches exactly a specified number of repetitions.
    ///
    /// Equivalent to `<exactly>element` in ABNF notation.
    ///
    /// - Parameter exactly: Exact number of repetitions required.
    /// - Returns: An element that matches exactly the specified number of repetitions.
    ///
    /// ## Example
    /// ```swift
    /// let fourDigits = Element.decimal(min: 48, max: 57).repeating(4) // Exactly 4 digits
    /// ```
    public func repeating(_ exactly: Int) -> Element {
        .repeating(self, atLeast: exactly, upTo: exactly)
    }
}

/// A complete ABNF grammar consisting of a collection of rules.
///
/// The ABNF struct represents a parsed ABNF grammar and provides methods for validating input
/// strings against the rules defined in the grammar. It implements the ABNF specification
/// as defined in RFC 5234 and RFC 7405.
///
/// ## Features
/// - Frame-based validation algorithm for efficient parsing
/// - Support for all ABNF constructs (alternation, concatenation, repetition, etc.)
/// - Parse tree generation with detailed match information
/// - Multiple encoding support (ASCII, Latin-1, Unicode)
/// - Built-in core ABNF rules
///
/// ## Example
/// ```swift
/// let grammar = """
/// greeting = "hello" SP name
/// name = 1*ALPHA
/// """
/// 
/// let abnf = try ABNF(string: grammar)
/// try abnf.validate(string: "hello world", ruleName: "greeting")
/// ```
public struct ABNF {
    /// The rules that make up this ABNF grammar.
    ///
    /// Rules are stored in the order they were defined in the original grammar.
    /// Multiple rules with the same name are automatically combined into alternations.
    public let rules: [Rule]
    
    /// Creates an ABNF grammar from a collection of rules.
    ///
    /// - Parameter rules: The rules that make up the grammar.
    public init(rules: [Rule]) {
        self.rules = rules
    }
}

extension ABNF {
    /// Character encoding options for ABNF parsing and validation.
    ///
    /// Different encodings affect how numeric values are interpreted and what characters
    /// are allowed in quoted strings. The encoding should match the encoding of the
    /// input string being validated.
    public enum Encoding: CaseIterable, Sendable {
        /// ASCII encoding (default).
        ///
        /// - Hex values match single bytes of encoded string data
        /// - Characters in quoted strings are limited to 0x20-0x7E as per original ABNF RFC
        /// - Most restrictive but widely compatible encoding
        case ascii
        
        /// Latin-1 encoding (ISO 8859-1).
        ///
        /// - Hex values match single bytes of encoded string data  
        /// - Characters in quoted strings extend through 0xFF
        /// - Supports Western European character sets
        case latin1
        
        /// Unicode encoding.
        ///
        /// - Hex values can match any Unicode code point
        /// - Characters in quoted strings extend through 0x10FFFD
        /// - Supports full Unicode character set for international text
        case unicode
    }
}
