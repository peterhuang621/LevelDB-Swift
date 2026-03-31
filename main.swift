//
//  main.swift
//  LevelDB-Swift
//
//  Created by 黄熠 on 2025/12/16.
//

import Foundation

print("Hello, World!")

var arr = [1, 3, 4, 5]
print("crc32c: \(crc32c_arm(3, &arr, arr.count))")
