import SwiftUI

struct SentenceContextView: View {
    let bookContent: String
    let allBookWords: [String]
    let globalWordIndex: Int
    var highlightCount: Int = 1

    @State private var lineStarts: [Int] = []
    @State private var splitLines: [String] = []
    @State private var built = false

    private var highlightEnd: Int {
        min(globalWordIndex + highlightCount, allBookWords.count)
    }

    private let maxLineWords = 12

    var body: some View {
        if allBookWords.isEmpty {
            EmptyView()
        } else {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(
                            Array(splitLines.enumerated()), id: \.offset
                        ) { lineIdx, line in
                            if line.isEmpty {
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
                .onAppear {
                    if !built { buildLines() }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        let target = lineForWord(globalWordIndex)
                        proxy.scrollTo(target, anchor: .center)
                    }
                }
                .onChange(of: globalWordIndex) { _, _ in
                    if !built { buildLines() }
                    let target = lineForWord(globalWordIndex)
                    withAnimation(.easeInOut(duration: 0.35)) {
                        proxy.scrollTo(target, anchor: .center)
                    }
                }
            }
        }
    }

    private func buildLines() {
        let rawLines = bookContent.components(separatedBy: .newlines)
        var result: [String] = []
        var starts: [Int] = []
        var wordCount = 0

        for rawLine in rawLines {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                result.append("")
                starts.append(wordCount)
                continue
            }

            let words = trimmed.split(
                whereSeparator: \.isWhitespace
            ).map(String.init)

            if words.count <= maxLineWords {
                result.append(trimmed)
                starts.append(wordCount)
                wordCount += words.count
            } else {
                var idx = 0
                while idx < words.count {
                    let end = min(idx + maxLineWords, words.count)
                    let chunk = words[idx..<end].joined(separator: " ")
                    result.append(chunk)
                    starts.append(wordCount + idx)
                    idx = end
                }
                wordCount += words.count
            }
        }

        splitLines = result
        lineStarts = starts
        built = true
    }

    private func lineForWord(_ wordIdx: Int) -> Int {
        var result = 0
        for idx in 0..<lineStarts.count {
            if lineStarts[idx] > wordIdx { break }
            result = idx
        }
        return result
    }

    private func lineGlobalStart(_ lineIdx: Int) -> Int {
        guard lineIdx < lineStarts.count else { return allBookWords.count }
        return lineStarts[lineIdx]
    }

    private func lineWordCount(_ lineIdx: Int) -> Int {
        if lineIdx + 1 < lineStarts.count {
            return lineStarts[lineIdx + 1] - lineStarts[lineIdx]
        }
        return max(0, allBookWords.count - lineStarts[lineIdx])
    }

    @ViewBuilder
    private func lineView(_ line: String, lineIndex: Int) -> some View {
        let start = lineGlobalStart(lineIndex)
        let count = lineWordCount(lineIndex)
        let end = start + count
        let lineWords = line.split(
            whereSeparator: \.isWhitespace
        ).map(String.init)

        let hasHL = globalWordIndex < end && highlightEnd > start

        if hasHL {
            highlightedLine(lineWords: lineWords, start: start)
        } else if end <= globalWordIndex {
            Text(line)
                .font(AppFont.contextWord(highlighted: false))
                .foregroundColor(Color.primary.opacity(0.5))
        } else {
            Text(line)
                .font(AppFont.contextWord(highlighted: false))
                .foregroundColor(Color.primary.opacity(0.35))
        }
    }

    private func highlightedLine(
        lineWords: [String], start: Int
    ) -> some View {
        var attr = AttributedString()

        for (localIdx, word) in lineWords.enumerated() {
            if localIdx > 0 {
                var space = AttributedString(" ")
                space.foregroundColor = Color.primary.opacity(0.35)
                attr.append(space)
            }

            let gIdx = start + localIdx
            var wordAttr = AttributedString(word)

            if gIdx >= globalWordIndex && gIdx < highlightEnd {
                wordAttr.foregroundColor = Color.accentColor
                wordAttr.underlineStyle = .single
            } else if gIdx < globalWordIndex {
                wordAttr.foregroundColor = Color.primary.opacity(0.5)
            } else {
                wordAttr.foregroundColor = Color.primary.opacity(0.35)
            }
            attr.append(wordAttr)
        }

        return Text(attr)
            .font(AppFont.contextWord(highlighted: false))
    }
}
