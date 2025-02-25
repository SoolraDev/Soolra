//
//  SOOLRA
//
//  Copyright © 2025 SOOLRA. All rights reserved.
//

import MetalKit
import Combine

@MainActor
public final class MetalManager: ObservableObject {
    public static var shared: MetalManager!
    
    public let device: MTLDevice
    private var commandQueues: [String: MTLCommandQueue] = [:]
    private let queueLock = NSLock()
    
    // Add a published property to satisfy ObservableObject requirements
    @Published private var lastQueueCreationTime: Date = Date()
    
    public init() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw MetalError.deviceCreationFailed
        }
        self.device = device
        
        // Initialize the default command queue
        try createCommandQueue(name: "default")
    }
    
    // Create a new command queue with a given name
    public func createCommandQueue(name: String) throws -> MTLCommandQueue {
        queueLock.lock()
        defer { queueLock.unlock() }
        
        if let existingQueue = commandQueues[name] {
            return existingQueue
        }
        
        guard let newQueue = device.makeCommandQueue() else {
            throw MetalError.commandQueueCreationFailed
        }
        
        commandQueues[name] = newQueue
        lastQueueCreationTime = Date()  // Update published property
        return newQueue
    }
    
    // Get an existing command queue by name
    public func getCommandQueue(name: String = "default") throws -> MTLCommandQueue {
        queueLock.lock()
        defer { queueLock.unlock() }
        
        if let queue = commandQueues[name] {
            return queue
        }
        
        return try createCommandQueue(name: name)
    }
    
    // Remove a command queue by name
    public func removeCommandQueue(name: String) {
        queueLock.lock()
        defer { queueLock.unlock() }
        
        commandQueues.removeValue(forKey: name)
        lastQueueCreationTime = Date()  // Update published property
    }
}

public enum MetalError: Error {
    case deviceCreationFailed
    case commandQueueCreationFailed
    case commandQueueNotFound
} 
