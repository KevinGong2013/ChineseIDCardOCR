#
#  Be sure to run `pod spec lint ChineseIDCardOCR.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see http://docs.cocoapods.org/specification.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#

Pod::Spec.new do |s|

  s.name         = "ChineseIDCardOCR"
  s.version      = "0.0.1"
  s.summary      = "中国二代身份证信息识别"
  s.description  = <<-DESC
                利用FFNN（前馈神经网络）OCR身份证信息
                   DESC

  s.homepage     = "http://www.prophetapp.cn"
  # s.screenshots  = "www.example.com/screenshots_1.gif", "www.example.com/screenshots_2.gif"

  s.license      = "Apache License, Version 2.0"
  s.author             = "Kevin.Gong"

  s.platform     = :ios
  s.ios.deployment_target = "9.0"

  s.source       = { :git => "https://github.com/KevinGong2013/ChineseIDCardOCR.git", :tag => "#{s.version}" }

  s.source_files  = "Source"
  s.exclude_files = "Source/OCR-Training.swift"

  s.resources = "Resources/icon_**.png", "Resources/OCR-Network", "Resources/*.xib"

  s.dependency "GPUImage", "~> 0.1"

end
