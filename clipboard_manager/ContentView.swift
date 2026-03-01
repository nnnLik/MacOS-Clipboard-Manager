import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var historyStore: ClipboardHistoryStore

    @State private var selectedID: ClipboardItem.ID?
    @FocusState private var isFocused: Bool

    var body: some View {
        ScrollViewReader { proxy in
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("История буфера")
                        .font(.headline)
                    Spacer()
                    if !historyStore.items.isEmpty {
                        Button(
                            action: {
                                historyStore.clearHistory()
                                selectedID = nil
                            },
                            label: {
                                Image(systemName: "trash")
                                    .imageScale(.small)
                            }
                        )
                        .buttonStyle(BorderlessButtonStyle())
                        .help("Очистить буфер")
                    }
                }

                if historyStore.items.isEmpty {
                    Text("Нет элементов в истории")
                        .foregroundColor(.secondary)
                        .frame(width: 260, height: 160, alignment: .center)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 6) {
                            ForEach(historyStore.items) { item in
                                ClipRowView(
                                    item: item,
                                    isSelected: item.id == selectedID
                                )
                                .id(item.id)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedID = item.id
                                }
                                .onTapGesture(count: 2) {
                                    selectedID = item.id
                                    activateSelection()
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(width: 280, height: 260)
                }
            }
            .padding(12)
            .focusable()
            .focused($isFocused)
            .onAppear {
                isFocused = true
                if selectedID == nil {
                    selectedID = historyStore.items.first?.id
                }
            }
            .onChange(of: selectedID) {
                if let id = selectedID {
                    withAnimation {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
            .onChange(of: historyStore.items.count) {
                if historyStore.items.count == 0 {
                    selectedID = nil
                } else if selectedID == nil {
                    selectedID = historyStore.items.first?.id
                }
            }
            .onMoveCommand { direction in
                guard !historyStore.items.isEmpty else { return }
                guard let currentID = selectedID,
                      let currentIndex = historyStore.items.firstIndex(where: { $0.id == currentID }) else {
                    selectedID = historyStore.items.first?.id
                    return
                }

                switch direction {
                case .up:
                    let newIndex = max(
                        historyStore.items.startIndex,
                        historyStore.items.index(before: currentIndex))
                    selectedID = historyStore.items[newIndex].id
                case .down:
                    let newIndex = min(
                        historyStore.items.index(before: historyStore.items.endIndex),
                        historyStore.items.index(after: currentIndex))
                    selectedID = historyStore.items[newIndex].id
                default:
                    break
                }
            }
            .overlay(
                Button("") {
                    activateSelection()
                }
                .keyboardShortcut(.defaultAction)
                .opacity(0)
                .allowsHitTesting(false)
            )
        }
    }


    private func activateSelection() {
        let effectiveID: ClipboardItem.ID?

        if let id = selectedID {
            effectiveID = id
        } else {
            effectiveID = historyStore.items.first?.id
        }

        guard
            let id = effectiveID,
            let item = historyStore.items.first(where: { $0.id == id })
        else { return }

        historyStore.moveToTop(item)
        historyStore.recopy(item)
    }
}

// Вынесенная строка — при смене selectedID перерисовываются только две строки (старая/новая выбранная).
private struct ClipRowView: View {
    let item: ClipboardItem
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.content)
                .font(.body)
                .lineLimit(3)
            Text(item.date, style: .time)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        )
    }
}
