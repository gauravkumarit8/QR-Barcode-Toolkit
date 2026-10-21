import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_pacing.dart';
import '../services/ad_service.dart';
import '../services/pro_service.dart';

/// One native ad, shown as a row inside the History list. It uses Google's
/// built-in "small" template, which carries its own "Ad" label. It takes no
/// space until an ad has actually loaded, so a failed load leaves no gap.
class NativeAdTile extends StatefulWidget {
  const NativeAdTile({super.key});

  @override
  State<NativeAdTile> createState() => _NativeAdTileState();
}

class _NativeAdTileState extends State<NativeAdTile> {
  NativeAd? _ad;
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
      _ad?.dispose();
      _ad = null;
      _loaded = false;
      if (mounted) setState(() {});
    }
  }

  void _maybeLoad() {
    if (_ad != null ||
        !AdService.adsReady.value ||
        ProService.isPro.value ||
        !AdPacing.passiveAdsAllowed) {
      return;
    }
    final ad = NativeAd(
      adUnitId: AdService.nativeUnitId,
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(templateType: TemplateType.small),
      listener: NativeAdListener(
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 320, minHeight: 90, maxHeight: 200),
        child: AdWidget(ad: ad),
      ),
    );
  }
}
