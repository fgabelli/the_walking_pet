---
description: Distribute iOS Application
---
1. Clean and build the iOS IPA folder from Flutter:
flutter build ipa --release

2. DO NOT use fastlane beta, and DO NOT run automated deploy scripts. The user uploads the resulting .ipa file manually using the Transporter app.
