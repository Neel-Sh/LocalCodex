import AppKit
import SwiftUI

struct MarkdownMessageView: View {
    let markdown: String

    private var blocks: [MarkdownBlock] {
        MarkdownParser.parse(markdown)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(blocks) { block in
                switch block.kind {
                case .heading(let level, let text):
                    MarkdownHeading(level: level, text: text)
                case .paragraph(let text):
                    MarkdownParagraph(text: text)
                case .unorderedList(let items):
                    MarkdownList(items: items, style: .unordered)
                case .orderedList(let items):
                    MarkdownList(items: items.map(\.text), style: .ordered(items.map(\.number)))
                case .quote(let text):
                    MarkdownQuote(text: text)
                case .code(let language, let code):
                    MarkdownCodeBlock(language: language, code: code)
                case .table(let header, let rows):
                    MarkdownTable(header: header, rows: rows)
                case .divider:
                    MarkdownDivider()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MarkdownBlock: Identifiable {
    let id: Int
    let kind: MarkdownBlockKind
}

private enum MarkdownBlockKind {
    case heading(level: Int, text: String)
    case paragraph(String)
    case unorderedList([String])
    case orderedList([(number: Int, text: String)])
    case quote(String)
    case code(language: String?, code: String)
    case table(header: [String], rows: [[String]])
    case divider
}

private enum MarkdownListStyle {
    case unordered
    case ordered([Int])
}

private enum MarkdownParser {
    static func parse(_ markdown: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var nextID = 0
        var paragraphLines: [String] = []
        var unorderedItems: [String] = []
        var orderedItems: [(number: Int, text: String)] = []
        var quoteLines: [String] = []
        var codeLines: [String] = []
        var codeLanguage: String?
        var inCodeFence = false
        var index = 0

        func append(_ kind: MarkdownBlockKind) {
            blocks.append(MarkdownBlock(id: nextID, kind: kind))
            nextID += 1
        }

        func flushParagraph() {
            guard !paragraphLines.isEmpty else { return }
            append(.paragraph(paragraphLines.joined(separator: "\n")))
            paragraphLines.removeAll()
        }

        func flushUnorderedList() {
            guard !unorderedItems.isEmpty else { return }
            append(.unorderedList(unorderedItems))
            unorderedItems.removeAll()
        }

        func flushOrderedList() {
            guard !orderedItems.isEmpty else { return }
            append(.orderedList(orderedItems))
            orderedItems.removeAll()
        }

        func flushQuote() {
            guard !quoteLines.isEmpty else { return }
            append(.quote(quoteLines.joined(separator: "\n")))
            quoteLines.removeAll()
        }

        func flushLooseBlocks() {
            flushParagraph()
            flushUnorderedList()
            flushOrderedList()
            flushQuote()
        }

        let lines = markdown.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if inCodeFence {
                if trimmed.hasPrefix("```") {
                    append(.code(language: codeLanguage, code: codeLines.joined(separator: "\n")))
                    codeLines.removeAll()
                    codeLanguage = nil
                    inCodeFence = false
                } else {
                    codeLines.append(line)
                }
                index += 1
                continue
            }

            if trimmed.hasPrefix("```") {
                flushLooseBlocks()
                inCodeFence = true
                let language = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                codeLanguage = language.isEmpty ? nil : language
                index += 1
                continue
            }

            if trimmed.isEmpty {
                flushLooseBlocks()
                index += 1
                continue
            }

            if isDivider(trimmed) {
                flushLooseBlocks()
                append(.divider)
                index += 1
                continue
            }

            if let table = parseTable(lines: lines, startingAt: index) {
                flushLooseBlocks()
                append(.table(header: table.header, rows: table.rows))
                index = table.nextIndex
                continue
            }

            if let heading = parseHeading(trimmed) {
                flushLooseBlocks()
                append(.heading(level: heading.level, text: heading.text))
                index += 1
                continue
            }

            if let quote = parseQuote(trimmed) {
                flushParagraph()
                flushUnorderedList()
                flushOrderedList()
                quoteLines.append(quote)
                index += 1
                continue
            }

            if let listItem = parseUnorderedListItem(trimmed) {
                flushParagraph()
                flushOrderedList()
                flushQuote()
                unorderedItems.append(listItem)
                index += 1
                continue
            }

            if let listItem = parseOrderedListItem(trimmed) {
                flushParagraph()
                flushUnorderedList()
                flushQuote()
                orderedItems.append(listItem)
                index += 1
                continue
            }

            if !unorderedItems.isEmpty {
                unorderedItems[unorderedItems.count - 1] += " " + trimmed
            } else if !orderedItems.isEmpty {
                let last = orderedItems.removeLast()
                orderedItems.append((last.number, last.text + " " + trimmed))
            } else if !quoteLines.isEmpty {
                quoteLines.append(trimmed)
            } else {
                paragraphLines.append(trimmed)
            }

            index += 1
        }

        if inCodeFence {
            append(.code(language: codeLanguage, code: codeLines.joined(separator: "\n")))
        }

        flushLooseBlocks()

        if blocks.isEmpty {
            append(.paragraph("Working..."))
        }

        return blocks
    }

    private static func parseHeading(_ line: String) -> (level: Int, text: String)? {
        var level = 0
        for character in line {
            if character == "#" {
                level += 1
            } else {
                break
            }
        }

        guard (1...6).contains(level) else { return nil }
        let index = line.index(line.startIndex, offsetBy: level)
        guard index < line.endIndex, line[index] == " " else { return nil }
        return (level, String(line[line.index(after: index)...]))
    }

    private static func parseQuote(_ line: String) -> String? {
        guard line.hasPrefix(">") else { return nil }
        return String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
    }

    private static func isDivider(_ line: String) -> Bool {
        guard line.count >= 3 else { return false }
        return line.allSatisfy { $0 == "-" || $0 == "*" || $0 == "_" }
    }

    private static func parseUnorderedListItem(_ line: String) -> String? {
        guard line.count >= 2 else { return nil }
        let first = line[line.startIndex]
        let next = line[line.index(after: line.startIndex)]
        guard ["-", "*", "+"].contains(first), next == " " else { return nil }
        return String(line.dropFirst(2))
    }

    private static func parseOrderedListItem(_ line: String) -> (number: Int, text: String)? {
        guard let dotIndex = line.firstIndex(of: ".") else { return nil }
        let numberText = String(line[..<dotIndex])
        guard let number = Int(numberText), dotIndex < line.index(before: line.endIndex) else { return nil }
        let afterDot = line.index(after: dotIndex)
        guard line[afterDot] == " " else { return nil }
        return (number, String(line[line.index(after: afterDot)...]))
    }

    private static func parseTable(
        lines: [String],
        startingAt index: Int
    ) -> (header: [String], rows: [[String]], nextIndex: Int)? {
        guard index + 1 < lines.count else { return nil }
        let headerLine = lines[index].trimmingCharacters(in: .whitespaces)
        let separatorLine = lines[index + 1].trimmingCharacters(in: .whitespaces)
        guard headerLine.contains("|"), isTableSeparator(separatorLine) else { return nil }

        let header = splitTableRow(headerLine)
        guard header.count > 1 else { return nil }

        var rows: [[String]] = []
        var nextIndex = index + 2
        while nextIndex < lines.count {
            let rowLine = lines[nextIndex].trimmingCharacters(in: .whitespaces)
            guard rowLine.contains("|"), !rowLine.isEmpty else { break }
            rows.append(splitTableRow(rowLine))
            nextIndex += 1
        }

        return (header, rows, nextIndex)
    }

    private static func isTableSeparator(_ line: String) -> Bool {
        guard line.contains("|") else { return false }
        let cells = splitTableRow(line)
        guard cells.count > 1 else { return false }
        return cells.allSatisfy { cell in
            let trimmed = cell.trimmingCharacters(in: CharacterSet(charactersIn: " :-"))
            return trimmed.isEmpty && cell.contains("-")
        }
    }

    private static func splitTableRow(_ line: String) -> [String] {
        var row = line
        if row.hasPrefix("|") {
            row.removeFirst()
        }
        if row.hasSuffix("|") {
            row.removeLast()
        }
        return row
            .split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }
}

private struct MarkdownHeading: View {
    let level: Int
    let text: String

    var body: some View {
        Text(inlineMarkdown(text))
            .font(font)
            .foregroundStyle(.white.opacity(0.94))
            .lineLimit(nil)
            .textSelection(.enabled)
            .padding(.top, level <= 2 ? 4 : 1)
    }

    private var font: Font {
        switch level {
        case 1:
            return .system(size: 24, weight: .semibold)
        case 2:
            return .system(size: 20, weight: .semibold)
        case 3:
            return .system(size: 17, weight: .semibold)
        default:
            return .system(size: 15, weight: .semibold)
        }
    }
}

private struct MarkdownParagraph: View {
    let text: String

    var body: some View {
        Text(inlineMarkdown(text))
            .font(.system(size: 15))
            .foregroundStyle(.white.opacity(0.87))
            .lineSpacing(4)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct MarkdownList: View {
    let items: [String]
    let style: MarkdownListStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 10) {
                    marker(for: index)
                        .padding(.top, 2)

                    Text(inlineMarkdown(displayText(for: item)))
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.86))
                        .lineSpacing(3)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.vertical, 1)
    }

    @ViewBuilder
    private func marker(for index: Int) -> some View {
        let taskState = taskState(for: items[index])
        switch style {
        case .unordered:
            if let taskState {
                Image(systemName: taskState ? "checkmark.square.fill" : "square")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(taskState ? CodexTheme.good.opacity(0.82) : .white.opacity(0.38))
                    .frame(width: 18, height: 18)
            } else {
                Circle()
                    .fill(CodexTheme.accent.opacity(0.72))
                    .frame(width: 5, height: 5)
                    .frame(width: 18, height: 18)
            }
        case .ordered(let numbers):
            Text("\(numbers[index]).")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.46))
                .frame(width: 28, alignment: .trailing)
        }
    }

    private func taskState(for item: String) -> Bool? {
        let lowercased = item.lowercased()
        if lowercased.hasPrefix("[x] ") {
            return true
        }
        if lowercased.hasPrefix("[ ] ") {
            return false
        }
        return nil
    }

    private func displayText(for item: String) -> String {
        if taskState(for: item) != nil {
            return String(item.dropFirst(4))
        }
        return item
    }
}

