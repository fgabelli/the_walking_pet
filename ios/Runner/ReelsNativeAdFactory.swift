import Flutter
import UIKit
import GoogleMobileAds
import google_mobile_ads

class ReelsNativeAdFactory: NSObject, FLTNativeAdFactory {
    func createNativeAd(_ nativeAd: NativeAd, customOptions: [AnyHashable : Any]?) -> NativeAdView? {
        let nativeAdView = NativeAdView()
        nativeAdView.backgroundColor = .black
        nativeAdView.frame = UIScreen.main.bounds
        
        // Media View
        let mediaView = MediaView()
        mediaView.translatesAutoresizingMaskIntoConstraints = false
        nativeAdView.addSubview(mediaView)
        nativeAdView.mediaView = mediaView
        
        // Overlay view
        let overlayView = UIView()
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        nativeAdView.addSubview(overlayView)
        
        // Headline
        let headlineLabel = UILabel()
        headlineLabel.textColor = .white
        headlineLabel.font = UIFont.boldSystemFont(ofSize: 16)
        headlineLabel.translatesAutoresizingMaskIntoConstraints = false
        overlayView.addSubview(headlineLabel)
        headlineLabel.text = nativeAd.headline
        nativeAdView.headlineView = headlineLabel
        
        // Body
        let bodyLabel = UILabel()
        bodyLabel.textColor = .lightGray
        bodyLabel.font = UIFont.systemFont(ofSize: 13)
        bodyLabel.numberOfLines = 2
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        overlayView.addSubview(bodyLabel)
        bodyLabel.text = nativeAd.body
        nativeAdView.bodyView = bodyLabel
        
        // CTA Button
        let ctaButton = UIButton(type: .custom)
        ctaButton.backgroundColor = UIColor(red: 255/255, green: 68/255, blue: 68/255, alpha: 1.0)
        ctaButton.setTitleColor(.white, for: .normal)
        ctaButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 15)
        ctaButton.layer.cornerRadius = 12
        ctaButton.translatesAutoresizingMaskIntoConstraints = false
        overlayView.addSubview(ctaButton)
        ctaButton.setTitle(nativeAd.callToAction, for: .normal)
        ctaButton.isUserInteractionEnabled = false // Passes tap to nativeAdView
        nativeAdView.callToActionView = ctaButton
        
        // Sponsored Label
        let sponsoredLabel = UILabel()
        sponsoredLabel.text = "Sponsorizzato"
        sponsoredLabel.textColor = .white
        sponsoredLabel.font = UIFont.boldSystemFont(ofSize: 10)
        sponsoredLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        sponsoredLabel.textAlignment = .center
        sponsoredLabel.layer.cornerRadius = 4
        sponsoredLabel.clipsToBounds = true
        sponsoredLabel.translatesAutoresizingMaskIntoConstraints = false
        nativeAdView.addSubview(sponsoredLabel)
        
        // Constraints
        NSLayoutConstraint.activate([
            // Media View spans full nativeAdView
            mediaView.topAnchor.constraint(equalTo: nativeAdView.topAnchor),
            mediaView.bottomAnchor.constraint(equalTo: nativeAdView.bottomAnchor),
            mediaView.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor),
            mediaView.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor),
            
            // Sponsored badge top-left
            sponsoredLabel.topAnchor.constraint(equalTo: nativeAdView.safeAreaLayoutGuide.topAnchor, constant: 16),
            sponsoredLabel.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor, constant: 16),
            sponsoredLabel.widthAnchor.constraint(equalToConstant: 100),
            sponsoredLabel.heightAnchor.constraint(equalToConstant: 24),
            
            // Overlay bottom container
            overlayView.bottomAnchor.constraint(equalTo: nativeAdView.bottomAnchor),
            overlayView.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor),
            
            // Headline
            headlineLabel.topAnchor.constraint(equalTo: overlayView.topAnchor, constant: 16),
            headlineLabel.leadingAnchor.constraint(equalTo: overlayView.leadingAnchor, constant: 16),
            headlineLabel.trailingAnchor.constraint(equalTo: overlayView.trailingAnchor, constant: -16),
            
            // Body
            bodyLabel.topAnchor.constraint(equalTo: headlineLabel.bottomAnchor, constant: 8),
            bodyLabel.leadingAnchor.constraint(equalTo: overlayView.leadingAnchor, constant: 16),
            bodyLabel.trailingAnchor.constraint(equalTo: overlayView.trailingAnchor, constant: -16),
            
            // CTA Button
            ctaButton.topAnchor.constraint(equalTo: bodyLabel.bottomAnchor, constant: 12),
            ctaButton.leadingAnchor.constraint(equalTo: overlayView.leadingAnchor, constant: 16),
            ctaButton.trailingAnchor.constraint(equalTo: overlayView.trailingAnchor, constant: -16),
            ctaButton.bottomAnchor.constraint(equalTo: overlayView.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            ctaButton.heightAnchor.constraint(equalToConstant: 48)
        ])
        
        nativeAdView.nativeAd = nativeAd
        return nativeAdView
    }
}
