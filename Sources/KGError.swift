//
//  KGError.swift
//  ChineseIDCardOCR
//
//  Created by GongXiang on 9/22/17.
//  Copyright © 2017 Kevin.Gong. All rights reserved.
//

import Foundation

/// `KGError` is the error type returned by ChineseIDCardOCR.

public enum KGError: Error {

    case sizeDoestMatch
    case invalidImage

    case noFaceDetected
    case faceInfoIncorrect

    case classifyFailed

    case unexpected(Error)

}

extension KGError {

    public var localizedDescription: String {
        switch self {
        case .noFaceDetected:
            return "身份证图片上未发现照片"
        case .faceInfoIncorrect:
            return "身份证照片信息不完整"
        case .sizeDoestMatch:
            return "请确认图片大小为28x28"
        case .classifyFailed:
            return "身份证号码识别失败"
        case .invalidImage:
            return "can't create CIImage from UIImage"
        case .unexpected(let e):
            return e.localizedDescription
        }
    }
}
