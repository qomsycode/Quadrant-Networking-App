import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:get/get.dart';
import '../services/ad_service.dart';

class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    final adService = Get.find<AdService>();
    final ad = adService.createBannerAd();
    
    if (ad == null) {
        // Ads invalid or not supported (e.g. web)
        return;
    }

    _bannerAd = ad
      ..load().then((_) {
        if (mounted) {
          setState(() {
            _isLoaded = true;
          });
        }
      });
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // WEB SUPPORT: Show AdSense Ad
    if (kIsWeb) {
      return Container(
        alignment: Alignment.center,
        width: double.infinity,
        height: 100, // Medium rectangle height rough approximation
        constraints: const BoxConstraints(minHeight: 100),
        margin: const EdgeInsets.symmetric(vertical: 12),
        color: Colors.white, // Background for the ad container
        child: const SizedBox(
           height: 100,
           width: 320,
           child: HtmlElementView(viewType: 'ad-sense-view'),
        ),
      );
    }

    if (!_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink(); // Hide until loaded
    }

    return Container(
      alignment: Alignment.center,
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
