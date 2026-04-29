//
//  DescriptionConvertorScreen.swift
//  atria
//
//  Created by Pavel Kroupa on 09.04.2025.
//

import AppKit
import SwiftUI

private enum EditorMetrics {
    static let horizontalInset: CGFloat = 16
    static let verticalInset: CGFloat = 14
    static let cornerRadius: CGFloat = 18
    static let outerPadding: CGFloat = 24
    static let sectionSpacing: CGFloat = 20
    static let minimumWidth: CGFloat = 980
    static let minimumHeight: CGFloat = 640
}

private enum EditorCopy {
    static let inputPlaceholder = """
    ### Highlights
    - Improved release note formatting
    - Fixed edge cases in Markdown conversion
    - Updated copy for App Store Connect
    """

    static let outputPlaceholder = "Converted text will appear here."
}

private let editorTextFont = Font.system(.body, design: .monospaced)
private let editorNSFont = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)

struct DescriptionConvertorScreen: View {
    @State private var inputText = ""
    @State private var copyFeedbackTask: Task<Void, Never>?
    @State private var didCopyOutput = false

    private let formatter = ReleaseNotesFormatter()

    private var outputText: String {
        formatter.transform(inputText)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: EditorMetrics.sectionSpacing) {
            ScreenHeader(
                outputText: outputText,
                didCopyOutput: didCopyOutput,
                copyOutput: copyOutput
            )

            HStack(alignment: .top, spacing: EditorMetrics.sectionSpacing) {
                InputPanel(
                    inputText: $inputText,
                    pasteFromClipboard: pasteFromClipboard,
                    clearInput: clearInput
                )

                OutputPanel(outputText: outputText)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .padding(EditorMetrics.outerPadding)
        .frame(
            minWidth: EditorMetrics.minimumWidth,
            minHeight: EditorMetrics.minimumHeight
        )
        .background(Color(nsColor: .windowBackgroundColor))
        .onDisappear {
            copyFeedbackTask?.cancel()
        }
    }
}

private extension DescriptionConvertorScreen {
    func copyOutput() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(outputText, forType: .string)

        didCopyOutput = true
        copyFeedbackTask?.cancel()
        copyFeedbackTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                didCopyOutput = false
            }
        }
    }

    func pasteFromClipboard() {
        inputText = NSPasteboard.general.string(forType: .string) ?? ""
    }

    func clearInput() {
        inputText = ""
    }
}

private struct ReleaseNotesFormatter {
    private let linkRegex = try! NSRegularExpression(pattern: "\\[.*?\\]\\((mailto:)?(.*?)\\)")

    func transform(_ markdown: String) -> String {
        let lines = markdown.components(separatedBy: .newlines)
        let transformedLines = lines.enumerated().compactMap(transformLine)
        return transformedLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func transformLine(indexedLine: EnumeratedSequence<[String]>.Element) -> String? {
        let (index, line) = indexedLine

        if index == 0, isReleaseNotesTitle(line) {
            return nil
        }

        if line.hasPrefix("### ") {
            return line.replacingOccurrences(of: "### ", with: "")
        }

        if line.hasPrefix("- ") || line.hasPrefix("* ") {
            return "• " + line.dropFirst(2)
        }

        if line.contains("[") && line.contains("](") {
            return replacingMarkdownLinks(in: line)
        }

        return line
    }

    private func replacingMarkdownLinks(in line: String) -> String {
        let range = NSRange(line.startIndex ..< line.endIndex, in: line)
        return linkRegex.stringByReplacingMatches(
            in: line,
            options: [],
            range: range,
            withTemplate: "$2"
        )
    }

    private func isReleaseNotesTitle(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("#") else { return false }

        let title = trimmed.drop { $0 == "#" || $0 == " " }.lowercased()
        return title.hasSuffix("release notes")
    }
}

private struct ScreenHeader: View {
    let outputText: String
    let didCopyOutput: Bool
    let copyOutput: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Release Notes Converter")
                    .font(.system(size: 28, weight: .semibold))

                Text("Paste Markdown on the left and copy App Store-ready text on the right.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(didCopyOutput ? "Copied" : "Copy Output", action: copyOutput)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(outputText.isEmpty)
        }
    }
}

private struct InputPanel: View {
    @Binding var inputText: String

    let pasteFromClipboard: () -> Void
    let clearInput: () -> Void

    var body: some View {
        EditorPanel(
            title: "Markdown",
            subtitle: "Source release notes",
            actions: {
                Button("Paste", action: pasteFromClipboard)
                    .keyboardShortcut("v", modifiers: [.command, .shift])

                Button("Clear", action: clearInput)
                    .disabled(inputText.isEmpty)
            },
            content: {
                TextEditorSurface(
                    text: $inputText,
                    placeholder: EditorCopy.inputPlaceholder
                )
            }
        )
    }
}

private struct OutputPanel: View {
    let outputText: String

    var body: some View {
        EditorPanel(
            title: "App Store Text",
            subtitle: "Ready to paste into App Store Connect",
            actions: {
                if !outputText.isEmpty {
                    Text("\(outputText.count) characters")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            },
            content: {
                ReadOnlyTextSurface(
                    text: outputText,
                    placeholder: EditorCopy.outputPlaceholder
                )
            }
        )
    }
}

private struct EditorPanel<Actions: View, Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let actions: Actions
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 8) {
                    actions
                }
            }

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(panelBackground)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: EditorMetrics.cornerRadius,
                        style: .continuous
                    )
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: EditorMetrics.cornerRadius,
                        style: .continuous
                    )
                    .strokeBorder(.quaternary, lineWidth: 1)
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: EditorMetrics.cornerRadius, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor))
    }
}

private struct TextEditorSurface: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            EditorTextView(text: $text)

            if text.isEmpty {
                EditorPlaceholder(text: placeholder)
            }
        }
    }
}

private struct ReadOnlyTextSurface: View {
    let text: String
    let placeholder: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            ReadOnlyTextView(text: text)

            if text.isEmpty {
                EditorPlaceholder(text: placeholder)
            }
        }
    }
}

private struct EditorPlaceholder: View {
    let text: String

    var body: some View {
        Text(text)
            .font(editorTextFont)
            .foregroundStyle(.tertiary)
            .padding(.leading, EditorMetrics.horizontalInset)
            .padding(.top, EditorMetrics.verticalInset)
            .allowsHitTesting(false)
    }
}

private struct EditorTextView: NSViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = TextViewFactory.makeScrollView()
        let textView = TextViewFactory.makeTextView(editable: true)
        textView.delegate = context.coordinator
        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String

        init(text: Binding<String>) {
            _text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text = textView.string
        }
    }
}

private struct ReadOnlyTextView: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = TextViewFactory.makeScrollView()
        let textView = TextViewFactory.makeTextView(editable: false)
        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
    }
}

private enum TextViewFactory {
    static func makeScrollView() -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        return scrollView
    }

    static func makeTextView(editable: Bool) -> NSTextView {
        let textView = NSTextView()
        textView.isEditable = editable
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.font = editorNSFont
        textView.textColor = .labelColor
        textView.insertionPointColor = .labelColor
        textView.textContainerInset = NSSize(
            width: EditorMetrics.horizontalInset - 5,
            height: EditorMetrics.verticalInset - 2
        )
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 0
        textView.isRichText = false
        textView.importsGraphics = false
        textView.usesFindBar = true
        return textView
    }
}

#Preview {
    ContentView()
}
