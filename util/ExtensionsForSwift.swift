//
//  ExtensionsForSwift.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2026/4/28.
//

import Foundation

extension Array {
    public mutating func resize(newSize: Int, repeating: Element) {
        if count <= newSize {
            append(contentsOf: repeatElement(repeating, count: newSize - count))
        } else {
            removeSubrange(newSize ..< count)
        }
    }
}

extension Array where Element: ExpressibleByNilLiteral {
    public mutating func resize(newSize: Int) {
        resize(newSize: newSize, repeating: nil)
    }
}
