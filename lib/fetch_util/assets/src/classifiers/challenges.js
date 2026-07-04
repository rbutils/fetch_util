  var COOKIE_CONSENT_KEYWORDS = "cookie|cookies|cookie settings|we use cookies|we use cookies and data|accept all cookies|accept all|reject all|reject optional cookies|reject optional|more options|cookie preferences|let us know your cookie preferences|allow the use of cookies|cookies from other companies|essential cookies|cookie notice|use cookies and similar technologies|manage cookie preferences|manage cookies|manage your privacy settings|privacy choices|personalize advertising|personalized content|welcome we and our .+ partners? wish to store|about your privacy|wish to store and access information|access information on your devices|collect personal data|personalized ads|trusted third party partners|trusted third party|browsing history|device identifiers|personal data|preferences|consent|manage consent|advertising cookies|strictly necessary|social media cookies|legitimate interest|pliki cookie|ustawienia prywatności|polityka prywatności|prywatności|datenschutz|données personnelles|datos personales|dati personali|utilizamos cookies|utilizziamo i cookie|preferenze cookie|accetta tutto|クッキー|Cookieプリファレンス|cookieプリファレンスセンター|Cookie設定|クッキー設定|同意設定|同意の優先設定|すべて受け入れる|すべて許可|同意|受け入れる|쿠키|쿠키 설정|개인정보 설정|동의|모두 허용|허용|全部接受|接受全部|cookie 偏好设置|隐私设置|接受|隐私|файлы cookie|настройки cookie|принять все|принять|we gebruiken cookies|nastavení souhlasu|nastaveni cookies|souhlas s personalizací|souhlas|personalizac|soukromí|soubory cookie|sutikmeny|vi bruger cookies|vi använder cookies|vi anvander kakor|kakor|sekretess|samtycke|samtykke|informasjonskapsler|vi bruker informasjonskapsler|personvern|personverninnstillinger|dine personverninnstillinger|ditt personvern|dine data|aller media|aller media er ansvarlig for dine data|privatlivs|galetes|protecció de dades|protecció|о вашој приватности|пристанак|колачић|колачиће|подешавања приватности|приватности|evästeet|evasteasetukset|evästeasetukset|evästeitä|kaytamme evasteita|käytämme evästeitä|hyväksy evästeet|tietosuoja|slapukai|slapuku nustatymai|slapukų nustatymai|naudojame slapukus|slapukų|slapukus|колачиња|приватност|поставки за колачиња|cookie-uri|confidențialitate|utilizăm cookie-uri|siklapuku iestatijumi|sīkdatnes|sīkdatņu iestatījumi|sīkdatņu|sīkfailus|izmantojam siklapukus|izmantojam sīkdatnes|privātums|privātuma iestatījumi|privātuma|sütiket|süti beállítások|süti|adatvédelem|adatvédelmi beállítások|adatvédelmi|o vašoj privatnosti|o vašoj privatnosti|пристанак|колачић|подешавања приватности|before you continue|before you continue to (google|youtube)|privacy gate|jouw privacy-instellingen|cookie-indstillinger|siklapuku iestatijumi";

  function consentKeywordPattern(flags) {
    return new RegExp(COOKIE_CONSENT_KEYWORDS, flags || "");
  }

  function consentKeywordLeadPattern(flags) {
    return new RegExp("^(?:" + COOKIE_CONSENT_KEYWORDS + ")", flags || "");
  }

  function challengeHostLabel(metadata) {
    var candidates = [location.hostname, metadata && metadata.siteName, metadata && metadata.title];

    for (var i = 0; i < candidates.length; i += 1) {
      var value = normalizeText(candidates[i] || "").replace(/^www\./i, "");
      if (domainLikeText(value)) return value;
    }

    return null;
  }

  function domSignals() {
    var iframeData = Array.prototype.map.call(document.querySelectorAll("iframe"), function(frame) {
      return {
        title: normalizeText(frame.getAttribute("title") || ""),
        src: normalizeText(frame.getAttribute("src") || "")
      };
    });

    return {
      iframeTitles: iframeData.map(function(frame) { return frame.title; }).filter(Boolean),
      iframeSources: iframeData.map(function(frame) { return frame.src; }).filter(Boolean),
      scriptSources: Array.prototype.map.call(document.querySelectorAll("script[src]"), function(script) {
        return normalizeText(script.getAttribute("src") || "");
      }).filter(Boolean),
      textLength: pageReadableText().length,
      htmlLength: (document.body && document.body.innerHTML || "").length,
      bodyHtml: (document.body && document.body.innerHTML || "").slice(0, 8000)
    };
  }

  function challengeAssetText(signals) {
    signals = signals || {};
    return normalizeText([
      (signals.iframeTitles || []).join(" "),
      (signals.iframeSources || []).join(" "),
      (signals.scriptSources || []).join(" "),
      signals.bodyHtml || ""
    ].join(" ")).toLowerCase();
  }

  function challengeEducationalContext(page) {
    return /(this page explains|this is an experiment|example page|demonstrate a webauthn-based interactive challenge|not part of cloudflare challenge production code)/i.test(page || "");
  }

  function anubisChallengePage(title, page) {
    title = title || "";
    page = page || "";

    return /making sure you're not a bot!?/i.test(title + " " + page) ||
      (/protected by anubis/i.test(page) && /(enable javascript to get past this challenge|please wait a moment while we ensure the security of your connection|loading)/i.test(page));
  }

  function dataDomeChallengePage(title, page, signals) {
    title = title || "";
    page = page || "";
    var assets = challengeAssetText(signals);
    var nearEmpty = !page || normalizeText(page).length < 80;

    return /datadome captcha/i.test(title + " " + page) ||
      (nearEmpty && /(captcha-delivery\.com|datadome captcha|\bvar dd=)/i.test(assets));
  }

  function cloudflareChallengePage(title, page, signals) {
    title = title || "";
    page = page || "";
    var assets = challengeAssetText(signals);
    var nearEmpty = !page || normalizeText(page).length < 120;

    if (challengeEducationalContext(page)) return false;

    return /attention required! \| cloudflare/i.test(title) ||
      ((/just a moment/i.test(title) || /verify you are human|checking your browser|performing security verification|verification successful\. waiting for .* to respond|reviewing the security of your connection before proceeding|please enable javascript and cookies to continue|security service to protect/i.test(page)) &&
        !/this page explains/i.test(page)) ||
      (((/turnstile/i.test(title) || /turnstile/i.test(page)) && /managed challenge|interactive challenge/i.test(page)) && !challengeEducationalContext(page)) ||
      (nearEmpty && /(cdn-cgi\/challenge-platform|cloudflare ray id|turnstile|cf challenge)/i.test(assets) && !challengeEducationalContext(assets));
  }

  function challengePageType(metadata, pageText, signals) {
    var title = normalizeText(metadata.title || document.title);
    var page = normalizeText(pageText || "");

    if (anubisChallengePage(title, page)) return "anubis";
    if (dataDomeChallengePage(title, page, signals)) return "datadome";
    if (cloudflareChallengePage(title, page, signals)) return "cloudflare";
    return null;
  }

  function challengeFallbackTitle(type, metadata) {
    if (type === "anubis") return "Making sure you're not a bot!";

    var host = challengeHostLabel(metadata);
    if (host) return "Access verification required for " + host;

    if (type === "datadome") return "Access verification required";
    return "Verifying you are human";
  }

  function challengeFallbackDescription(type, signals) {
    var description = type === "anubis" ?
      "This page is presenting an Anubis challenge before the original content is available." :
      (type === "datadome" ?
        "This page is presenting a DataDome CAPTCHA challenge before the original content is available." :
        "This page is presenting a Cloudflare or Turnstile challenge before the original content is available.");

    if (signals && signals.textLength < 40 && signals.htmlLength > 200) {
      description += " The readable DOM content is effectively empty in this environment.";
    }

    return description;
  }

  function challengeContent(metadata, pageText, signals) {
    var type = challengePageType(metadata, pageText, signals);
    if (!type) return null;

    var title = normalizeText(metadata.title || document.title);
    if (!title || domainLikeText(title) || /^www\./i.test(title)) {
      title = challengeFallbackTitle(type, metadata);
    }

    var description = challengeFallbackDescription(type, signals);
    var details = [type === "anubis" ? "Challenge: Anubis" : (type === "datadome" ? "Challenge: DataDome" : "Challenge: Cloudflare/Turnstile")];
    if (signals && signals.textLength < 40 && signals.htmlLength > 200) details.push("Readable DOM: challenge page only");

    return articleContentFromParts({
      title: title,
      description: description,
      highlights: [],
      details: details,
      siteName: metadata.siteName || location.hostname,
      contentType: "interstitial"
    });
  }

  function metaRequestedLabel() {
    var target = queryParam("next") || location.pathname;

    try {
      target = new URL(target, location.href).pathname;
    } catch (_error) {
    }

    var parts = safeDecodeURI(target || "").split("/").filter(Boolean);
    if (!parts.length) return null;
    if (parts[0] === "login") return normalizeText(parts[1] || "");
    return normalizeText(parts[0]);
  }

  function metaWallPage(metadata, pageText) {
    var signature = normalizeText([
      location.hostname,
      metadata && metadata.siteName,
      metadata && metadata.title,
      metadata && metadata.excerpt
    ].join(" ")).toLowerCase();
    var combined = normalizeText([
      pageText
    ].join(" ")).toLowerCase();

    if (!/(^|\.)(facebook\.com|threads\.(net|com))$/.test(location.hostname) && !/(facebook|threads|meta)/.test(signature)) return false;

    return /meta products|cookies from other companies|allow the use of cookies from threads by instagram|log in with your instagram|join threads to share ideas|create new account|log in to facebook|log in to continue|essential cookies/.test(signature + " " + combined);
  }

  function metaWallContent(metadata, pageText) {
    if (!metaWallPage(metadata, pageText)) return null;

    var threadsHost = /(threads)/i.test([location.hostname, metadata && metadata.siteName, metadata && metadata.title].join(" "));
    var title = normalizeText(metadata.title || document.title);
    var target = metaRequestedLabel();
    var details = [threadsHost ? "Access notice: Threads login or cookie acceptance required" : "Access notice: Facebook login or cookie acceptance required"];
    var description = metadata.excerpt;

    if (!title || /threads\s*[•|-]\s*log in|facebook\s*-\s*log in/i.test(title)) {
      title = target ? (threadsHost ? "Threads page " + target : "Facebook page " + target) : (threadsHost ? "Threads page" : "Facebook page");
    }

    if (!description || /join threads to share ideas|log in with your instagram|create an account or log into facebook/i.test(description)) {
      description = threadsHost ?
        "Original content on this Threads page is not available without login or cookie acceptance." :
        "Original content on this Facebook page is not available without login or cookie acceptance.";
    }

    if (target && title.indexOf(target) === -1) details.push("Requested page: " + target);

    return articleContentFromParts({
      title: title,
      description: description,
      details: details,
      siteName: metadata.siteName || location.hostname
    });
  }

  function interstitialNoiseText(text) {
    return /^(skip to content|showing slide\b|trending searches|popular near you|concerts|sports|theater|family)$/i.test(text || "");
  }

  function consentSummaryVisible(node) {
    if (!node || !node.getBoundingClientRect) return false;
    var rect = node.getBoundingClientRect();
    var style = window.getComputedStyle(node);
    return rect.width > 0 && rect.height > 0 && style.visibility !== "hidden" && style.display !== "none";
  }

  function consentSummaryText(node) {
    if (!node) return "";
    return normalizeText(node.innerText || node.textContent || node.value || node.getAttribute("aria-label") || node.getAttribute("title") || "");
  }

  function addConsentSummaryItem(items, seen, text, limit) {
    text = normalizeText(text || "");
    if (!text || text.length > limit || interstitialNoiseText(text)) return;
    if (seen[text]) return;
    seen[text] = true;
    items.push(text);
  }

  function consentSummaryParts() {
    var seen = {};
    var headings = [];
    var paragraphs = [];
    var bullets = [];
    var controls = [];

    document.querySelectorAll("main h1, main h2, main h3, body h1, body h2, body h3").forEach(function(node) {
      if (!consentSummaryVisible(node)) return;
      addConsentSummaryItem(headings, seen, consentSummaryText(node), 140);
    });

    document.querySelectorAll("main p, body p").forEach(function(node) {
      if (!consentSummaryVisible(node)) return;
      addConsentSummaryItem(paragraphs, seen, consentSummaryText(node), 260);
    });

    document.querySelectorAll("main li, body li").forEach(function(node) {
      if (!consentSummaryVisible(node)) return;
      addConsentSummaryItem(bullets, seen, consentSummaryText(node), 160);
    });

    document.querySelectorAll("main button, main [role='button'], main a[href], body button, body [role='button'], body a[href]").forEach(function(node) {
      if (!consentSummaryVisible(node)) return;
      var text = consentSummaryText(node);
      if (!text || text.length > 80) return;
      if (!/(accept|reject|decline|manage|options|settings|choices|privacy|cookies?|consent|allow|agree|continue|more|customize|save|confirm|necessary|essential|preferences|alles|tout|todas?|todos?|rifiuta|rejeitar|weigeren|afvis|hylkää|odmítnout|noraidīt|elutasítás|elutasítom)/i.test(text)) return;
      addConsentSummaryItem(controls, seen, "Control: " + text, 100);
    });

    var mainParagraph = paragraphs.find(function(text) {
      return text.length >= 40 && /(cookies?|data|privacy|personal|ads?|content|services|device|information|partners?|consent)/i.test(text);
    }) || paragraphs.find(function(text) {
      return text.length >= 20;
    }) || null;

    return {
      headings: headings,
      description: mainParagraph,
      highlights: headings.concat(paragraphs).concat(bullets).concat(controls)
    };
  }

  function consentLikeInterstitial(interstitialType, combined, body, page) {
    var normalizedBody = normalizeText(body || "").toLowerCase();
    var normalizedPage = normalizeText(page || "").toLowerCase();
    var cookiePattern = consentKeywordPattern("i");
    var cookieLeadPattern = consentKeywordLeadPattern();
    var bodySignals = cookiePattern.test(normalizedBody);
    var pageSignals = cookiePattern.test(normalizedPage);

    if (!bodySignals && !pageSignals && interstitialType !== "meta_login") return false;

    var bodyCookieLed = cookieLeadPattern.test(normalizedBody) || (normalizedBody.indexOf("cookie") >= 0 && normalizedBody.indexOf("cookie") < 140 && normalizedBody.length < 500);
    var pageCookieLed = cookieLeadPattern.test(normalizedPage) || (normalizedPage.indexOf("cookie") >= 0 && normalizedPage.indexOf("cookie") < 140 && normalizedBody.length < 260);

    return interstitialType === "meta_login" || bodyCookieLed || pageCookieLed;
  }

  function consentWallPage(title, page) {
    var normalizedTitle = normalizeText(title || "").toLowerCase();
    var normalizedPage = normalizeText(page || "").toLowerCase();
    var cookiePattern = consentKeywordPattern();
    var cookieLeadPattern = consentKeywordLeadPattern();
    if (/^before you continue to (google|youtube)\b/.test(normalizedTitle)) return true;
    if (/before you continue to (google|youtube)/.test(normalizedPage) && /accept all|reject all|more options|we use cookies and data/.test(normalizedPage)) return true;
    if (!consentWallDominates(normalizedPage)) return false;

    return cookiePattern.test(normalizedTitle) || cookieLeadPattern.test(normalizedPage);
  }

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

  function notFoundInterstitialDominates(text, title) {
    var normalizedText = normalizeText(text || "").toLowerCase();
    var normalizedTitle = normalizeText(title || "").toLowerCase();
    var pattern = notFoundInterstitialPattern();
    if (!pattern.test(normalizedTitle + " " + normalizedText)) return false;

    var lead = normalizedText.slice(0, 420);
    return pattern.test(normalizedTitle) || pattern.test(lead) || normalizedText.length < 900;
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
    if (structuredNotFoundInterstitial()) return "not_found";
    if (/\bpage not found\b/i.test(combined) &&
        /\bpage you requested cannot be accessed\b|\baddress was typed incorrectly\b|\bpage does not exist\b|\bpage cannot be found\b/i.test(combined) &&
        !document.querySelector("article, [itemprop='articleBody'], [property='articleBody'], .article-content, .article-text, .abstract, [property='abstract']")) {
      return "not_found";
    }
    if (notFoundInterstitialDominates(page, title)) {
      var titleLooksMissing = notFoundInterstitialPattern().test(title.toLowerCase());
      var pageStartsMissing = notFoundInterstitialPattern().test(page.toLowerCase().slice(0, 420));
      var shortMissingPage = pageStartsMissing && normalizeText(page).length < 900;
      if (!/definitions\.net/i.test(title + " " + location.hostname) && (titleLooksMissing || shortMissingPage || (!substantialPublic && pageStartsMissing) || !substantialPublic)) {
        return "not_found";
      }
    }
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
