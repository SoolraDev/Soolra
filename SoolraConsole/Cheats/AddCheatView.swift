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
                        reformatCheatCode(for: type)
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
                        let formatted = formatCheatCode(newValue, for: selectedType)
                        if formatted != cheatCode {
                            cheatCode = formatted
                        }
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
                        type: CheatType(rawValue: selectedType.rawValue) ?? .codeBreaker,
                        name: cheatName,
                        isActive: true
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
            if !didSetInitialValues {
                if let cheat = existingCheat {
                    cheatName = cheat.name
                    cheatCode = cheat.code
                    selectedType = CheatTypeUI(rawValue: cheat.type.rawValue) ?? availableCheatTypes.first!
                } else {
                    selectedType = availableCheatTypes.first! // ✅ default to first available type
                }
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


    private var availableCheatTypes: [CheatTypeUI] {
        switch consoleType {
        case .gba:
            return [.actionReplay, .codeBreaker, .gameShark]
        case .nes:
            return [.gameGenie6, .gameGenie8]
        }
    }
    
    private func allowedCharacters(for type: CheatTypeUI) -> CharacterSet {
        switch type {
        case .actionReplay, .gameShark, .codeBreaker:
            return CharacterSet(charactersIn: "0123456789ABCDEF")
        case .gameGenie6, .gameGenie8:
            return CharacterSet(charactersIn: "APZLGITYEOXUKSVN")
        }
    }

    private func formatCheatCode(_ raw: String, for type: CheatTypeUI) -> String {
        let uppercase = raw.uppercased()
        let cleaned = uppercase.filter { allowedCharacters(for: type).contains($0.unicodeScalars.first!) }

        switch type {
        case .codeBreaker:
            return cleaned.chunkedCodeBreaker().joined(separator: "\n")
        case .actionReplay, .gameShark:
            return cleaned.chunked(into: 8).joined(separator: " ")
        case .gameGenie6:
            return cleaned.chunked(into: 6).joined(separator: "\n")
        case .gameGenie8:
            return cleaned.chunked(into: 8).joined(separator: "\n")
        }
    }
    
    private func reformatCheatCode(for type: CheatTypeUI) {
        let reformatted = formatCheatCode(cheatCode, for: type)
        if reformatted != cheatCode {
            cheatCode = reformatted
        }
    }


    
}

extension String {
    func chunked(into size: Int) -> [String] {
        stride(from: 0, to: count, by: size).map {
            let start = index(startIndex, offsetBy: $0)
            let end = index(start, offsetBy: size, limitedBy: endIndex) ?? endIndex
            return String(self[start..<end])
        }
    }

    // ✅ CodeBreaker-specific format: 8 + 4 per line
    func chunkedCodeBreaker() -> [String] {
        var result: [String] = []
        var i = 0
        while i + 8 <= count {
            let start = index(startIndex, offsetBy: i)
            let mid = index(start, offsetBy: 8)
            let end = index(mid, offsetBy: 4, limitedBy: endIndex) ?? endIndex
            let firstPart = String(self[start..<mid])
            let secondPart = String(self[mid..<end])
            result.append([firstPart, secondPart].joined(separator: secondPart.isEmpty ? "" : " "))
            i += 12
        }
        return result
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
