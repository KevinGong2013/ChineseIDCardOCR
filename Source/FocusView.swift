//
//  UIView.swift
//  ChineseIDCardOCR
//
//  Created by GongXiang on 8/16/16.
//  Copyright © 2016 Kevin.Gong. All rights reserved.
//

import UIKit

public class FocusView: UIView {

    public func startScaningAnimation() {

        //
        stopScaningAnimation()

        //
        let grid = CALayer()

        let gridImg = gridImage(frame.size.width, height: frame.size.height)
        grid.contents = gridImg.CGImage
        grid.frame = bounds
        grid.name = "grid"

        let laser = CALayer()

        let img = laserImage(frame.size.width, height: frame.size.height * 0.3)
        laser.backgroundColor = UIColor.clearColor().CGColor
        laser.contents = img.CGImage
        laser.frame = CGRect(x: 0, y: img.size.height * -1, width: img.size.width, height: img.size.height)

        let animation = CABasicAnimation(keyPath: "position.y")
        animation.byValue = frame.size.height + img.size.height
        animation.duration = 2
        animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
        animation.delegate = self
        animation.beginTime = 0
        animation.autoreverses = true
        animation.repeatCount = Float(Int.max)

        grid.mask = laser
        layer.addSublayer(grid)
        laser.addAnimation(animation, forKey: "scaningAnimation")
    }

    public func stopScaningAnimation() {
        layer.sublayers?.filter { $0.name == "grid" }.forEach { $0.removeFromSuperlayer() }
    }

    private func laserImage(width: CGFloat, height: CGFloat) -> UIImage {

        UIGraphicsBeginImageContext(CGSize(width: width, height: height))

        let context = UIGraphicsGetCurrentContext()

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let whiteclearColor = UIColor(red: 255, green: 255, blue: 255, alpha: 0).CGColor
        let whiteColor = UIColor.whiteColor().CGColor
        let locations: [CGFloat] = [0, 0.5, 1]
        let colors = [whiteclearColor, whiteColor, whiteclearColor]
        let gradient = CGGradientCreateWithColors(colorSpace, colors, locations)

        let startPoint = CGPoint(x: width/2, y: 0)
        let endPoint = CGPoint(x: width/2, y: height)

        CGContextDrawLinearGradient(context, gradient, startPoint, endPoint, .DrawsBeforeStartLocation)

        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return image
    }

    private func gridImage(width: CGFloat, height: CGFloat) -> UIImage {

        UIGraphicsBeginImageContext(CGSize(width: width, height: height))

        let context = UIGraphicsGetCurrentContext()
        CGContextSetStrokeColorWithColor(context, UIColor.whiteColor().CGColor)

        // 先画竖线
        0.stride(to: Int(width), by: 3).map { CGFloat($0) } .forEach {
            CGContextBeginPath(context)
            CGContextMoveToPoint(context, $0, 0)
            CGContextAddLineToPoint(context, $0, height)
            CGContextStrokePath(context)
        }

        // 再画横线
        0.stride(to: Int(height), by: 3).map { CGFloat($0) }.forEach {
            CGContextBeginPath(context)
            CGContextMoveToPoint(context, 0, $0)
            CGContextAddLineToPoint(context, width, $0)
            CGContextStrokePath(context)
        }

        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return image
    }
}
