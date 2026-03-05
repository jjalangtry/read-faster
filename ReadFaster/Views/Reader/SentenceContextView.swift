import SwiftUI

struct SentenceContextView: View {
    let bookContent: String
    let allBookWords: [String]
    let globalWordIndex: Int
    var highlightCount: Int = 1

    @State private var wordToLine: [Int: Int] = [:]
    @State private var lastLine: Int = -1

    private var highlightEnd: Int {
        min(globalWordIndex + highlightCount, allBookWords.count)
    }

    private var lines: [String] {
        bookContent.components(separatedBy: .newlines)
    }

    var body: some View {
        if allBookWords.isEmpty {
            EmptyView()
        } else {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(
                            Array(lines.enumerated()), id: \.offset
                        ) { lineIdx, line in
                            if line.trimmingCharacters(
                                in: .whitespaces
                            ).isEmpty {
                                Spacer().frame(height: 12).id(lineIdx)
                            } else {
                                lineView(line, lineIndex: lineIdx)
                                    .id(lineIdx)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 80)
                }
                .scrollDisabled(true)
                .onAppear { buildIndex(); scrollToCurrentLine(proxy) }
                .onChange(of: globalWordIndex) { _, _ in
                    scrollToCurrentLine(proxy)
                }
            }
        }
    }

    private func scrollToCurrentLine(_ proxy: ScrollViewProxy) {
        let line = findCurrentLine()
        if line != lastLine {
            lastLine = line
            withAnimation(.easeInOut(duration: 0.4)) {
                proxy.scrollTo(line, anchor: .center)
            }
        }
    }

    private func findCurrentLine() -> Int {
        if let cached = wordToLine[globalWordIndex] { return cached }
        var wordCount = 0
        for (lineIdx, line) in lines.enumerated() {
            let wordsInLine = line.split(whereSeparator: {
                $0.isWhitespace || $0.isNewline
            }).count
            if globalWordIndex < wordCount + wordsInLine {
                wordToLine[globalWordIndex] = lineIdx
                return lineIdx
            }
            wordCount += wordsInLine
        }
        return max(0, lines.count - 1)
    }

    private func buildIndex() {
        var wordCount = 0
        for (lineIdx, line) in lines.enumerated() {
            let wordsInLine = line.split(whereSeparator: {
                $0.isWhitespace || $0.isNewline
            }).count
            for wIdx in wordCount..<(wordCount + wordsInLine) {
                wordToLine[wIdx] = lineIdx
            }
            wordCount += wordsInLine
        }
    }

    @ViewBuilder
    private func lineView(_ line: String, lineIndex: Int) -> some View {
        let lineWords = line.split(whereSeparator: {
            $0.isWhitespace
        }).map(String.init)

        let lineGlobalStart = globalStartForLine(lineIndex)
        let lineGlobalEnd = lineGlobalStart + lineWords.count

        let hasHighlight = globalWordIndex < lineGlobalEnd
            && highlightEnd > lineGlobalStart

        if hasHighlight {
            highlightedLineText(
                line: line, lineWords: lineWords,
                lineStart: lineGlobalStart
            )
        } else if lineGlobalEnd <= globalWordIndex {
            Text(line)
                .font(AppFont.contextWord(highlighted: false))
                .foregroundColor(Color.primary.opacity(0.5))
        } else {
            Text(line)
                .font(AppFont.contextWord(highlighted: false))
                .foregroundColor(Color.primary.opacity(0.35))
        }
    }

    private func highlightedLineText(
        line: String, lineWords: [String], lineStart: Int
    ) -> some View {
        var parts: [Text] = []
        var searchFrom = line.startIndex

        for (localIdx, word) in lineWords.enumerated() {
            let gIdx = lineStart + localIdx

            guard let range = line.range(
                of: word,
                range: searchFrom..<line.endIndex
            ) else { continue }

            if searchFrom < range.lowerBound {
                let gap = String(line[searchFrom..<range.lowerBound])
                let opacity: Double = gIdx <= globalWordIndex ? 0.5 : 0.35
                parts.append(
                    Text(gap).foregroundColor(
                        Color.primary.opacity(opacity)
                    )
                )
            }

            let isHL = gIdx >= globalWordIndex && gIdx < highlightEnd

            if isHL {
                parts.append(
                    Text(word)
                        .foregroundColor(Color.primary)
                        .underline(true, color: Color.accentColor)
                )
            } else if gIdx < globalWordIndex {
                parts.append(
                    Text(word).foregroundColor(Color.primary.opacity(0.5))
                )
            } else {
                parts.append(
                    Text(word).foregroundColor(Color.primary.opacity(0.35))
                )
            }

            searchFrom = range.upperBound
        }

        if searchFrom < line.endIndex {
            parts.append(
                Text(String(line[searchFrom...]))
                    .foregroundColor(Color.primary.opacity(0.35))
            )
        }

        let combined = parts.reduce(Text(""), +)
        return combined
            .font(AppFont.contextWord(highlighted: false))
    }

    private func globalStartForLine(_ lineIndex: Int) -> Int {
        var count = 0
        for idx in 0..<lineIndex {
            count += lines[idx].split(whereSeparator: {
                $0.isWhitespace || $0.isNewline
            }).count
        }
        return count
    }
}
