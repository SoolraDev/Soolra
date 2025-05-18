//
//  SaveStateView.swift
//  SOOLRA
//
//  Created by Kai Yoshida on 29/04/2025.
//


// SaveStateView.swift
import SwiftUI

struct SaveStateView: View {
    @EnvironmentObject var manager: SaveStateManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss
    var consoleManager: ConsoleCoreManager
    var pauseViewModel: PauseGameViewModel
    var mode: Mode
    
    @State private var stateToRename: SaveState?
    @State private var newName: String = ""
    @State private var isRenaming: Bool = false
    
    enum Mode {
        case saving
        case loading
    }
    
    var body: some View {
        List {
          ForEach(manager.states(for: consoleManager.gameName)) { state in
            // 1️⃣ Build your row
            HStack {
              if let image = manager.thumbnail(for: state) {
                Image(uiImage: image)
                  .resizable()
                  .frame(width: 80, height: 60)
                  .cornerRadius(4)
              } else {
                Rectangle()
                  .fill(Color.gray)
                  .frame(width: 80, height: 60)
              }

              VStack(alignment: .leading) {
                Text(state.localizedName)
                  .font(.headline)
                Text(state.date.formatted())
                  .font(.subheadline)
              }

              Spacer()

                if mode == .loading {
                        Button("Load") {
                            manager.load(state: state, into: consoleManager)
                            dismiss()
                            pauseViewModel.togglePause()
                        }
                    } else if mode == .saving {
                        Button("Overwrite") {
                            manager.overwrite(state: state, with: consoleManager)
                        }
                    }
            }
            // 2️⃣ Now *attach* your swipe actions to that HStack
            .swipeActions(edge: .trailing) {
              Button(role: .destructive) {
                manager.delete(state: state)
              } label: {
                Label("Delete", systemImage: "trash")
              }

              Button {
                beginRenaming(state)
              } label: {
                Label("Rename", systemImage: "pencil")
              }
              .tint(.blue)
            }
          }
          .onDelete { indexSet in
            indexSet.forEach { manager.delete(state: manager.saveStates[$0]) }
          }
        }
        .alert("Rename Save", isPresented: $isRenaming) {
          TextField("New name", text: $newName)
          Button("Save") {
            if let state = stateToRename {
              manager.rename(state: state, to: newName)
            }
          }
          Button("Cancel", role: .cancel) { }
        }

        .navigationTitle(mode == .loading ? "Load State" : "Save State")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Back") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if mode == .saving {
                    Button("New Save") {
                        manager.saveNewState(from: consoleManager, name: nil)
                    }
                } else {
                    EmptyView() // Required to resolve ambiguity
                }
            }
        }
        .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
        .alert("Rename Save", isPresented: $isRenaming) {
            TextField("New name", text: $newName)
            Button("Save") {
                if let state = stateToRename {
                    manager.rename(state: state, to: newName)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        
    }
    
    private func beginRenaming(_ state: SaveState) {
        stateToRename = state
        newName = state.name ?? ""
        isRenaming = true
    }

    
}
