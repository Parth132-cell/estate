class NegotiationAssistantService {
  /// Simple phase-next heuristic suggestion engine.
  Map<String, dynamic> suggest({
    required int listedPrice,
    required int offerPrice,
    int? counterPrice,
  }) {
    final gap = listedPrice - offerPrice;
    final offerRatio = listedPrice == 0 ? 0.0 : offerPrice / listedPrice;

    String strategy;
    String message;
    int suggestedCounter;

    if (offerRatio >= 0.95) {
      strategy = 'close_fast';
      suggestedCounter = listedPrice;
      message = 'Offer is strong. Recommend quick close at listed or minimal discount.';
    } else if (offerRatio >= 0.85) {
      strategy = 'mid_negotiation';
      suggestedCounter = ((listedPrice + offerPrice) / 2).round();
      message = 'Healthy room for negotiation. Suggest midpoint counter offer.';
    } else {
      strategy = 'protect_value';
      suggestedCounter = (listedPrice * 0.93).round();
      message = 'Offer is low. Defend value with a firmer counter and feature highlights.';
    }

    if (counterPrice != null && counterPrice > 0) {
      final counterGap = (counterPrice - offerPrice).abs();
      if (counterGap < (listedPrice * 0.03)) {
        message += ' Current counter is close enough; propose final call.';
      }
    }

    return {
      'strategy': strategy,
      'listedPrice': listedPrice,
      'offerPrice': offerPrice,
      'gap': gap,
      'suggestedCounter': suggestedCounter,
      'message': message,
    };
  }
}
