// main.swift
// Entry point for the ABNF command-line tool

#if canImport(ArgumentParser)

import ArgumentParser
import ABNFLib

@main
struct ABNFCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "abnf",
        abstract: "A utility for working with ABNF grammars",
        subcommands: [Validate.self]
    )
    
    struct Validate: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Validate input against an ABNF grammar"
        )
        
        @Option(name: .long, help: "Path to the ABNF grammar file")
        var grammar: String
        
        @Argument(help: "Input files to validate (reads from stdin if none provided)")
        var inputFiles: [String] = []
        
        func run() throws {
            // Stub implementation
            print("Validate command would validate input against the grammar at \(grammar)")
            if inputFiles.isEmpty {
                print("Reading from stdin (not implemented in this stub)")
            } else {
                print("Would validate these files: \(inputFiles.joined(separator: ", "))")
            }
        }
    }
}

#else

@main
struct ABNFCommand {
    static func main() {
        print("This tool requires the ArgumentParser package, which is only available on supported platforms (macOS, Linux, Windows).")
    }
}

#endif
