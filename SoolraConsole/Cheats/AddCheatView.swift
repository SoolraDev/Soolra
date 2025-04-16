//
//  AddCheatView.swift
//  SOOLRA
//  

import SwiftUI

struct AddCheatView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    let existingCheat: Cheat?
    @State private var cheatName: String = ""
    @State private var cheatCode: String = ""
    @State private var didSetInitialValues = false



    init(existingCheat: Cheat?, onSave: @escaping (Cheat) -> Void) {
        self.existingCheat = existingCheat
        self.onSave = onSave
    }


    var onSave: (Cheat) -> Void

    var body: some View {
        VStack(spacing: 20) {
            TextField("Cheat Name", text: $cheatName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)

            TextEditor(text: $cheatCode)
                .frame(minHeight: 120)
                .padding(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                )
                .padding(.horizontal)
                .onChange(of: cheatCode) { newValue in
                    cheatCode = insertLineBreaks(every: 13, in: newValue)
                }


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
        .onAppear {
            if !didSetInitialValues, let cheat = existingCheat {
                cheatName = cheat.name
                cheatCode = cheat.code
                didSetInitialValues = true
            }
        }

        .onDisappear {
            cheatName = ""
            cheatCode = ""
            didSetInitialValues = false
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
    private func insertLineBreaks(every n: Int, in text: String) -> String {
        // Remove existing line breaks
        let cleaned = text.replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: "\r", with: "")
        
        // Chunk into segments of n characters
        var result = ""
        for (index, char) in cleaned.enumerated() {
            if index > 0 && index % n == 0 {
                result.append("\n")
            }
            result.append(char)
        }
        return result
    }

    
}
