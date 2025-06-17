import Foundation
import Testing
@testable import ABNFLib

@Test func parseSlashAssignment() async throws {
    let rules = [
        Rule(name: "single-space", element: .binary(0b100000))
    ]
    let abnf = try ABNF(string: "single-space =/ %b100000\r\n")
    #expect(abnf.rules == rules)
    try abnf.validate(string: " ")
    #expect(throws: ABNF.ValidationError.self) { try abnf.validate(string: "  ") }
}

@Test func parseBinValSingle() async throws {
    let rules = [
        Rule(name: "single-space", element: .binary(0b100000))
    ]
    let abnf = try ABNF(string: "single-space = %b100000\r\n")
    #expect(abnf.rules == rules)
    try abnf.validate(string: " ")
    #expect(throws: ABNF.ValidationError.self) { try abnf.validate(string: "  ") }
}

@Test func parseBinValSeries() async throws {
    let rules = [
        Rule(name: "double-space", element: .binary(series: [0b100000, 0b100000]))
    ]
    let abnf = try ABNF(string: "double-space = %b100000.100000\r\n")
    #expect(abnf.rules == rules)
    #expect(throws: ABNF.ValidationError.self) { try abnf.validate(string: " ") }
    try abnf.validate(string: "  ")
    #expect(throws: ABNF.ValidationError.self) { try abnf.validate(string: "   ") }
}

@Test func parseBinValRange() async throws {
    let rules = [
        Rule(name: "space-or-exclamation", element: .binary(min: 0b100000, max: 0b100001))
    ]
    let abnf = try ABNF(string: "space-or-exclamation = %b100000-100001\r\n")
    #expect(abnf.rules == rules)
    #expect(throws: ABNF.ValidationError.self) { try abnf.validate(string: "  ") }
    try abnf.validate(string: " ")
    try abnf.validate(string: "!")
    #expect(throws: ABNF.ValidationError.self) { try abnf.validate(string: " !") }
}

@Test func parseDecValRule() async throws {
    let rules = [
        Rule(name: "single-space", element: .decimal(32))
    ]
    let abnf = try ABNF(string: "single-space = %d32\r\n")
    #expect(abnf.rules == rules)
    try abnf.validate(string: " ")
    #expect(throws: ABNF.ValidationError.self) { try abnf.validate(string: "  ") }
}

@Test func parseDecValSeries() async throws {
    let rules = [
        Rule(name: "double-space", element: .decimal(series: [32, 32]))
    ]
    let abnf = try ABNF(string: "double-space = %d32.32\r\n")
    #expect(abnf.rules == rules)
    #expect(throws: ABNF.ValidationError.self) { try abnf.validate(string: " ") }
    try abnf.validate(string: "  ")
    #expect(throws: ABNF.ValidationError.self) { try abnf.validate(string: "   ") }
}

@Test func parseDecValRange() async throws {
    let rules = [
        Rule(name: "space-or-exclamation", element: .decimal(min: 32, max: 33))
    ]
    let abnf = try ABNF(string: "space-or-exclamation = %d32-33\r\n")
    #expect(abnf.rules == rules)
    #expect(throws: ABNF.ValidationError.self) { try abnf.validate(string: "  ") }
    try abnf.validate(string: " ")
    try abnf.validate(string: "!")
    #expect(throws: ABNF.ValidationError.self) { try abnf.validate(string: " !") }
}

@Test func parseHexValRule() async throws {
    let rules = [
        Rule(name: "single-space", element: .hexadecimal(0x20))
    ]
    let abnf = try ABNF(string: "single-space = %x20\r\n")
    #expect(abnf.rules == rules)
    try abnf.validate(string: " ")
    #expect(throws: ABNF.ValidationError.self) { try abnf.validate(string: "  ") }
}

@Test func parseHexValSeries() async throws {
    let rules = [
        Rule(name: "double-space", element: .hexadecimal(series: [0x20, 0x20]))
    ]
    let abnf = try ABNF(string: "double-space = %x20.20\r\n")
    #expect(abnf.rules == rules)
    #expect(throws: ABNF.ValidationError.self) { try abnf.validate(string: " ") }
    try abnf.validate(string: "  ")
    #expect(throws: ABNF.ValidationError.self) { try abnf.validate(string: "   ") }
}

