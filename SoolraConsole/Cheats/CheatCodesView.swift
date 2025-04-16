import SwiftUI

struct CheatCodesView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var consoleManager: ConsoleCoreManager
    @State private var showAddCheatView = false
    @State private var cheatBeingEdited: Cheat?
    @ObservedObject private var cheatManager: CheatCodesManager
    @State private var editContext: CheatEditContext?

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
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        withAnimation {
                            cheatManager.deleteCheat(at: index)
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }


                    Button {
                        editContext = .edit(cheatManager.cheats[index])
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.blue)

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
                    editContext = .new
                }
            }
        }

        .sheet(item: $editContext, onDismiss: {
            editContext = nil
        }) { context in
            AddCheatView(existingCheat: context.existingCheat) { newCheat in
                switch context {
                case .edit(let original):
                    cheatManager.updateCheat(original: original, updated: newCheat)
                case .new:
                    cheatManager.addCheat(newCheat)
                }
                editContext = nil
            }
            .environmentObject(themeManager)
        }




        .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
    }
    
    private func showEditSheet(for index: Int) {
        cheatBeingEdited = cheatManager.cheats[index]
        DispatchQueue.main.async {
            showAddCheatView = true
        }
    }


}
enum CheatEditContext: Identifiable {
    case new
    case edit(Cheat)

    var id: String {
        switch self {
        case .new: return "new"
        case .edit(let cheat): return cheat.name + cheat.code
        }
    }

    var existingCheat: Cheat? {
        if case .edit(let cheat) = self {
            return cheat
        }
        return nil
    }
}
