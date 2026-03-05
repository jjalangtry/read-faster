import SwiftUI

struct SentenceContextView: View {
    let bookContent: String
    let allBookWords: [String]
    let globalWordIndex: Int
    var highlightCount: Int = 1

    @State private var lineStarts: [Int] = []
    @State private var splitLines: [String] = []
    @State private var lastLine: Int = -1
    @State private var built = false

    private var highlightEnd: Int {
        min(globalWordIndex + highlightCount, allBookWords.count)
    }

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
                            if line.trimmingCharacters(in: .whitespaces)
                                .isEmpty
                            {
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
                    if !built { buildOnce() }
                    scrollToLine(proxy, animated: false)
                }
                .onChange(of: globalWordIndex) { _, _ in
                    scrollToLine(proxy, animated: true)
                }
            }
        }
    }

    private func buildOnce() {
        splitLines = bookContent.components(separatedBy: .newlines)
        var starts: [Int] = []
        var count = 0
        for line in splitLines {
            starts.append(count)
            count += line.split(whereSeparator: {
                $0.isWhitespace || $0.isNewline
            }).count
        }
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

    private func scrollToLine(
        _ proxy: ScrollViewProxy, animated: Bool
    ) {
        let line = lineForWord(globalWordIndex)
        guard line != lastLine else { return }
        lastLine = line
        if animated {
            withAnimation(.easeInOut(duration: 0.4)) {
                proxy.scrollTo(line, anchor: .center)
            }
        } else {
            proxy.scrollTo(line, anchor: .center)
        }
    }

    private func lineGlobalStart(_ lineIdx: Int) -> Int {
        guard lineIdx < lineStarts.count else { return allBookWords.count }
        return lineStarts[lineIdx]
    }

    @ViewBuilder
    private func lineView(_ line: String, lineIndex: Int) -> some View {
        let lineWords = line.split(whereSeparator: \.isWhitespace)
            .map(String.init)
        let start = lineGlobalStart(lineIndex)
        let end = start + lineWords.count

        let hasHL = globalWordIndex < end && highlightEnd > start

        if hasHL {
            highlightedLine(line, lineWords: lineWords, start: start)
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
        _ line: String, lineWords: [String], start: Int
    ) -> some View {
        var attr = AttributedString()
        var searchFrom = line.startIndex

        for (localIdx, word) in lineWords.enumerated() {
            let gIdx = start + localIdx

            guard let range = line.range(
                of: word,
                range: searchFrom..<line.endIndex
            ) else { continue }

            if searchFrom < range.lowerBound {
                var gap = AttributedString(
                    String(line[searchFrom..<range.lowerBound])
                )
                gap.foregroundColor = gIdx <= globalWordIndex
                    ? Color.primary.opacity(0.5)
                    : Color.primary.opacity(0.35)
                attr.append(gap)
            }

            var wordAttr = AttributedString(word)
            if gIdx >= globalWordIndex && gIdx < highlightEnd {
                wordAttr.foregroundColor = Color.primary
                wordAttr.underlineStyle = .single
                wordAttr.underlineColor = Color.accentColor
            } else if gIdx < globalWordIndex {
                wordAttr.foregroundColor = Color.primary.opacity(0.5)
            } else {
                wordAttr.foregroundColor = Color.primary.opacity(0.35)
            }
            attr.append(wordAttr)
            searchFrom = range.upperBound
        }

        if searchFrom < line.endIndex {
            var tail = AttributedString(String(line[searchFrom...]))
            tail.foregroundColor = Color.primary.opacity(0.35)
            attr.append(tail)
        }

        return Text(attr)
            .font(AppFont.contextWord(highlighted: false))
    }
}
