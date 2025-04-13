//
//  AddCheatView.swift
//  SOOLRA
//  

import SwiftUI

struct AddCheatView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager

    @State private var cheatName: String = ""
    @State private var cheatCode: String = ""

    var gameName: String
    var onSave: (Cheat) -> Void

    var body: some View {
        VStack(spacing: 20) {
            TextField("Cheat Name", text: $cheatName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)

            TextField("Cheat Code", text: $cheatCode)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)

            HStack {
                Button("Back") {
                    dismiss()
                }

                Spacer()

                Button("Save") {
                    let newCheat = Cheat(
                        code: cheatCode,
                        type: .actionReplay, // or default value
                        name: cheatName,
                        isActive: false
                    )

                    if validate(cheat: newCheat) {
                        onSave(newCheat)
                        dismiss()
                    }
                }
                .disabled(!canSave)
            }
            .padding(.horizontal)
        }
        .navigationTitle("Add Cheat")
        .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
    }

    private var canSave: Bool {
        !cheatName.isEmpty && !cheatCode.isEmpty
    }

    private func validate(cheat: Cheat) -> Bool {
        // TODO: Add real validation logic
        return true
    }
}
