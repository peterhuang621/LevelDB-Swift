//
//  mutexlock.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2026/1/30.
//

import Foundation
import os

public final class Mutex {
    fileprivate var mu_ = os_unfair_lock()

    public func Lock() {
        os_unfair_lock_lock(&mu_)
    }

    public func Unlock() {
        os_unfair_lock_unlock(&mu_)
    }
}

public final class CondVar {
    private let cv_ = NSCondition()

    public func Wait() {
        cv_.lock()
        cv_.wait()
        cv_.unlock()
    }

    public func Signal() { cv_.signal() }
    public func SignalAll() { cv_.broadcast() }

    public func Lock() {
        cv_.lock()
    }

    public func Unlock() {
        cv_.unlock()
    }
}

class MutexLock {
    private let mu_:Mutex

    init(mu: Mutex) {
        mu_ = mu
        mu_.Lock()
    }

    deinit{
        mu_.Unlock()
    }
}
