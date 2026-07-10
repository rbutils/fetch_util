  function accessWarningReasons(metadata, content, markdown, body, page, combined, title, docsLike, readableDocsPage,
                                challengeType, interstitialType, extractedNotFoundBody, hasPublicContent,
                                substantialContent, emptyExtraction, boilerplateOnlyExtraction, signals) {
    var reasons = [];
    var consentDominatedBody = consentWallDominates(body);

    if (content && content.lodgingShell) reasons.push("client_rendered_property_shell");
    if (!docsLike && !substantialContent && consentDominatedBody) reasons.push("consent_interstitial");
    if (!docsLike && shortConsentPrivacyFragment(body)) reasons.push("consent_interstitial");
    var consentLikeWall = consentLikeInterstitial(interstitialType, combined, body, page) && !(interstitialType === "consent_wall" && hasPublicContent);
    if (!docsLike && !substantialContent && (consentLikeWall || (consentWallDominates(page) && !hasPublicContent))) {
      reasons.push("consent_interstitial");
    }
    if (challengeType === "anubis") reasons.push("anubis_challenge_page");
    if (challengeType === "datadome") reasons.push("datadome_challenge_page");
    if (challengeType === "cloudflare") reasons.push("cloudflare_challenge_page");
    if (interstitialType === "consent_wall" && !substantialContent && !hasPublicContent) reasons.push("consent_interstitial");
    if (interstitialType === "meta_login") reasons.push("meta_login_wall");
    if (interstitialType === "human_verification") reasons.push("human_verification_interstitial");
    if (interstitialType === "region_selector") reasons.push("regional_selector_interstitial");
    if (interstitialType === "browser_support") reasons.push("browser_support_interstitial");
    if (interstitialType === "access_error" && !substantialContent && !hasPublicContent) reasons.push("access_error_interstitial");
    if (interstitialType === "site_unavailable") reasons.push("site_unavailable_interstitial");
    if ((interstitialType === "not_found" || extractedNotFoundBody) && !(docsLike && readableDocsPage)) reasons.push("not_found_interstitial");
    if (interstitialType === "subscription" && (!substantialContent || subscriptionWallDominates(body) || (subscriptionWallDominates(page) && !hasPublicContent))) {
      reasons.push("subscription_interstitial");
    }
    if (interstitialType === "auth_wall") reasons.push("auth_or_login_interstitial");
    if (interstitialType === "meta_login" && /cookie/i.test(combined)) reasons.push("consent_interstitial");
    if (!(docsLike && readableDocsPage) && (challengeType || (!substantialContent && !hasPublicContent && /(verify you are human|unusual traffic|are you a robot|access denied|security verification|checking your browser)/.test(combined)))) {
      reasons.push("bot_or_access_interstitial");
    }
    if (!(docsLike && readableDocsPage) && (interstitialType === "human_verification" || (interstitialType === "access_error" && !substantialContent && !hasPublicContent))) reasons.push("bot_or_access_interstitial");
    if (emptyExtraction && (page.length > 80 || (metadata.title || "").length > 3 || (signals && signals.htmlLength > 200))) reasons.push("empty_extraction");
    if (boilerplateOnlyExtraction && !challengeType && !interstitialType) reasons.push("empty_extraction");
    if (!challengeType && !interstitialType && normalizeText(markdown || "").length < 10 && (metadata.title || "").length > 3) {
      if (reasons.indexOf("empty_extraction") === -1 && reasons.indexOf("short_extraction") === -1) reasons.push("short_extraction");
    }
    return reasons;
  }
