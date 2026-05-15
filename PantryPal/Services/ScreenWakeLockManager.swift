//
//  ScreenWakeLockManager.swift
//  Reciplease
//
//  Manages the device idle timer so certain screens can
//  keep the display awake without scattering UIApplication
//  calls throughout the codebase.
//

import Foundation

#if os(iOS)
import UIKit

final class ScreenWakeLockManager {
    static let shared = ScreenWakeLockManager()
    
    private var lockCount = 0
    private let queue = DispatchQueue(label: "ScreenWakeLockManager.queue", qos: .userInitiated)
    
    private init() {}
    
    func acquire() {
        queue.async {
            self.lockCount += 1
            let shouldDisable = self.lockCount > 0
            DispatchQueue.main.async {
                UIApplication.shared.isIdleTimerDisabled = shouldDisable
            }
        }
    }
    
    func release() {
        queue.async {
            guard self.lockCount > 0 else { return }
            self.lockCount -= 1
            let shouldDisable = self.lockCount > 0
            DispatchQueue.main.async {
                UIApplication.shared.isIdleTimerDisabled = shouldDisable
            }
        }
    }
}

#else

final class ScreenWakeLockManager {
    static let shared = ScreenWakeLockManager()
    
    private init() {}
    
    func acquire() {}
    func release() {}
}

#endif

