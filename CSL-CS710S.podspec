Pod::Spec.new do |spec|

  spec.name         = "CSL-CS710S"
  spec.version      = "1.7.0"
  spec.summary      = "CocoaPod Framework for CSL CS710 SDK"
  spec.description  = "CSL SDK Library Framework, a library for CS710 RFID handheld devices"

  spec.homepage     = "https://github.com/cslrfid/CSL-CS710S"
  spec.license      = "MIT"
  spec.author       = { "Carlson Lam" => "carlson.lam@convergence.com.hk" }

  spec.platform     = :ios, "13.0"
  spec.source       = { :git => "https://github.com/cslrfid/CSL-CS710S.git", :tag => spec.version.to_s }
  spec.source_files  = "Classes", "CSL-CS710S/**/*.{h,m}"
  spec.dependency 'MQTTClient'
end
