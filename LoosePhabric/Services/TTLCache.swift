//
//  TTLCache.swift
//  LoosePhabric
//

import Foundation

// In-memory cache with a fixed lifetime for each entry. Handlers call it from URLSession queues, so a lock protects it.
final class TTLCache<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var entries: [String: (value: Value, expires: Date)] = [:]
    private let ttl: TimeInterval

    init(ttl: TimeInterval) {
        self.ttl = ttl
    }

    func get(_ key: String) -> Value? {
        lock.withLock {
            guard let entry = entries[key], entry.expires > Date() else { return nil }
            return entry.value
        }
    }

    func set(_ key: String, _ value: Value) {
        lock.withLock {
            let now = Date()
            // Remove expired entries here, so that the cache does not grow without limit.
            entries = entries.filter { $0.value.expires > now }
            entries[key] = (value, now.addingTimeInterval(ttl))
        }
    }
}