@Test func parseHexValRange() async throws {
    let rules = [
        Rule(name: "space-or-exclamation", element: .hexadecimal(min: 0x20, max: 0x21))
    ]
    let abnf = try ABNF(string: "space-or-exclamation = %x20-21\r\n")
    #expect(abnf.rules == rules)
    #expect(throws: ABNF.ValidationError.self) { try abnf.validate(string: "  ") }
    try abnf.validate(string: " ")
    try abnf.validate(string: "!")
    #expect(throws: ABNF.ValidationError.self) { try abnf.validate(string: " !") }
}

@Test func parseRepeatRule() async throws {
    let rules = [
        Rule(name: "any-space", element: .hexadecimal(0x20).repeating())
    ]
    let abnf = try ABNF(string: "any-space = *%x20\r\n")
    #expect(abnf.rules == rules)
    try abnf.validate(string: "")
    try abnf.validate(string: " ")
    try abnf.validate(string: "  ")
    try abnf.validate(string: "   ")
    try abnf.validate(string: "    ")
}

@Test func parseRepeatExactlyRule() async throws {
    let rules = [
        Rule(name: "double-space", element: .hexadecimal(0x20).repeating(2))
    ]
    let abnf = try ABNF(string: "double-space = 2%x20\r\n")
    #expect(abnf.rules == rules)
    #expect(throws: ABNF.ValidationError.self) { try abnf.validate(string: "") }
    #expect(throws: ABNF.ValidationError.self) { try abnf.validate(string: " ") }
    try abnf.validate(string: "  ")
    #expect(throws: ABNF.ValidationError.self) { try abnf.validate(string: "   ") }
    #expect(throws: ABNF.ValidationError.self) { try abnf.validate(string: "    ") }
}

@Test func parseRepeatAtLeastRule() async throws {
    let rules = [
        Rule(name: "two-or-more-spaces", element: .hexadecimal(0x20).repeating(atLeast: 2))
    ]
    let abnf = try ABNF(string: "two-or-more-spaces = 2*%x20\r\n")
    #expect(abnf.rules == rules)
    #expect(throws: ABNF.ValidationError.self) { try abnf.validate(string: "") }
    #expect(throws: ABNF.ValidationError.self) { try abnf.validate(string: " ") }
    try abnf.validate(string: "  ")
    try abnf.validate(string: "   ")
    try abnf.validate(string: "    ")
}

@Test func parseRepeatUpToRule() async throws {
    let rules = [
        Rule(name: "up-to-three-spaces", element: .hexadecimal(0x20).repeating(upTo: 3))
    ]
    let abnf = try ABNF(string: "up-to-three-spaces = *3%x20\r\n")
    #expect(abnf.rules == rules)
    try abnf.validate(string: "")
    try abnf.validate(string: " ")
    try abnf.validate(string: "  ")
    try abnf.validate(string: "   ")
    #expect(throws: ABNF.ValidationError.self) { try abnf.validate(string: "    ") }
}

@Test func parseRepeatAtLeastAndUpToRule() async throws {
    let rules = [
        Rule(name: "two-or-three-spaces", element: .hexadecimal(0x20).repeating(atLeast: 2, upTo: 3))
    ]
    let abnf = try ABNF(string: "two-or-three-spaces = 2*3%x20\r\n")
    #expect(abnf.rules == rules)
    #expect(throws: ABNF.ValidationError.self) { try abnf.validate(string: "") }
    #expect(throws: ABNF.ValidationError.self) { try abnf.validate(string: " ") }
    try abnf.validate(string: "  ")
    try abnf.validate(string: "   ")
    #expect(throws: ABNF.ValidationError.self) { try abnf.validate(string: "    ") }
}

