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
    var consoleManager: ConsoleCoreManager
    var mode: Mode

    enum Mode {
        case saving
        case loading
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(manager.saveStates) { state in
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
                            }
                        } else {
                            Button("Overwrite") {
                                manager.saveNewState(from: consoleManager, name: state.name)
                            }
                        }
                    }
                }
                .onDelete { indexSet in
                    indexSet.forEach { manager.delete(state: manager.saveStates[$0]) }
                }
            }
            .navigationTitle(mode == .loading ? "Load State" : "Save State")
            .toolbar {
                if mode == .saving {
                    Button("New Save") {
                        manager.saveNewState(from: consoleManager, name: nil)
                    }
                }
            }
        }
    }
}
