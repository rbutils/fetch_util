function siteUnavailablePage(title, page) {
  var normalizedTitle = normalizeText(title || "").toLowerCase();
  var normalizedPage = normalizeText(page || "").toLowerCase();
  var unavailablePattern = /خطایی رخ داده|وب سایت مورد نظر در دسترس نیست|page unavailable|site unavailable|website unavailable|service temporarily unavailable|temporarily unavailable|service unavailable/;

  return unavailablePattern.test(normalizedTitle) ||
    (normalizedPage.length < 1200 && unavailablePattern.test(normalizedPage.slice(0, 500)));
}

function notFoundInterstitialPattern() {
  return /\b404\b|\boops!\b|\bnot found\b|page not found|not the web page you are looking for|sorry, (?:we )?(?:can.?t|could not) find (?:that |the )?page|we.?re sorry, but that page cannot be found|(?:that |the )?page cannot be found|the page you (?:requested|were looking for|are looking for) (?:can.?t be found|does(?:n'?t| not) exist)|this page is no longer available|content no longer available|(?:dataset|record|project|submission) (?:you are trying to view )?is not available|this doi cannot be found in the doi system|doi cannot be found|ご利用のページが見つかりません|ページまたはファイルが存在しません|移動または削除されている|urlに誤りがある|urlには.*存在しません/i;
}

function notFoundInterstitialEvidence(title, text, options) {
  options = options || {};
  var normalizedText = normalizeText(text || "").toLowerCase();
  var normalizedTitle = normalizeText(title || "").toLowerCase();
  var pattern = notFoundInterstitialPattern();
  var maxTextLength = options.maxTextLength;
  if (maxTextLength && normalizedText.length >= maxTextLength) return null;
  if (substantialArticleBodyForNotFoundCheck()) return null;

  if (options.checkStructured && structuredNotFoundInterstitial()) {
    return { structured: true };
  }

  if (options.checkStructured && /\bpage not found\b/i.test(normalizedTitle + " " + normalizedText) &&
      /\bpage you requested cannot be accessed\b|\baddress was typed incorrectly\b|\bpage does not exist\b|\bpage cannot be found\b/i.test(normalizedTitle + " " + normalizedText) &&
      !document.querySelector("article, [itemprop='articleBody'], [property='articleBody'], .article-content, .article-text, .abstract, [property='abstract']")) {
    return { structured: true };
  }

  if (!pattern.test(normalizedTitle + " " + normalizedText)) return null;

  var lead = normalizedText.slice(0, 420);
  var titleLooksMissing = pattern.test(normalizedTitle);
  var pageStartsMissing = pattern.test(lead);
  var shortMissingPage = pageStartsMissing && normalizedText.length < 900;
  var dominates = titleLooksMissing || pageStartsMissing || normalizedText.length < 900;

  if (options.requireDominance && !dominates) return null;
  if (options.excludeDefinitionsNet && /definitions\.net/i.test(normalizedTitle + " " + location.hostname)) return null;
  if (options.requireInterstitialPage && !(titleLooksMissing || shortMissingPage || (!options.substantialPublic && pageStartsMissing) || !options.substantialPublic)) return null;

  return {
    titleLooksMissing: titleLooksMissing,
    pageStartsMissing: pageStartsMissing,
    shortMissingPage: shortMissingPage,
    dominates: dominates
  };
}

function substantialArticleBodyForNotFoundCheck() {
  var root = document.querySelector("article, main article, main [data-testid*='article' i], main [class*='article-body' i], main [class*='article-content' i], main [itemprop='articleBody'], [data-testid*='article-body' i], [class*='article-body' i], [class*='article-content' i], [itemprop='articleBody']");
  if (!root) return false;

  var text = normalizeText(root.textContent || "");
  if (text.length < 700) return false;

  var paragraphs = root.querySelectorAll("p").length;
  var headings = root.querySelectorAll("h1, h2, h3").length;
  var forms = root.querySelectorAll("form input[type='password'], form input[name*='password' i]").length;
  var notFoundText = notFoundInterstitialPattern().test(text.slice(0, 500));

  return forms === 0 && !notFoundText && (paragraphs >= 3 || headings >= 2);
}

function structuredNotFoundInterstitial() {
  var main = document.querySelector("main, [role='main'], .content, body");
  if (!main) return false;

  var heading = normalizeText(((main.querySelector("h1, h2") || {}).textContent) || "");
  var text = normalizeText(main.textContent || "");
  if (!/\bpage not found\b|\bnot found\b/i.test(heading)) return false;
  if (!/\bpage you requested cannot be accessed\b|\baddress was typed incorrectly\b|\bpage does not exist\b|\bpage cannot be found\b/i.test(text)) return false;

  var articleSignals = main.querySelectorAll("article, [itemprop='articleBody'], [property='articleBody'], .article-content, .article-text, .abstract, [property='abstract']").length;
  return articleSignals === 0;
}

function likelyAuthWall(title, page, combined) {
  var normalizedTitle = normalizeText(title || "").toLowerCase();
  var normalizedPage = normalizeText(page || "");
  var path = (location.pathname || "").toLowerCase();
  var expectedAuthPath = /\/(?:log(?:in|-in)|sign(?:in|-in)|auth|oauth|sso|session|sessions|account(?:s)?\/login|users?\/sign_in|password|forgot)(?:\/|$)/.test(path);
  var authInputs = document.querySelectorAll("input[type='email'], input[name*='email' i], input[name*='password' i]").length;
  var authForms = document.querySelectorAll("form input[type='password'], form input[name*='password' i], form[action*='login' i], form[id*='login' i], form[class*='login' i], [aria-label*='sign in' i] input[type='password']").length;
  var authHeadings = manyTexts(["form h1", "form h2", "form legend", "[role='dialog'] h1", "[role='dialog'] h2", "main h1", "main h2"], 8).filter(function(text) {
    return /sign in|log in|login|create (?:an )?account|password/i.test(text);
  }).length;
  var publicSignals = document.querySelectorAll("main article, main section, main a[href], main img, main h2, main h3").length;
  // Also count broader page-level content signals for non-English pages where main may not be used
  var widePublicSignals = document.querySelectorAll("article, [role='article'], .article, .post, .entry, .content a[href], .content img, nav a[href]").length;
  var effectivePublicSignals = Math.max(publicSignals, widePublicSignals);
  var resetSignals = /forgot(?:ten)? password|reset your password|check your email for a reset link/i.test(combined);
  var authProviderSignals = /\b(?:github|gitlab|google|oauth|sso|single sign-on|continue with|sign in with|log in with)\b/i.test(combined);

  if (!expectedAuthPath && /^(?:log in|login|sign in|sign-in|sign into|log into)(?:\b|\s*[-|–])/.test(normalizedTitle) && (authInputs >= 1 || authForms > 0 || authHeadings > 0 || authProviderSignals)) {
    return effectivePublicSignals < 15;
  }

  if (resetSignals && publicSignals < 10 && normalizedPage.length < 2200) return true;
  if (!resetSignals && !/sign in to continue|log in to continue|create an account to continue|please sign in|please log in/i.test(combined)) return false;

  if (/sign in|log in|login|create (?:an )?account|reset your password/.test(normalizedTitle)) return true;

  // If the page has substantial visible content (links, images, headings), it is likely a public page
  // with incidental login UI in a header/footer — not an auth wall
  if (!/sign in|log in|login|create (?:an )?account|reset your password/.test(normalizedTitle) && effectivePublicSignals >= 15 && normalizedPage.length >= 1000) {
    return false;
  }

  return ((authForms > 0 || authHeadings > 0) && authInputs >= 1 && publicSignals < 10) ||
    (authInputs >= 1 && normalizedPage.length < 900 && publicSignals < 8) ||
    (normalizedPage.length < 400 && publicSignals < 5);
}

function publicContentSignals() {
  var mainSignals = document.querySelectorAll("main article, main section, main a[href], main img, main h2, main h3, main p, main li").length;
  var wideSignals = document.querySelectorAll("article, [role='article'], .article, .post, .entry, .content a[href], .content img, h1, h2, h3, [itemprop='articleBody'], main li").length;
  return Math.max(mainSignals, wideSignals);
}

function substantialPublicPage(page) {
  var normalizedPage = normalizeText(page || "");
  var signals = publicContentSignals();
  var headlineSignals = document.querySelectorAll("main h1, h1, main h2").length;
  var linkSignals = document.querySelectorAll("main a[href], a[href]").length;
  return signals >= 5 && (normalizedPage.length >= 180 || (headlineSignals >= 1 && linkSignals >= 3));
}

function interstitialPageType(metadata, pageText) {
  var title = normalizeText(metadata.title || document.title);
  var page = normalizeText([pageText || "", (document.body && document.body.textContent) || ""].join(" "));
  var combined = (title + " " + page).toLowerCase();
  var substantialPublic = substantialPublicPage(page);

  if (metaWallPage(metadata, pageText)) return "meta_login";
  if (/robot or human|confirm (?:that )?you (?:are|.?re) (?:a )?human|activate and hold the button|press\s*(?:&|and)\s*hold|px-captcha|drag the slider to fit the puzzle|slide to verify|help us protect|verifying that you.?re a real person|unusual activity from your computer network|click the box below to let us know you.?re not a robot/i.test(combined)) return "human_verification";
  if (/select your country|choose a country|shopping in the u\.s\?|best buy international/i.test(combined) && !substantialPublic) return "region_selector";
  if (/browser is not supported|your browser is not supported|unsupported browser|for the best experience, use any of these supported browsers|use any of these supported browsers|supported browsers:/i.test(combined) && !substantialPublic) return "browser_support";
  if (/^access error$/i.test(title) || /potential misuse|page you are trying to access is unavailable|help\.ft\.com|request blocked|you have been blocked|troubleshooting cloudflare errors/i.test(combined)) return "access_error";
  if (siteUnavailablePage(title, page)) return "site_unavailable";
  if (consentWallPage(title, page)) return "consent_wall";
  if (/\bmy account\b[\s\S]{0,120}\blog in\b/i.test(page) && /\byou must log in to access\b/i.test(page) && !document.querySelector("article, [itemprop='articleBody'], [property='articleBody']")) return "auth_wall";
  if (notFoundInterstitialEvidence(title, page, { checkStructured: true, requireDominance: true, requireInterstitialPage: true, substantialPublic: substantialPublic, excludeDefinitionsNet: true })) return "not_found";
  if (/transferring (?:you )?to (?:the )?website|در حال انتقال به وب.سایت|سایت در حال بارگذاری|sayfaya yönlendiriliyorsunuz|yönlendiriliyor|מועבר לאתר|الموقع قيد التحميل|ویب سائٹ پر منتقل/i.test(combined) && normalizeText(page).length < 600) return "js_redirect";
  if (/subscribe to continue|subscription required|sign in to continue reading|log in to continue reading|subscriber-only|purchase short-term access|institutional access|access through your institution|read with a subscription/i.test(combined)) return "subscription";
  if (likelyAuthWall(title, page, combined)) return "auth_wall";

  return null;
}

function interstitialContent(metadata, pageText) {
  var type = interstitialPageType(metadata, pageText);
  if (!type) return null;
  if (type === "meta_login") return metaWallContent(metadata, pageText);

  var title = normalizeText(metadata.title || document.title);
  var lines = manyTexts([
    "main h1",
    "main h2",
    "main p",
    "main li",
    "body h1",
    "body h2",
    "body p"
  ], 20).filter(function(text) {
    return text && text.length <= 240 && !interstitialNoiseText(text);
  });
  var description = lines.find(function(text) {
    return text !== title && text.length >= 12;
  }) || metadata.excerpt || normalizeText(pageText || "");
  var details = [];
  var highlights = [];

  if (type === "human_verification") {
    if (!title || domainLikeText(title)) title = "Robot or human?";
    details.push("Gate: human verification");
  } else if (type === "consent_wall") {
    var consentSummary = consentSummaryParts();
    if (consentSummary.headings.length) title = consentSummary.headings[0];
    if (consentSummary.description) description = consentSummary.description;
    details.push("Interstitial: cookie or consent prompt");
    highlights = consentSummary.highlights.filter(function(text) { return text !== title && text !== description; }).slice(0, 6);
  } else if (type === "region_selector") {
    details.push("Interstitial: region or country selector");
    highlights = lines.filter(function(text) { return text !== title && text !== description; }).slice(0, 3);
  } else if (type === "browser_support") {
    details.push("Interstitial: unsupported browser shell");
  } else if (type === "access_error") {
    details.push("Interstitial: access error or blocked session");
  } else if (type === "site_unavailable") {
    details.push("Interstitial: site unavailable or temporarily offline");
  } else if (type === "not_found") {
    if (!title || domainLikeText(title)) title = "Page not found";
    details.push("Interstitial: requested page is unavailable");
  } else if (type === "subscription") {
    details.push("Access notice: subscription or institutional login required");
  } else if (type === "auth_wall") {
    if (!title || domainLikeText(title)) title = "Login required";
    details.push("Access notice: login or account required");
  } else if (type === "js_redirect") {
    if (!title || domainLikeText(title)) title = "Redirecting...";
    details.push("Interstitial: JavaScript redirect page — content not yet loaded");
  }

  return articleContentFromParts({
    title: title,
    description: description,
    details: details,
    highlights: highlights,
    siteName: metadata.siteName || location.hostname,
    contentType: "interstitial"
  });
}
