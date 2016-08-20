//
//  ViewController.swift
//  Example
//
//  Created by GongXiang on 8/17/16.
//  Copyright © 2016 Kevin.Gong. All rights reserved.
//

import UIKit
import ChineseIDCardOCR

class ViewController: UIViewController {

    @IBOutlet private weak var imageView: UIImageView!
    @IBOutlet private weak var numberLabel: UILabel!

    @IBAction func tap(sender: UIButton) {

        let vc = ScannerViewController()

        var errorSum = 0

        func fill(card: IDCard) {
            imageView.image = card.image
            numberLabel.text = card.number
            vc.dismissViewControllerAnimated(true, completion: nil)
        }

        vc.didRecognizedHandler = {

            // 连续3次都没有识别正确，就不再继续等待
            guard errorSum < 3 else {
                fill($0)
                return
            }

            guard $0.number.isValidateIdentityCard else {
                debugPrint("did recognize an error id card number \($0.number)")
                errorSum += 1
                return
            }

            fill($0)
        }

        presentViewController(vc, animated: true, completion: nil)
    }

    @IBAction func recoginzeLocalImage(sender: UIButton) {

        let ocr = IDCardOCR()!

        let names = ["test", "test1", "test4", "test3"]
        let randomIdx = Int(arc4random_uniform(4))
        let image = UIImage(named: names[randomIdx])!
        self.imageView.image = image //cropNameImage(image)
        self.numberLabel.text = "正在识别 ... ..."

        ocr.recognize(image) {
            let number = $0
            dispatch_async(dispatch_get_main_queue()) {
                self.numberLabel.text = number
            }
        }
    }
}
