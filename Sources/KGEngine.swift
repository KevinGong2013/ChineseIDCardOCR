//
//  Engine.swift
//  ChineseIDCardOCR
//
//  Created by GongXiang on 9/22/17.
//  Copyright © 2017 Kevin.Gong. All rights reserved.
//

import Vision

public struct IDCard {
    public let number: String
}

/// MARK: -

/// User Engine to create a CNN network.
public class KGEngine {

    lazy var model = KGNetCNN() // for signle prediction
//    Creating a CIContext is an expensive operation, so a cached context should always be used for repeated resizing
    lazy var gpuContext = CIContext(options: [kCIContextUseSoftwareRenderer: false])
    
    public var debugBlock: ((CIImage) -> ())?
    public static var `default`: KGEngine { return KGEngine() }

    public init(_ debugBlock: ((CIImage) -> ())? = nil) {
        self.debugBlock = debugBlock
    }

    /// 对单个的包含数字的图片进行分类。
    /// 对一些特殊的图片比如像车牌之类的，可以自己进行预处理，使用本方法进行分类
    ///
    /// - parameter images: 将要识别的单个数字图片数组。 为了提高准确率请确认图片为: 28X28的灰度图
    ///
    /// - returns: 分类结果.
    ///            数字对应的概率. 比如 (1, 0.87)
    public func prediction(_ image: CIImage) -> (String, Double)? {
        guard let cgImage = gpuContext.createCGImage(image, from: image.extent) else {
            fatalError(KGError.invalidImage.localizedDescription)
        }
        guard let pixelBuffer = cgImage.pixelBuffer() else { fatalError("can't get image's pixel buffer") }
        if let f = debugBlock {
            f(CIImage(cvPixelBuffer: pixelBuffer))
        }
        guard let result = try? model.prediction(image: pixelBuffer) else { fatalError("unexpected runtime error") }

        return result.output.sorted { (lh, rh) -> Bool in
            return lh.value > rh.value
        }.first
    }
}

/// MARK: -

public extension KGEngine {

    /// 对完整原始的身份证照片进行识别
    ///
    /// 请务必确认图片方向， 保证身份证头像向上
    ///
    /// - parameter kgImage: 包含身份证图像的原始照片
    ///
    /// - parameter completionHandler: 识别成功以后会调用 包含身份证结构体和错误信息
    ///
    ///
    /// - returns: nil
    ///
    public func recognize(IDCard image: CIImage, completionHandler: @escaping (IDCard?, KGError?) -> ()) {
        ///
        /// 1. 检测身份证号码所在区域 并截取出来
        ///
        /// 2. 对图片进行一些里的预处理
        ///
        /// 3. 把每一个数字截出来，并且去噪 二值化
        ///
        /// 4. CNN 分类识别
        ///
        /// 5. TODO 根据身份证规则验证
        ///
        DispatchQueue.global(qos: .userInteractive).async {
            guard let numberArea = KGPreProcessing.detectChineseIDCardNumbersAra(image, debugBlock: self.debugBlock) else {
                completionHandler(nil, .faceInfoIncorrect)
                return
            }
            let preprocessedImage = KGPreProcessing.do(numberArea, debugBlock: self.debugBlock)
            let numbers = KGPreProcessing.segment(preprocessedImage, debugBlock: self.debugBlock)

            let result = numbers.map { $0.0 }.flatMap(self.prediction).map { $0.0 }
            guard result.count > 0 else {
                completionHandler(nil, KGError.classifyFailed)
                return
            }
            completionHandler(IDCard(number: result.joined(separator: "")), nil)
        }
    }
}

