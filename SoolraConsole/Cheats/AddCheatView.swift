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
    @State private var selectedType: CheatTypeUI = .actionReplay

    let consoleType: ConsoleCoreManager.ConsoleType
    private var gbaTypes: [CheatTypeUI] {
        [.actionReplay, .codeBreaker, .gameShark]
    }
    private var nesTypes: [CheatTypeUI] {
        [.gameGenie6, .gameGenie8]
    }



    init(existingCheat: Cheat?, consoleType: ConsoleCoreManager.ConsoleType, onSave: @escaping (Cheat) -> Void) {
        self.existingCheat = existingCheat
        self.consoleType = consoleType
        self.onSave = onSave
    }



    var onSave: (Cheat) -> Void

    var body: some View {
        ScrollView {
        VStack(spacing: 20) {
            TextField("Cheat Name", text: $cheatName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            HStack(spacing: 8) {
                ForEach(availableCheatTypes) { type in
                    Button(action: {
                        selectedType = type
                    }) {
                        Text(type.rawValue)
                            .font(.system(size: 13, weight: .medium))
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(
                                Capsule()
                                    .fill(selectedType == type ? Color.accentColor : Color.gray.opacity(0.2))
                            )
                            .foregroundColor(selectedType == type ? .white : .primary)
                    }
                }
            }
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 4) {
                Text("Code")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                TextEditor(text: $cheatCode)
                    .frame(height: 240) // ✅ half height
                    .padding(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                    )
                    .padding(.horizontal)
                    .onChange(of: cheatCode) { newValue in
                        cheatCode = insertLineBreaks(every: 13, in: newValue)
                    }
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
        .frame(maxWidth: .infinity, alignment: .top)
        .padding(.top, 20)
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

    private var availableCheatTypes: [CheatTypeUI] {
        switch consoleType {
        case .gba:
            return [.actionReplay, .codeBreaker, .gameShark]
        case .nes:
            return [.gameGenie6, .gameGenie8]
        }
    }

    
    
}
enum CheatTypeUI: String, CaseIterable, Identifiable {
    case actionReplay = "Action Replay"
    case codeBreaker = "Code Breaker"
    case gameShark = "GameShark"
    case gameGenie6 = "Game Genie (6)"
    case gameGenie8 = "Game Genie (8)"

    var id: String { rawValue }
}
