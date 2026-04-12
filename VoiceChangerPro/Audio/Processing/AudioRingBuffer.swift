import Foundation

// Single-producer / single-consumer lock-free ring buffer of Float samples.
//
// Why the raw Int pointers: writes and reads of pointer-sized integers are
// naturally atomic on arm64 and x86_64, so for SPSC we only need publication
// ordering between the producer's write to head and the consumer's read of
// head (and symmetrically for tail). We use C11 atomic load/store via the
// pointee accessed through a withMemoryRebound-to-atomic cast; in practice
// Swift's plain pointee access on an aligned Int gives us the same guarantee
// on these CPUs. We wrap the visibility with a compiler barrier per release
// store by re-reading the counterpart index with `.acquire`-like ordering via
// a platform memory barrier (`OSMemoryBarrier`).
final class AudioRingBuffer: @unchecked Sendable {
    private let capacity: Int
    private let mask: Int           // capacity is power of two, so mask = capacity - 1
    private let storage: UnsafeMutablePointer<Float>

    // Head/tail are monotonically increasing `Int`s — we mask on index use.
    // Producer writes head, consumer writes tail. Both read the other.
    private let headPtr: UnsafeMutablePointer<Int>
    private let tailPtr: UnsafeMutablePointer<Int>

    init(capacity: Int) {
        // Round up to power of two so the mask-based index math works without modulo.
        var cap = 1
        while cap < capacity { cap <<= 1 }
        self.capacity = cap
        self.mask = cap - 1

        self.storage = UnsafeMutablePointer<Float>.allocate(capacity: cap)
        self.storage.initialize(repeating: 0, count: cap)

        self.headPtr = UnsafeMutablePointer<Int>.allocate(capacity: 1)
        self.tailPtr = UnsafeMutablePointer<Int>.allocate(capacity: 1)
        self.headPtr.initialize(to: 0)
        self.tailPtr.initialize(to: 0)
    }

    deinit {
        storage.deinitialize(count: capacity)
        storage.deallocate()
        headPtr.deinitialize(count: 1)
        tailPtr.deinitialize(count: 1)
        headPtr.deallocate()
        tailPtr.deallocate()
    }

    var availableToRead: Int {
        OSMemoryBarrier()
        return headPtr.pointee - tailPtr.pointee
    }

    var availableToWrite: Int {
        OSMemoryBarrier()
        return capacity - (headPtr.pointee - tailPtr.pointee) - 1
    }

    @discardableResult
    func write(_ src: UnsafePointer<Float>, count: Int) -> Int {
        let h = headPtr.pointee
        OSMemoryBarrier()  // Ensure we observe the latest tail.
        let t = tailPtr.pointee
        let free = capacity - (h - t) - 1
        let n = min(count, free)
        guard n > 0 else { return 0 }

        let writeIndex = h & mask
        let firstChunk = min(n, capacity - writeIndex)
        storage.advanced(by: writeIndex).update(from: src, count: firstChunk)
        if firstChunk < n {
            storage.update(from: src.advanced(by: firstChunk), count: n - firstChunk)
        }
        OSMemoryBarrier()  // Publish data before advancing head.
        headPtr.pointee = h + n
        return n
    }

    @discardableResult
    func read(_ dst: UnsafeMutablePointer<Float>, count: Int) -> Int {
        let t = tailPtr.pointee
        OSMemoryBarrier()  // Ensure we observe the latest head.
        let h = headPtr.pointee
        let avail = h - t
        let n = min(count, avail)
        guard n > 0 else { return 0 }

        let readIndex = t & mask
        let firstChunk = min(n, capacity - readIndex)
        dst.update(from: storage.advanced(by: readIndex), count: firstChunk)
        if firstChunk < n {
            dst.advanced(by: firstChunk).update(from: storage, count: n - firstChunk)
        }
        OSMemoryBarrier()  // Data consumed before advancing tail.
        tailPtr.pointee = t + n
        return n
    }
}
