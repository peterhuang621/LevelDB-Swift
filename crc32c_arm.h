//
//  crc32c_arm.h
//  LevelDB-Swift
//
//  Created by 黄熠 on 2026/3/29.
//

#ifndef crc32c_arm_h
#define crc32c_arm_h

#include <arm_acle.h>
#include <stdio.h>

uint32_t crc32c_arm(uint32_t crc, const uint8_t *data, size_t len) {
    while (len >= 8) {
        crc = __crc32cd(crc, *(const uint64_t *)data);
        data += 8;
        len -= 8;
    }

    while (len > 0) {
        crc = __crc32cb(crc, *data);
        data++;
        len--;
    }

    return crc;
}

#endif /* crc32c_arm_h */
