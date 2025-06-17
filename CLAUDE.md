# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SwiftABNF is a Swift library and command-line tool for parsing and validating ABNF (Augmented Backus-Naur Form) grammars according to RFC 5234 and RFC 7405. The project includes:

- **ABNFLib**: Core library implementing ABNF parsing and validation
- **abnf**: Command-line tool for grammar validation (stub implementation)
- Support for binary, decimal, and hexadecimal numeric values
- Parse tree generation for matched inputs
- Multiple encoding support (ASCII, Latin-1, Unicode)

## Architecture

### Core Components

- `ABNF` struct: Main parser and validator with frame-based validation engine
- `Rule` struct: Represents individual ABNF rules with name and element
- `Element` enum: Recursive structure representing all ABNF constructs (alternation, concatenation, repetition, strings, numeric values, etc.)
- `ParseTree` struct: Represents validation results with hierarchical structure
- Core rules implementation covering standard ABNF rules (ALPHA, DIGIT, VCHAR, etc.)

### Key Features

- Frame-based validation algorithm for efficient parsing
- Support for case-sensitive and case-insensitive string matching
- Numeric value parsing in binary (%b), decimal (%d), and hexadecimal (%x) formats
- Repetition handling with min/max constraints
- Parse tree generation for detailed analysis
- Multiple encoding support with appropriate character ranges

## Common Development Commands

### Building
```bash
swift build
```

### Running Tests
```bash
swift test
```

### Running Single Test
```bash
swift test --filter <test-name>
```

### Running the CLI Tool
```bash
swift run abnf validate --grammar <path-to-grammar> [input-files...]
```

## Test Framework

Uses Swift Testing framework (not XCTest). Test files use `@Test` attribute and `#expect` assertions. Test resources are accessed via `Bundle.module`.

## File Structure

- `Sources/ABNFLib/`: Core library implementation
- `Sources/abnf/`: Command-line tool (currently stub)
- `Sources/SwiftABNF/`: Empty main file
- `Tests/ABNFLibTests/`: Test suite with ABNF grammar examples