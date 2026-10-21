import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_pacing.dart';
import '../services/ad_service.dart';
import '../services/pro_service.dart';

/// Single banner shown above the bottom navigation on every tab.
/// Renders nothing for Pro users, before consent is resolved, or if the ad
/// fails to load — so it never leaves an empty gap or blocks the UI.
///
/// Uses an anchored adaptive banner (sized to the screen width) and retries a
/// failed load with exponential backoff, so one "no fill" doesn't mean no ads
/// for the rest of the session.
class BannerAdWidget extends StatefulWidget {
  /// When false the banner is not drawn (used for the Scan tab, where an ad
  /// would sit next to the camera). The loaded ad is kept, so switching tabs
  /// does not trigger a new ad request every time.
  final bool visible;

  const BannerAdWidget({super.key, this.visible = true});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  static const _maxRetries = 6;

  BannerAd? _ad;
  bool _loaded = false;
  bool _loading = false; // true while the adaptive size is being resolved
  int _failures = 0;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    AdService.adsReady.addListener(_maybeLoad);
    ProService.isPro.addListener(_onProChanged);
    _maybeLoad();
  }

  void _onProChanged() {
    if (ProService.isPro.value) {
      _retryTimer?.cancel();
      _disposeAd();
      if (mounted) setState(() {});
    } else {
      _maybeLoad();
    }
  }

  /// Screen width in logical pixels. Read from the platform dispatcher so it
  /// works from initState (no BuildContext / MediaQuery needed).
  int get _screenWidthDp {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    return (view.physicalSize.width / view.devicePixelRatio).truncate();
  }

  Future<void> _maybeLoad() async {
    if (_ad != null ||
        _loading ||
        !AdService.adsReady.value ||
        ProService.isPro.value ||
        !AdPacing.passiveAdsAllowed) {
      return;
    }

    _loading = true;
    AdSize? size;
    try {
      size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(_screenWidthDp);
    } catch (_) {
      size = null; // fall back to the standard banner below
    }
    _loading = false;
    if (!mounted || _ad != null || ProService.isPro.value) return;

    final ad = BannerAd(
      adUnitId: AdService.bannerUnitId,
      size: size ?? AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          _failures = 0;
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _failures++;
          if (mounted) {
            setState(() {
              _ad = null;
              _loaded = false;
            });
          }
          _scheduleRetry();
        },
      ),
    );
    _ad = ad;
    ad.load();
  }

  /// 30s, 60s, 120s, ... capped at 5 minutes, and gives up after [_maxRetries].
  void _scheduleRetry() {
    if (!mounted || ProService.isPro.value || _failures > _maxRetries) return;
    final seconds = math.min(30 * (1 << (_failures - 1)), 300);
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: seconds), _maybeLoad);
  }

  void _disposeAd() {
    _ad?.dispose();
    _ad = null;
    _loaded = false;
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    AdService.adsReady.removeListener(_maybeLoad);
    ProService.isPro.removeListener(_onProChanged);
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!widget.visible || ad == null || !_loaded || ProService.isPro.value) {
      return const SizedBox.shrink();
    }
    // Padding keeps the ad clear of the content above and the nav bar below,
    // reducing accidental taps (a Play/AdMob policy concern). It also lives
    // in its own row here — structurally separate from any screen's buttons
    // or camera view — specifically because competitor app reviews describe
    // ads overlapping the scan frame or styled to look like real buttons.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Advertisement',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 0.5,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: ad.size.width.toDouble(),
            height: ad.size.height.toDouble(),
            child: AdWidget(ad: ad),
          ),
        ],
      ),
    );
  }
}
