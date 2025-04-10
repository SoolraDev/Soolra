import SwiftUI

struct CheatCodesView: View {
    @Environment(\.dismiss) var dismiss
    @State private var cheatCodes = ["Infinite Lives", "Unlock All Levels", "God Mode"]

    var body: some View {
        List {
            ForEach(cheatCodes, id: \.self) { code in
                Button(action: {
                    print("Tapped cheat code: \(code)")
                }) {
                    Text(code)
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
                    print("Add tapped")
                }
            }
        }
    }
}
