#
#  Be sure to run `pod spec lint MessageListener.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see http://docs.cocoapods.org/specification.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#

Pod::Spec.new do |s|

  s.name         = "MessageListener"
  s.version      = "1.0.0"
  s.summary      = "A tool for monitoring message calls"
  s.homepage     = "https://github.com/TangentW/MessageListener"

  s.license      = "MIT"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author       = { "TangentW" => "805063400@qq.com" }

  s.source       = { :git => "https://github.com/TangentW/MessageListener.git", :tag => "#{s.version}" }
  s.source_files  = "MessageListener/MessageListener/Core/*.{h,m}"
end
