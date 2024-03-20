Pod::Spec.new do |s|
  s.name             = "AEPCampaign"
  s.version          = "5.0.0"
  s.summary          = "Campaign Standard library for Adobe Experience Platform SDK. Written and maintained by Adobe."
  s.description      = <<-DESC
                        The Campaign library provides APIs that allow use of the Campaign Standard product in the Adobe Experience Platform SDK.
                        DESC
  s.homepage         = "https://github.com/adobe/aepsdk-campaign-ios.git"
  s.license          = { :type => "Apache License, Version 2.0", :file => "LICENSE" }
  s.author           = "Adobe Experience Platform SDK Team"
  s.source           = { :git => "https://github.com/adobe/aepsdk-campaign-ios.git", :tag => s.version.to_s }

  s.ios.deployment_target = '12.0'

  s.swift_version = '5.1'

  s.pod_target_xcconfig = { 'BUILD_LIBRARY_FOR_DISTRIBUTION' => 'YES' }

  s.dependency 'AEPCore', '>= 5.0.0', '< 6.0.0'
  s.dependency 'AEPIdentity', '>= 5.0.0', '< 6.0.0'
  s.dependency 'AEPServices', '>= 5.0.0', '< 6.0.0'
  s.dependency 'AEPRulesEngine', '>= 5.0.0', '< 6.0.0'

  s.source_files     = 'AEPCampaign/Sources/**/*.swift'

end
