import SwiftUI

struct CheatCodesView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var consoleManager: ConsoleCoreManager
    @State private var cheats: [Cheat] = []
    @State private var showAddCheatView = false
    private let storage = CheatStorage()
    let gameName: String
    var body: some View {
        List {
            ForEach(cheats.indices, id: \.self) { index in
                Button(action: {
                    cheats[index].isActive.toggle()
                    storage.saveCheats(cheats, for: gameName)

                    if cheats[index].isActive {
                        consoleManager.activateCheat(cheats[index])
                    }
                })
 {
                    HStack {
                        Text(cheats[index].name)
                        Spacer()
                        if cheats[index].isActive {
                            Image(systemName: "checkmark")
                                .foregroundColor(.green)
                        }
                    }
                }
            }
        }
        .onAppear {
            cheats = storage.loadCheats(for: gameName)
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
            AddCheatView(gameName: gameName) { newCheat in
                cheats.append(newCheat)
                storage.saveCheats(cheats, for: gameName)
            }
            .environmentObject(themeManager)
        }
        .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
    }
}
