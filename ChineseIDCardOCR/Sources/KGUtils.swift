//
//  KGUtils.swift
//  ChineseIDCardOCR
//
//  Created by GongXiang on 9/22/17.
//  Copyright © 2017 Kevin.Gong. All rights reserved.
//

import CoreImage
import CoreGraphics

public extension CGImage {
     
    func pixelBuffer(_ colorspace: CGColorSpace = CGColorSpaceCreateDeviceGray()) -> CVPixelBuffer? {
        var pb: CVPixelBuffer? = nil
        
        CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_OneComponent8, nil, &pb)
        guard let pixelBuffer = pb else { return nil }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue:0))
        
        let bitmapContext = CGContext(data: CVPixelBufferGetBaseAddress(pixelBuffer), width: width, height: height, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer), space: colorspace, bitmapInfo: 0)!
        
        bitmapContext.draw(self, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        return pixelBuffer
    }
}

public extension CGRect {
    public func scaled(to size: CGSize) -> CGRect {
        return CGRect(
            x: self.origin.x * size.width,
            y: self.origin.y * size.height,
            width: self.size.width * size.width,
            height: self.size.height * size.height
        )
    }
}

#if os(macOS)
import AppKit

public extension CIImage {

    public convenience init?(image: NSImage) {
        guard let tiffData = image.tiffRepresentation else { return nil }
        self.init(data: tiffData)
    }
}

#endif


