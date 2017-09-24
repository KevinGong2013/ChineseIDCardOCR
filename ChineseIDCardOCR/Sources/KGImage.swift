//
//  KGImage.swift
//  ChineseIDCardOCR
//
//  Created by Kevin.Gong on 25/09/2017.
//  Copyright © 2017 Kevin.Gong. All rights reserved.
//

import Foundation

#if os(iOS)
    import UIKit
    public typealias KGImage = UIImage
#else
    import AppKit
    public typealias KGImage = NSImage
#endif
