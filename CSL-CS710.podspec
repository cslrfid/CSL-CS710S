Pod::Spec.new do |spec|

  spec.name         = "CSL-CS710"
  spec.version      = "0.4.0"
  spec.summary      = "CocoaPod Framework for CSL CS710 SDK"
  spec.description  = "CSL SDK Library Framework, a library for CS710 RFID handheld devices"

  spec.homepage     = "https://github.com/cslrfid/CSL-CS710"
  spec.license      = "MIT"
  spec.author       = { "Carlson Lam" => "carlson.lam@convergence.com.hk" }

  spec.platform     = :ios, "13.0"
  spec.source       = { :git => "https://github.com/cslrfid/CSL-CS710.git", :tag => spec.version.to_s }
  spec.source_files  = "Classes", "CSL-CS710/**/*.{h,m}"
  spec.dependency 'MQTTClient'
end
