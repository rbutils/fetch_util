function finalizedPaywallState(content, warnings) {
  var paywall = paywallSignals();
  if (!paywall || visiblePublicArticleBodyRetained(content, paywall)) return null;
  return warnings.indexOf("subscription_interstitial") !== -1 ? "full_block" : "detected";
}
