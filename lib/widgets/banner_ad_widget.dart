import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_service.dart';
import '../services/pro_service.dart';

/// Single banner shown above the bottom navigation on every tab.
/// Renders nothing for Pro users, before consent is resolved, or if the ad
/// fails to load — so it never leaves an empty gap or blocks the UI.
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    AdService.adsReady.addListener(_maybeLoad);
    ProService.isPro.addListener(_onProChanged);
    _maybeLoad();
  }

  void _onProChanged() {
    if (ProService.isPro.value) {
      _disposeAd();
      if (mounted) setState(() {});
    } else {
      _maybeLoad();
    }
  }

  void _maybeLoad() {
    if (_ad != null || !AdService.adsReady.value || ProService.isPro.value) return;

    final ad = BannerAd(
      adUnitId: AdService.bannerUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (mounted) {
            setState(() {
              _ad = null;
              _loaded = false;
            });
          }
        },
      ),
    );
    _ad = ad;
    ad.load();
  }

  void _disposeAd() {
    _ad?.dispose();
    _ad = null;
    _loaded = false;
  }

  @override
  void dispose() {
    AdService.adsReady.removeListener(_maybeLoad);
    ProService.isPro.removeListener(_onProChanged);
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null || !_loaded || ProService.isPro.value) {
      return const SizedBox.shrink();
    }
    // Padding keeps the ad clear of the content above and the nav bar below,
    // reducing accidental taps (a Play/AdMob policy concern).
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      ),
    );
  }
}
