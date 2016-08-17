//
//  Utils.swift
//  ChineseIDCardOCR
//
//  Created by GongXiang on 8/13/16.
//  Copyright © 2016 Kevin.Gong. All rights reserved.
//
//
//  NSTimer+Closure.swift
//  ChineseIDCardOCR
//
//  Created by GongXiang on 8/13/16.
//  Copyright © 2016 Kevin.Gong. All rights reserved.
//
// BaseOn: https://gist.github.com/natecook1000/b0285b518576b22c4dc8

import UIKit

// Usage:
//var count = 0
//NSTimer.schedule(repeatInterval: 1) { timer in
//    print(++count)
//    if count >= 10 {
//        timer.invalidate()
//    }
//}
//
//NSTimer.schedule(delay: 5) { timer in
//    print("5 seconds")
//}

extension NSTimer {
    /**
     Creates and schedules a one-time `NSTimer` instance.

     - Parameters:
     - delay: The delay before execution.
     - handler: A closure to execute after `delay`.

     - Returns: The newly-created `NSTimer` instance.
     */
    class func schedule(delay delay: NSTimeInterval, handler: NSTimer! -> Void) -> NSTimer {
        let fireDate = delay + CFAbsoluteTimeGetCurrent()
        let timer = CFRunLoopTimerCreateWithHandler(kCFAllocatorDefault, fireDate, 0, 0, 0, handler)
        CFRunLoopAddTimer(CFRunLoopGetCurrent(), timer, kCFRunLoopCommonModes)
        return timer
    }

    /**
     Creates and schedules a repeating `NSTimer` instance.

     - Parameters:
     - repeatInterval: The interval (in seconds) between each execution of
     `handler`. Note that individual calls may be delayed; subsequent calls
     to `handler` will be based on the time the timer was created.
     - handler: A closure to execute at each `repeatInterval`.

     - Returns: The newly-created `NSTimer` instance.
     */
    class func schedule(repeatInterval interval: NSTimeInterval, handler: NSTimer! -> Void) -> NSTimer {
        let fireDate = interval + CFAbsoluteTimeGetCurrent()
        let timer = CFRunLoopTimerCreateWithHandler(kCFAllocatorDefault, fireDate, interval, 0, 0, handler)
        CFRunLoopAddTimer(CFRunLoopGetCurrent(), timer, kCFRunLoopCommonModes)
        return timer
    }
}

extension UIImage {

    func crop(rect: CGRect) -> UIImage {

        guard let imageRef = CGImageCreateWithImageInRect(CGImage, rect) else {
            return self
        }

        return UIImage(CGImage: imageRef, scale: scale, orientation: imageOrientation)
    }
}

extension Array where Element: _ArrayType, Element.Generator.Element: Any {

    func transpose() -> [Element] {
        if self.isEmpty { return [Element]() }
        let count = self[0].count
        var out = [Element](count: count, repeatedValue: Element())
        for outer in self {
            for (index, inner) in outer.enumerate() {
                out[index].append(inner)
            }
        }
        return out
    }
}

extension String {

    //六位数字地址码，八位数字出生日期码，三位数字顺序码和一位数字校验码。
    /*
     1、将前面的身份证号码17位数分别乘以不同的系数。从第一位到第十七位的系数分别为：7－9－10－5－8－4－2－1－6－3－7－9－10－5－8－4－2。
     2、将这17位数字和系数相乘的结果相加。
     3、用加出来和除以11，看余数是多少？
     4、余数只可能有0－1－2－3－4－5－6－7－8－9－10这11个数字。其分别对应的最后一位身份证的号码为1－0－X －9－8－7－6－5－4－3－2。
     5、通过上面得知如果余数是3，就会在身份证的第18位数字上出现的是9。如果对应的数字是2，身份证的最后一位号码就是罗马数字x。
     例如：某男性的身份证号码为【53010219200508011x】， 我们看看这个身份证是不是合法的身份证。
     首先我们得出前17位的乘积和【(5*7)+(3*9)+(0*10)+(1*5)+(0*8)+(2*4)+(1*2)+(9*1)+(2*6)+(0*3)+(0*7)+(5*9)+(0*10)+(8*5)+(0*8)+(1*4)+(1*2)】是189，然后用189除以11得出的结果是189/11=17----2，也就是说其余数是2。最后通过对应规则就可以知道余数2对应的检验码是X。所以，可以判定这是一个正确的身份证号码。
     */
    var isValidateIdentityCard: Bool {

        func validateIdCardLength() -> Bool {
            let reg = "^(\\d{14}|\\d{17})(\\d|[xX])$"
            let predicate = NSPredicate(format: "SELF MATCHES %@", reg)
            return predicate.evaluateWithObject(self)
        }

        func checkCode() -> Bool {
            let factor = [7, 9, 10, 5, 8, 4, 2, 1, 6, 3, 7, 9, 10, 5, 8, 4, 2]
            let codes = [1, 0, 10, 9, 8, 7, 6, 5, 4, 3, 2]
            var chs = characters; chs.removeLast()
            let sum = chs.flatMap { Int(String($0)) }.enumerate().map { $0.element * factor[$0.index] }.reduce(0, combine: +)
            let code =  codes[sum % 11]

            var lastStr = substringFromIndex(endIndex.advancedBy(-1))
            if lastStr.lowercaseString == "x" { lastStr = "10" }

            return code == (Int(lastStr) ?? -1)
        }

        guard validateIdCardLength() else { return false }
        return checkCode()
    }
}
