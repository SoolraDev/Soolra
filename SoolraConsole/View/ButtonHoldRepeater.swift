//
//  ButtonHoldRepeater.swift
//  SOOLRA
//
//  Created by Kai Yoshida on 29/10/2025.
//


final class ButtonHoldRepeater {
    private var task: Task<Void, Never>?

    func start(initialDelay: Double = 0.28,
               baseInterval: Double = 0.11,
               accelerations: [Int: Double] = [6: 0.085, 16: 0.060],
               tick: @escaping @MainActor () -> Void) {
        cancel()
        task = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(initialDelay * 1_000_000_000))
            var step = 0
            var interval = baseInterval
            while !Task.isCancelled {
                tick()
                step += 1
                if let new = accelerations[step] { interval = new }
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}
