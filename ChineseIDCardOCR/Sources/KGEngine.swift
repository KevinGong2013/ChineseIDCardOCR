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

    /// 对完整的身份证照片进行识别
    ///
    /// - parameter image: 身份证照片
    ///
    /// - returns: 身份证号码
    ///
    public func classify(IDCard kgImage: KGImage, completionHandler: @escaping (IDCard?, KGError?) -> ()) {

        guard let inputImage = CIImage(image: kgImage) else {
            completionHandler(nil, .invalidImage)
            return
        }
        debugBlock?(inputImage)
        
        #if os(iOS)
            let orientation = CGImagePropertyOrientation(kgImage.imageOrientation)
            inputImage.oriented(forExifOrientation: Int32(orientation.rawValue))
        #endif

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
            guard let numberArea = KGPreProcessing.detectChineseIDCardNumbersAra(inputImage) else {
                completionHandler(nil, .faceInfoIncorrect)
                return
            }
            let preprocessedImage = KGPreProcessing.do(numberArea, debugBlock: self.debugBlock)
            let numbers = KGPreProcessing.segment(preprocessedImage, debugBlock: self.debugBlock)

            if let result = self.classify(IDCardNumbers: numbers.map { x in x.0 }) {
                completionHandler(IDCard(number: result.joined(separator: "")), nil)
            } else {
               completionHandler(nil, .classifyFailed)
            }
        }
    }

    // TODO 根据不同类型（身份证，银行卡...）进行 校验 计算
    func classify(IDCardNumbers images: [CIImage]) -> [String]? {

        return images.flatMap(prediction).map { x in x.0 }
    }
}