private struct MarkdownQuote: View {
    let text: String

    var body: some View {
        Text(inlineMarkdown(text))
            .font(.system(size: 15))
            .foregroundStyle(.white.opacity(0.72))
            .lineSpacing(3)
            .textSelection(.enabled)
            .padding(.leading, 13)
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 3)
            }
    }
}

private struct MarkdownCodeBlock: View {
    let language: String?
    let code: String
    @State private var didCopy = false

    private var displayLanguage: String {
        language?.isEmpty == false ? language! : "code"
    }

    private var codeLines: [String] {
        let lines = code.components(separatedBy: "\n")
        return lines.isEmpty ? [""] : lines
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "curlybraces")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(GitHubStyle.mutedText)

                Text(displayLanguage)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(GitHubStyle.mutedText)

                Spacer()

                Button {
                    copyCode()
                } label: {
                    Label(didCopy ? "Copied" : "Copy", systemImage: didCopy ? "checkmark" : "doc.on.doc")
                        .labelStyle(.titleAndIcon)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(GitHubStyle.mutedText)
                }
                .buttonStyle(.plain)
                .help("Copy code")
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .background(GitHubStyle.header)

            Divider()
                .overlay(GitHubStyle.border)

            ScrollView(.horizontal, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(codeLines.enumerated()), id: \.offset) { index, line in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(GitHubStyle.lineNumber)
                                .frame(width: 34, alignment: .trailing)
                                .textSelection(.disabled)

                            Text(SyntaxHighlighter.highlight(line, language: language))
                                .textSelection(.enabled)
                                .frame(minWidth: 1, alignment: .leading)
                        }
                        .padding(.vertical, 1)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 13)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(GitHubStyle.body)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(GitHubStyle.border)
        )
        .shadow(color: .black.opacity(0.14), radius: 8, y: 3)
    }

    private func copyCode() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        withAnimation(.easeOut(duration: 0.15)) {
            didCopy = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.15)) {
                didCopy = false
            }
        }
    }
}

