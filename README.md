#ChineseIDCardOCR

ChineseIDCardOCR是一个用swift写的framework，用来识别中国二代身份证信息。修改自 [Swift-ORC](https://github.com/garnele007/SwiftOCR)。

##功能
- [x] 简洁易用的扫描界面
- [x] 简洁的Train接口
- [x] 身份证号码识别
- [ ] 身份证姓名、性别、地址识别
- [ ] 图片预处理逻辑优化
- [ ] Unit Test Converage

## Requirements

- iOS 9.0+
- Xcode 7.3+

## Installation

### CocoaPods

[CocoaPods](http://cocoapods.org) is a dependency manager for Cocoa projects. You can install it with the following command:

```bash
$ gem install cocoapods
```

> CocoaPods 0.39.0+ is required to build Alamofire 3.0.0+.

To integrate Alamofire into your Xcode project using CocoaPods, specify it in your `Podfile`:

```ruby
source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '9.0'
use_frameworks!

target '<Your Target Name>' do
    pod 'ChineseIDCardOCR'
end
```

Then, run the following command:

```bash
$ pod install
```

### Carthage
- [ ] TODO

## 使用示例

### 扫描身份证
```swift
import ChineseIDCardOCR

let vc = ScannerViewController()
vc.didRecognizedHandler = { idcard in
	debugPrint(idcard) 
}
presentViewController(vc, animated: true, completion: nil)	
```

### 识别图片

```swift
import ChineseIDCardOCR

let ocrInstance = IDCardOCR()

let idCardImage = UIImage ... ...

ocrInstance.recognize { recoginzedResult in 
	debugPrint(recoginzedResult)
}
	
```

## 工作原理
ChineseIDCardOCR 会对传入的UIImage进行人脸检测，根据监测到的frame和身份证比例，计算出身份证号码所在在的 Rect，然后截取图片。获取身份证号码图片以后, 利用[GPUImage](https://github.com/BradLarson/GPUImage)对图片进行一系列预处理，根据 [Connected-component labeling](https://en.wikipedia.org/wiki/Connected-component_labeling)理论，把身份证号码图片剪切成18个单独的小图片。然后利用[前馈神经网络(FFNN)](https://en.wikipedia.org/wiki/Feedforward_neural_network)对每个图片进行识别。
### FFNN 训练
在framework提供了*OCR-Training.swift*可以根据自己的特点提供单独的训练数据

## Dependencies

* [Swift-AI](https://github.com/collinhundley/Swift-AI)
* [GPUImage](https://github.com/BradLarson/GPUImage)
* [Union-Find](https://github.com/hollance/swift-algorithm-club/tree/master/Union-Find)
* [Swift-ORC](https://github.com/garnele007/SwiftOCR)

## License

    The code in this repository is licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

**NOTE**: This software depends on other packages that may be licensed under different open source licenses.
