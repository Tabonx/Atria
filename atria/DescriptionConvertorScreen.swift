//
//  DescriptionConvertorScreen.swift
//  atria
//
//  Created by Pavel Kroupa on 09.04.2025.
//

import SwiftUI

struct DescriptionConvertorScreen: View {
    @State private var inputText: String = ""
    var outputText: String {
        transformMarkdownToAppStoreText(inputText)
    }

    var body: some View {
        VStack {
            HStack {
                VStack {
                    TextEditor(text: $inputText)
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Button("Copy Input") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(inputText, forType: .string)
                    }
                    .padding(.bottom)
                }

                VStack {
                    TextEditor(text: .constant(outputText))
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .disabled(true)
                    Button("Copy Output") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(outputText, forType: .string)
                    }
                    .padding(.bottom)
                }
            }
        }
    }

    func transformMarkdownToAppStoreText(_ markdown: String) -> String {
        var result = ""
        let lines = markdown.components(separatedBy: .newlines)

        for line in lines {
            if line.hasPrefix("### ") {
                // Convert markdown header to plain text
                result += line.replacingOccurrences(of: "### ", with: "") + "\n"
            } else if line.hasPrefix("- ") {
                // Convert markdown bullet to App Store bullet
                result += "• " + line.dropFirst(2) + "\n"
            } else if line.contains("[") && line.contains("](") {
                // Convert markdown link to plain email text
                let emailRegex = try! NSRegularExpression(pattern: "\\[.*?\\]\\((mailto:)?(.*?)\\)")
                let range = NSRange(line.startIndex ..< line.endIndex, in: line)
                let newLine = emailRegex.stringByReplacingMatches(in: line, options: [], range: range, withTemplate: "$2")
                result += newLine + "\n"
            } else {
                result += line + "\n"
            }
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#Preview {
    DescriptionConvertorScreen()
}