@Test func parseOptionalRule() async throws {
    let rules = [
        Rule(name: "optional-space", element: .optional(.hexadecimal(0x20)))
    ]
    let abnf = try ABNF(string: "optional-space = [%x20]")
    #expect(abnf.rules == rules)
    try abnf.validate(string: "")
    try abnf.validate(string: " ")
    #expect(throws: ABNF.ValidationError.self) { try abnf.validate(string: "  ") }
    #expect(throws: ABNF.ValidationError.self) { try abnf.validate(string: "   ") }
    #expect(throws: ABNF.ValidationError.self) { try abnf.validate(string: "    ") }
}

@Test func parseOptionalConcatenatingRule() async throws {
    let rules = [
        Rule(name: "optional-space-space", element: .concatenating([
            .optional(.hexadecimal(0x20)),
            .hexadecimal(0x20),
        ]))
    ]
    let abnf = try ABNF(string: "optional-space-space = [%x20] %x20")
    #expect(abnf.rules == rules)
    #expect(throws: ABNF.ValidationError.self) { try abnf.validate(string: "") }
    try abnf.validate(string: " ")
    try abnf.validate(string: "  ")
    #expect(throws: ABNF.ValidationError.self) { try abnf.validate(string: "   ") }
    #expect(throws: ABNF.ValidationError.self) { try abnf.validate(string: "    ") }
}

@Test func parseStringCaseInsensitiveRule() async throws {
    let rules = [
        Rule(name: "hello", element: .string("hello"))
    ]
    let abnf = try ABNF(string: #"hello = "hello""#)
    #expect(abnf.rules == rules)
    try abnf.validate(string: "hello")
    try abnf.validate(string: "Hello")
    try abnf.validate(string: "HelLo")
    try abnf.validate(string: "HELLO")
}

@Test func parseStringCaseInsensitivePrefixedRule() async throws {
    let rules = [
        Rule(name: "hello", element: .string("hello"))
    ]
    let abnf = try ABNF(string: #"hello = %i"hello""#)
    #expect(abnf.rules == rules)
    try abnf.validate(string: "hello")
    try abnf.validate(string: "Hello")
    try abnf.validate(string: "HelLo")
    try abnf.validate(string: "HELLO")
}

@Test func parseStringCaseSensitiveRule() async throws {
    let rules = [
        Rule(name: "hello", element: .string("hello", caseSensitive: true))
    ]
    let abnf = try ABNF(string: #"hello = %s"hello""#)
    #expect(abnf.rules == rules)
    try abnf.validate(string: "hello")
    #expect(throws: ABNF.ValidationError.self) { try abnf.validate(string: "Hello") }
    #expect(throws: ABNF.ValidationError.self) { try abnf.validate(string: "HelLo") }
    #expect(throws: ABNF.ValidationError.self) { try abnf.validate(string: "HELLO") }
}

@Test func parseInitial() async throws {
    let abnf = try ABNF(string: """
        name-part        = *(personal-part SP) last-name [SP suffix]
        name-part        =/ personal-part
        personal-part    = first-name / (initial ".")
        first-name       = *ALPHA
        initial          = ALPHA
        last-name        = *ALPHA
        suffix           = ("Jr." / "Sr." / 1*("I" / "V" / "X"))
        """)
    try abnf.validate(string: "J. Doe IX")
}


@Test func validatePostalAddress() async throws {
    let data = try Data(contentsOf: Bundle.module.url(forResource: "postal_address", withExtension: "abnf")!)
    let abnf = try ABNF(string: String(data: data, encoding: .ascii)!)
    var options = ABNF.ValidationOptions()
    options.encoding = .unicode
    try abnf.validate(string: "J. Doe IX\n123 Main St.\nSomewhere, US  12345\n", options: options)
}

@Test func testParseTreeGeneration() async throws {
    let rules = [
        Rule(name: "test", element: .concatenating([
            .string("hello"),
            .string(" "),
            .string("world")
        ]))
    ]
    let abnf = ABNF(rules: rules)
    let result = try abnf.validate(string: "hello world", ruleName: "test")
    
    // Verify parse tree structure
    #expect(result.element == .ruleName("test"))
    #expect(result.matchedText == "hello world")
    #expect(result.children.count == 1) // The concatenation child
    #expect(result.children[0].children.count == 3) // hello, space, world
}