private struct MarkdownDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.10))
            .frame(height: 1)
            .padding(.vertical, 4)
    }
}

private struct MarkdownTable: View {
    let header: [String]
    let rows: [[String]]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    ForEach(Array(header.enumerated()), id: \.offset) { _, cell in
                        tableCell(cell, isHeader: true)
                    }
                }

                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    GridRow {
                        ForEach(0..<header.count, id: \.self) { column in
                            tableCell(column < row.count ? row[column] : "", isHeader: false)
                        }
                    }
                }
            }
            .background(Color.white.opacity(0.025))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.10))
            )
        }
    }

    private func tableCell(_ text: String, isHeader: Bool) -> some View {
        Text(inlineMarkdown(text))
            .font(.system(size: 13, weight: isHeader ? .semibold : .regular))
            .foregroundStyle(.white.opacity(isHeader ? 0.88 : 0.76))
            .lineLimit(nil)
            .textSelection(.enabled)
            .frame(minWidth: 120, maxWidth: 260, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(isHeader ? Color.white.opacity(0.055) : Color.clear)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)
            }
            .overlay(alignment: .trailing) {
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 1)
            }
    }
}

private enum GitHubStyle {
    static let body = Color(hex: 0x0D1117)
    static let header = Color(hex: 0x161B22)
    static let border = Color(hex: 0x30363D)
    static let text = Color(hex: 0xC9D1D9)
    static let mutedText = Color(hex: 0x8B949E)
    static let lineNumber = Color(hex: 0x6E7681)
}

