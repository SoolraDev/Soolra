import SwiftUI

struct CheatCodesView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var consoleManager: ConsoleCoreManager
    @State private var showAddCheatView = false
    @ObservedObject private var cheatManager: CheatCodesManager

    init(consoleManager: ConsoleCoreManager) {
        self._cheatManager = ObservedObject(wrappedValue: consoleManager.cheatCodesManager!)
    }


    
    var body: some View {
        List {
            ForEach(cheatManager.cheats.indices, id: \.self) { index in
                Button(action: {
                    cheatManager.toggleCheat(at: index)
                }) {
                    HStack {
                        Text(cheatManager.cheats[index].name)
                        Spacer()
                        if cheatManager.cheats[index].isActive {
                            Image(systemName: "checkmark")
                                .foregroundColor(.green)
                        }
                    }
                }
            }
        }
        .navigationTitle("Cheat Codes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Back") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Add") {
                    showAddCheatView = true
                }
            }
        }
        .sheet(isPresented: $showAddCheatView) {
            AddCheatView() { newCheat in
                cheatManager.addCheat(newCheat)
            }
            .environmentObject(themeManager)
        }

        .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
    }

}
