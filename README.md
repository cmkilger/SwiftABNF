# SwiftABNF

A Swift library and command-line tool for parsing and validating ABNF (Augmented Backus-Naur Form) grammars according to RFC 5234 and RFC 7405.

## Features

- ✅ Full ABNF grammar parsing and validation
- ✅ Support for all ABNF constructs (alternation, concatenation, repetition, optional elements)
- ✅ Binary (`%b`), decimal (`%d`), and hexadecimal (`%x`) numeric value support
- ✅ Case-sensitive and case-insensitive string matching
- ✅ Parse tree generation with detailed match information
- ✅ Multiple encoding support (ASCII, Latin-1, Unicode)
- ✅ Built-in core ABNF rules (ALPHA, DIGIT, VCHAR, etc.)
- ✅ Swift 6 compatible with full concurrency support

## Installation

### Swift Package Manager

Add SwiftABNF to your `Package.swift` dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/SwiftABNF", from: "1.0.0")
]
```

Then add it to your target:

```swift
targets: [
    .target(
        name: "YourTarget",
        dependencies: ["ABNFLib"]
    )
]
```

## Usage

### Basic Grammar Parsing and Validation

```swift
import ABNFLib

// Define an ABNF grammar
let grammarString = """
name-part = *(personal-part SP) last-name [SP suffix]
personal-part = first-name / (initial ".")
first-name = *ALPHA
initial = ALPHA
last-name = *ALPHA
suffix = ("Jr." / "Sr." / 1*("I" / "V" / "X"))
"""

// Parse the grammar
let abnf = try ABNF(string: grammarString)

// Validate input against the grammar
try abnf.validate(string: "John Doe Jr.", ruleName: "name-part")
try abnf.validate(string: "J. Smith", ruleName: "name-part")
```

### Working with Parse Trees

```swift
let abnf = ABNF(rules: [
    Rule(name: "greeting", element: .concatenating([
        .string("hello"),
        .string(" "),
        .string("world")
    ]))
])

let result = try abnf.validate(string: "hello world", ruleName: "greeting")

// Access parse tree information
print("Matched text: \(result.parseTree.matchedText)")
print("Number of children: \(result.parseTree.children.count)")
```

### Programmatic Rule Construction

```swift
// Create rules programmatically
let spaceRule = Rule(
    name: "spaces", 
    element: .hexadecimal(0x20).repeating(atLeast: 1, upTo: 3)
)

let abnf = ABNF(rules: [spaceRule])
try abnf.validate(string: " ", ruleName: "spaces")    // ✅ Valid
try abnf.validate(string: "  ", ruleName: "spaces")   // ✅ Valid  
try abnf.validate(string: "   ", ruleName: "spaces")  // ✅ Valid
try abnf.validate(string: "    ", ruleName: "spaces") // ❌ Invalid
```

### Encoding Options

```swift
// ASCII encoding (default)
var options = ABNF.ValidationOptions()
options.encoding = .ascii

// Unicode support for international characters
options.encoding = .unicode

// Latin-1 encoding
options.encoding = .latin1

try abnf.validate(string: "héllo", options: options)
```

### Error Handling

```swift
do {
    try abnf.validate(string: "invalid input", ruleName: "my-rule")
} catch let error as ABNF.ValidationError {
    print("Validation failed at index \(error.index): \(error.message)")
} catch let error as ABNF.ParserError {
    print("Grammar parsing failed: \(error.message)")
}
```

## ABNF Element Types

The library supports all standard ABNF constructs:

### String Literals
```swift
.string("hello")                    // Case-insensitive by default
.string("Hello", caseSensitive: true) // Case-sensitive
```

### Numeric Values
```swift
.binary(0b1000001)                  // %b1000001 (ASCII 'A')
.decimal(65)                        // %d65 (ASCII 'A')  
.hexadecimal(0x41)                  // %x41 (ASCII 'A')

// Series and ranges
.binary(series: [65, 66, 67])       // %b1000001.1000010.1000011
.decimal(min: 65, max: 90)          // %d65-90 (A-Z)
```

### Repetition
```swift
.repeating(element)                 // *element (0 or more)
.repeating(element, atLeast: 2)     // 2*element (2 or more)
.repeating(element, upTo: 5)        // *5element (0 to 5)
.repeating(element, atLeast: 2, upTo: 5) // 2*5element (2 to 5)
.repeating(element, exactly: 3)     // 3element (exactly 3)
```

### Grouping and Options
```swift
.alternating([elem1, elem2, elem3]) // elem1 / elem2 / elem3
.concatenating([elem1, elem2])      // elem1 elem2
.optional(element)                  // [element]
```

### Rule References
```swift
.ruleName("ALPHA")                  // Reference to another rule
```

## Command-Line Tool

The package includes a command-line tool for validating files against ABNF grammars:

```bash
# Build the tool
swift build

# Run validation (stub implementation)
swift run abnf validate --grammar grammar.abnf input.txt
```

## Examples

### Email Address Validation

```swift
let emailGrammar = """
email = local-part "@" domain
local-part = 1*64(ALPHA / DIGIT / "." / "-" / "_")
domain = 1*253(ALPHA / DIGIT / "." / "-")
"""

let abnf = try ABNF(string: emailGrammar)
try abnf.validate(string: "user@example.com", ruleName: "email")
```

### URL Parsing

```swift
let urlGrammar = """
url = scheme "://" authority path-abempty
scheme = ALPHA *( ALPHA / DIGIT / "+" / "-" / "." )
authority = host [":" port]
host = 1*( ALPHA / DIGIT / "-" / "." )
port = 1*5DIGIT
path-abempty = *( "/" segment )
segment = *VCHAR
"""

let abnf = try ABNF(string: urlGrammar)
try abnf.validate(string: "https://example.com:8080/path", ruleName: "url")
```

## Requirements

- Swift 6.1+
- macOS 14.0+

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## License

This project is available under the MIT license. See the LICENSE file for more info.

## References

- [RFC 5234 - Augmented BNF for Syntax Specifications: ABNF](https://tools.ietf.org/html/rfc5234)
- [RFC 7405 - Case-Sensitive String Support in ABNF](https://tools.ietf.org/html/rfc7405)
