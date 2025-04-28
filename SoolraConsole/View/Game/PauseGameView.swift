@ViewBuilder
private func menuButton(for item: PauseMenuItem, isSelected: Bool, action: @escaping () -> Void) -> some View {
    let textColor: Color = (item == .exit) ? .red : themeManager.whitetextColor

    Button(action: action) {
        Text(item.title)
            .font(.custom("Orbitron-Bold", size: 18))
            .foregroundColor(textColor)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                Capsule()
                    .fill(themeManager.keyBackgroundColor)
                    .overlay(
                        Capsule()
                            .stroke(isSelected ? Color.white : themeManager.keyBorderColor.opacity(0.8),
                                    lineWidth: isSelected ? 3 : 2)
                            .shadow(color: themeManager.keyShadowColor, radius: 4, x: 0, y: 2)
                    )
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
    }
    .animation(.easeInOut(duration: 0.2), value: isSelected)
}
