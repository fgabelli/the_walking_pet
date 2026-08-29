import Flutter
import UIKit
import GoogleMobileAds
import google_mobile_ads

class SocialFeedNativeAdFactory: NSObject, FLTNativeAdFactory {
    func createNativeAd(_ nativeAd: NativeAd, customOptions: [AnyHashable : Any]?) -> NativeAdView? {
        let nativeAdView = NativeAdView()
        nativeAdView.backgroundColor = .white
        
        // App icon
        let iconView = UIImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.layer.cornerRadius = 18
        iconView.clipsToBounds = true
        iconView.contentMode = .scaleAspectFill
        iconView.backgroundColor = UIColor.lightGray.withAlphaComponent(0.2)
        nativeAdView.addSubview(iconView)
        iconView.image = nativeAd.icon?.image
        nativeAdView.iconView = iconView
        
        // Headline
        let headlineLabel = UILabel()
        headlineLabel.textColor = .black
        headlineLabel.font = UIFont.boldSystemFont(ofSize: 14)
        headlineLabel.translatesAutoresizingMaskIntoConstraints = false
        nativeAdView.addSubview(headlineLabel)
        headlineLabel.text = nativeAd.headline
        nativeAdView.headlineView = headlineLabel
        
        // Sponsored text
        let sponsoredLabel = UILabel()
        sponsoredLabel.text = "Sponsorizzato"
        sponsoredLabel.textColor = .gray
        sponsoredLabel.font = UIFont.systemFont(ofSize: 11, weight: .medium)
        sponsoredLabel.translatesAutoresizingMaskIntoConstraints = false
        nativeAdView.addSubview(sponsoredLabel)
        
        // Media View
        let mediaView = MediaView()
        mediaView.translatesAutoresizingMaskIntoConstraints = false
        mediaView.backgroundColor = .black
        nativeAdView.addSubview(mediaView)
        nativeAdView.mediaView = mediaView
        
        // Body
        let bodyLabel = UILabel()
        bodyLabel.textColor = .darkGray
        bodyLabel.font = UIFont.systemFont(ofSize: 13)
        bodyLabel.numberOfLines = 3
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        nativeAdView.addSubview(bodyLabel)
        bodyLabel.text = nativeAd.body
        nativeAdView.bodyView = bodyLabel
        
        // CTA Button
        let ctaButton = UIButton(type: .custom)
        ctaButton.backgroundColor = UIColor(red: 255/255, green: 68/255, blue: 68/255, alpha: 1.0)
        ctaButton.setTitleColor(.white, for: .normal)
        ctaButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 15)
        ctaButton.layer.cornerRadius = 12
        ctaButton.translatesAutoresizingMaskIntoConstraints = false
        nativeAdView.addSubview(ctaButton)
        ctaButton.setTitle(nativeAd.callToAction, for: .normal)
        ctaButton.isUserInteractionEnabled = false // Passes tap to nativeAdView
        nativeAdView.callToActionView = ctaButton
        
        // Constraints
        NSLayoutConstraint.activate([
            // Icon
            iconView.topAnchor.constraint(equalTo: nativeAdView.topAnchor, constant: 12),
            iconView.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor, constant: 12),
            iconView.widthAnchor.constraint(equalToConstant: 36),
            iconView.heightAnchor.constraint(equalToConstant: 36),
            
            // Headline
            headlineLabel.topAnchor.constraint(equalTo: nativeAdView.topAnchor, constant: 12),
            headlineLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            headlineLabel.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor, constant: -12),
            
            // Sponsored label
            sponsoredLabel.topAnchor.constraint(equalTo: headlineLabel.bottomAnchor, constant: 2),
            sponsoredLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            
            // Media View
            mediaView.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 12),
            mediaView.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor),
            mediaView.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor),
            mediaView.heightAnchor.constraint(equalToConstant: 200),
            
            // Body
            bodyLabel.topAnchor.constraint(equalTo: mediaView.bottomAnchor, constant: 12),
            bodyLabel.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor, constant: 12),
            bodyLabel.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor, constant: -12),
            
            // CTA Button
            ctaButton.topAnchor.constraint(equalTo: bodyLabel.bottomAnchor, constant: 12),
            ctaButton.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor, constant: 12),
            ctaButton.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor, constant: -12),
            ctaButton.bottomAnchor.constraint(equalTo: nativeAdView.bottomAnchor, constant: -16),
            ctaButton.heightAnchor.constraint(equalToConstant: 48)
        ])
        
        nativeAdView.nativeAd = nativeAd
        return nativeAdView
    }
}
