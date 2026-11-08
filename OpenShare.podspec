Pod::Spec.new do |s|
  s.name = 'OpenShare'
  s.version = '0.1.0'
  s.summary = 'Minimal native sharing, with optional official SDK adapters.'
  s.homepage = 'https://github.com/100apps/openshare'
  s.license = { :type => 'GPL v3', :file => 'LICENSE' }
  s.author = { 'Logan' => 'gf@gfzj.us' }
  s.source = { :git => 'https://github.com/100apps/openshare.git', :tag => s.version.to_s }
  s.ios.deployment_target = '15.0'
  s.requires_arc = true
  s.static_framework = true
  s.default_subspecs = 'Core'

  s.subspec 'Core' do |core|
    # Keep all existing headers/categories available for source compatibility.
    core.source_files = 'openshare/*.{h,m}'
    core.frameworks = 'UIKit', 'WebKit'
  end

  s.subspec 'WeChat' do |wechat|
    wechat.dependency 'OpenShare/Core'
    wechat.dependency 'WechatOpenSDK-XCFramework', '2.0.9'
    wechat.source_files = 'adapters/ios/*.{h,m}'
  end
end
