import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:get/get.dart';

class AdService extends GetxService {
  InterstitialAd? _interstitialAd;
  int _numInterstitialLoadAttempts = 0;
  int _maxFailedLoadAttempts = 3;

  /// TEST IDS (Replace with Real IDs in Production)
  final String _androidBannerId = 'ca-app-pub-3940256099942544/6300978111';
  final String _iosBannerId = 'ca-app-pub-3940256099942544/2934735716';
  final String _androidInterstitialId = 'ca-app-pub-3940256099942544/1033173712';
  final String _iosInterstitialId = 'ca-app-pub-3940256099942544/4411468910';

  /// --- AD ARCHITECTURE ---
  ///
  /// **Mobile (Android/iOS)**:
  /// - Uses `google_mobile_ads` plugin (AdMob).
  /// - Managed by this service (`AdService`).
  /// - Preloads Interstitial ads for performance.
  ///
  /// **Web**:
  /// - Uses **Google AdSense** (JS Snippet + HtmlElementView).
  /// - `AdService` is effectively disabled for Web (`if (kIsWeb) return`).
  /// - Web logic is found in `lib/core/web_ad_registry.dart` and `web/index.html`.
  Future<void> init() async {
    // Web uses AdSense, not AdMob SDK
    if (kIsWeb) return; 
    
    await MobileAds.instance.initialize();
    _loadInterstitial();
  }

  String get bannerAdUnitId {
    if (kIsWeb) return ''; // No ads on web
    if (defaultTargetPlatform == TargetPlatform.android) return _androidBannerId;
    if (defaultTargetPlatform == TargetPlatform.iOS) return _iosBannerId;
    return '';
  }

  String get interstitialAdUnitId {
    if (kIsWeb) return '';
    if (defaultTargetPlatform == TargetPlatform.android) return _androidInterstitialId;
    if (defaultTargetPlatform == TargetPlatform.iOS) return _iosInterstitialId;
    return '';
  }

  /// Create a Banner Ad widget
  /// Returns null on web or unsupported platforms
  BannerAd? createBannerAd() {
    // Web has its own placeholder in the UI widget, so we return null here
    if (kIsWeb) return null;

    final adUnitId = bannerAdUnitId;
    if (adUnitId.isEmpty) return null;

    return BannerAd(
      adUnitId: adUnitId,
      size: AdSize.mediumRectangle, // Slightly larger for feed
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => debugPrint('Banner Ad Loaded'),
        onAdFailedToLoad: (ad, error) {
          debugPrint('Banner Ad Failed to Load: $error');
          ad.dispose();
        },
      ),
    )..load();
  }

  /// Preload Interstitial Ad
  void _loadInterstitial() {
    if (kIsWeb) return;
    
    final adUnitId = interstitialAdUnitId;
    if (adUnitId.isEmpty) return;

    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          debugPrint('Interstitial Ad Loaded');
          _interstitialAd = ad;
          _numInterstitialLoadAttempts = 0;
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('InterstitialAd failed to load: $error');
          _numInterstitialLoadAttempts += 1;
          _interstitialAd = null;
          if (_numInterstitialLoadAttempts < _maxFailedLoadAttempts) {
            _loadInterstitial();
          }
        },
      ),
    );
  }

  /// Show Interstitial Ad (e.g., after posting)
  void showInterstitial() {
    if (kIsWeb) return;

    if (_interstitialAd == null) {
      debugPrint('Warning: Attempted to show interstitial before loading.');
      _loadInterstitial(); // Retry loading for next time
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (InterstitialAd ad) {
        debugPrint('Interstitial Ad Dismissed');
        ad.dispose();
        _loadInterstitial(); // Preload the next one immediately
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
        debugPrint('Interstitial Ad Failed to Show: $error');
        ad.dispose();
        _loadInterstitial();
      },
    );

    _interstitialAd!.show();
    _interstitialAd = null;
  }
}