private func inlineMarkdown(_ text: String) -> AttributedString {
    let options = AttributedString.MarkdownParsingOptions(
        interpretedSyntax: .inlineOnlyPreservingWhitespace
    )
    return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
}

private enum SyntaxHighlighter {
    static func highlight(_ line: String, language: String?) -> AttributedString {
        let displayLine = line.isEmpty ? " " : line
        let attributed = NSMutableAttributedString(
            string: displayLine,
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
                .foregroundColor: NSColor(hex: 0xC9D1D9),
            ]
        )

        apply(pattern: #""(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|`(?:\\.|[^`\\])*`"#, color: 0xA5D6FF, to: attributed)
        apply(pattern: #"\b\d+(?:\.\d+)?\b"#, color: 0x79C0FF, to: attributed)
        apply(pattern: keywordPattern(for: language), color: 0xFF7B72, to: attributed)
        apply(pattern: #"(?://.*|#.*|/\*.*\*/)"#, color: 0x8B949E, to: attributed)

        return AttributedString(attributed)
    }

    private static func keywordPattern(for language: String?) -> String {
        let normalized = language?.lowercased() ?? ""
        let keywords: [String]

        switch normalized {
        case "swift":
            keywords = ["actor", "associatedtype", "case", "class", "enum", "extension", "func", "guard", "if", "import", "let", "private", "protocol", "return", "self", "static", "struct", "switch", "var", "where"]
        case "js", "jsx", "javascript", "ts", "tsx", "typescript":
            keywords = ["async", "await", "case", "catch", "class", "const", "export", "for", "from", "function", "if", "import", "let", "new", "return", "switch", "throw", "try", "type", "var"]
        case "py", "python":
            keywords = ["as", "async", "await", "class", "def", "elif", "else", "except", "for", "from", "if", "import", "in", "lambda", "return", "try", "with", "yield"]
        case "sh", "bash", "zsh":
            keywords = ["case", "do", "done", "elif", "else", "esac", "fi", "for", "function", "if", "in", "then", "while"]
        default:
            keywords = ["case", "class", "const", "enum", "func", "function", "if", "import", "let", "private", "return", "static", "struct", "var"]
        }

        return #"(?<![\w])("# + keywords.joined(separator: "|") + #")(?![\w])"#
    }

    private static func apply(pattern: String, color: UInt32, to attributed: NSMutableAttributedString) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let range = NSRange(location: 0, length: attributed.string.utf16.count)
        regex.enumerateMatches(in: attributed.string, range: range) { match, _, _ in
            guard let match else { return }
            attributed.addAttribute(.foregroundColor, value: NSColor(hex: color), range: match.range)
        }
    }
}

private extension NSColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xff) / 255,
            green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255,
            alpha: 1
        )
    }
}
