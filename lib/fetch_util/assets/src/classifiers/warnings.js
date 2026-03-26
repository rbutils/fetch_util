  function slugKeywords() {
    var text = safeDecodeURI(location.pathname || "").toLowerCase().replace(/[^a-z0-9]+/g, " ");
    return text.split(/\s+/).filter(function(token) {
      return token.length >= 3 && !/^(questions|question|about|docs|wiki|html|index|start|journey|get|your|with|from|the|and|for|dictionary|definition|definitions|browse|category|recipes|recipe|english|search|translate|translation|pronunciation|thesaurus)$/.test(token) && !/^\d+$/.test(token);
    });
  }

  // Detect language indicated by URL path segments like /de/, /fr/, /es/
  function urlLanguageHint() {
    var match = (location.pathname || "").match(/^\/([a-z]{2})(?:\/|$)/);
    if (!match) match = (location.pathname || "").match(/\/([a-z]{2})(?:\/|$)/);
    if (!match) return null;
    var code = match[1];
    // Only return recognized language codes, not generic path segments
    if (/^(de|fr|es|pt|pl|it|nl|sv|da|nb|no|fi|cs|sk|hu|ro|bg|hr|sr|sl|uk|el|tr|ja|ko|zh|ar|he|th|vi|id|ms)$/.test(code)) return code;
    return null;
  }

  // Language stopword sets for content language detection
  var langStopwords = {
    de: /\b(und|die|der|das|ist|von|zu|mit|den|ein|eine|für|auf|als|auch|nicht|sich|werden|nach|bei|aus|wie|oder|noch|nur|dem|des|über)\b/gi,
    fr: /\b(les|des|une|est|dans|pour|sur|par|pas|qui|que|avec|son|sont|plus|ses|mais|cette|ont|tout|nous|vous|aux|leur)\b/gi,
    es: /\b(los|las|una|del|por|con|para|que|más|son|sus|pero|como|esta|todo|nos|hay|fue|muy|han|sin|sobre|tiene)\b/gi,
    pt: /\b(dos|das|uma|por|com|para|que|mais|são|mas|como|esta|seu|sua|tem|nos|foi|pode|muito|seus|sobre|também)\b/gi,
    pl: /\b(nie|jest|się|jak|czy|ale|lub|tak|ich|jego|już|pod|przy|bez|dla|gdy|gdzie|między|tylko|może|który|która)\b/gi,
    it: /\b(gli|una|del|per|con|che|sono|più|dalla|della|delle|dei|anche|come|questa|tutto|suo|sua|suoi|nelle|alla)\b/gi,
    nl: /\b(een|het|van|zijn|met|dat|voor|maar|niet|ook|als|nog|wel|hun|uit|bij|kan|zou|meer|alle|dit|wordt)\b/gi
  };

  function bodyMatchesLanguage(langCode, body) {
    var pattern = langStopwords[langCode];
    if (!pattern) return true; // Unknown language, assume match
    var matches = body.match(pattern) || [];
    var words = body.split(/\s+/).length;
    // Expect at least 3% of words to be stopwords in the expected language
    return words < 40 || (matches.length / words) >= 0.03;
  }

  function consentWallDominates(text) {
    var normalized = normalizeText(text || "").toLowerCase();
    if (!normalized) return false;

    var cookiePattern = /cookie settings|we use cookies|accept all cookies|reject optional cookies|cookie preferences|allow the use of cookies|cookies from other companies|essential cookies|cookie notice|use cookies and similar technologies|manage cookie preferences|manage cookies|privacy choices|personalize advertising|wish to store and access information|access information on your devices|collect personal data|personalized ads|trusted third party partners|browsing history|device identifiers|pliki cookie|ustawienia prywatności|polityka prywatności|datenschutz|données personnelles|datos personales|dati personali|utilizamos cookies|utilizziamo i cookie|preferenze cookie|accetta tutto|クッキー|Cookieプリファレンス|Cookie設定|同意設定|すべて受け入れる|すべて許可|쿠키|동의|모두 허용|全部接受|接受全部|隐私设置|файлы cookie|настройки cookie|принять все|we gebruiken cookies|nastavení souhlasu|souhlas s personalizací|soubory cookie|vi bruger cookies|vi använder cookies|kakor|samtycke|informasjonskapsler|personvern|dine data|aller media|galetes|protecció de dades|о вашој приватности|пристанак|колачић|колачиће|подешавања приватности/i;
    if (!cookiePattern.test(normalized)) return false;

    if (/^(cookie settings|let us know your cookie preferences|allow the use of cookies|we use cookies|before you continue|manage cookie preferences|ustawienia prywatności|pliki cookie|datenschutz|welcome we and our .+ partners? wish to store|about your privacy|cookieプリファレンスセンター|クッキー設定|同意の優先設定|쿠키 설정|개인정보 설정|cookie 偏好设置|隐私设置|настройки cookie|файлы cookie|nastavení souhlasu|souhlas s personalizací|soubory cookie|informasjonskapsler|personvern|aller media er ansvarlig for dine data|galetes|protecció de dades|о вашој приватности|пристанак|колачић)/.test(normalized)) return true;

    var hits = normalized.match(/cookie|cookies|accept all|reject optional|essential cookies|preferences|privacy choices|personal data|browsing history|device identifiers|personalized ads|trusted third party|wish to store|manage consent|advertising cookies|strictly necessary|social media cookies|legitimate interest|pliki cookie|prywatności|datenschutz|クッキー|同意|受け入れる|쿠키|동의|허용|接受|隐私|принять|файлы cookie|souhlas|personalizac|soukromí|soubory cookie|kakor|sekretess|samtycke|privatlivs|samtykke|informasjonskapsler|personvern|dine data|galetes|protecció|пристанак|колачић|приватности/g) || [];
    if (normalized.length < 5000 && hits.length >= 3) return true;
    // For longer text, check if consent keywords dominate: >= 0.4 hits per 500 chars
    if (hits.length >= 8 && (hits.length / (normalized.length / 500)) >= 0.4) return true;
    return false;
  }

  function suspicionReasons(metadata, content, markdown, pageText, signals) {
    var reasons = [];
    var title = normalizeText((content && content.title) || metadata.title).toLowerCase();
    var body = normalizeText(markdown || (content && content.textContent) || "").toLowerCase();
    var page = normalizeText(pageText || "").toLowerCase();
    var combined = (title + " " + body + " " + page).trim();
    var challengeType = challengePageType(metadata, pageText, signals);
    var interstitialType = interstitialPageType(metadata, pageText);
    var docsLike = !!(content && content.docsLike);
    var glossaryPage = /definition of |what does .+ mean\??| pronunciation in english|dictionary|definitions for /.test(title) || /(\/dictionary\/|\/definition\/|\/definitions\/|\/pronunciation\/)/.test(location.pathname || "") ||
      (!!queryParam("q") && /\b(dictionary|translation|translate|thesaurus|lexicon|s[łl]ownik|t[łl]umaczenie)\b/.test(title + " " + normalizeText(metadata.excerpt || "").toLowerCase()));
    var readableDocsPage = docsLike && body.length > 20;
    var emptyExtraction = !normalizeText(markdown || "") && !normalizeText((content && content.textContent) || "");
    var substantialContent = body.length > 500 && !consentWallDominates(body);

    if (!docsLike && consentWallDominates(body)) reasons.push("consent_interstitial");
    if (!docsLike && !substantialContent && (consentLikeInterstitial(interstitialType, combined, body, page) || consentWallDominates(page))) {
      reasons.push("consent_interstitial");
    }
    if (challengeType === "anubis") reasons.push("anubis_challenge_page");
    if (challengeType === "datadome") reasons.push("datadome_challenge_page");
    if (challengeType === "cloudflare") reasons.push("cloudflare_challenge_page");
    if (interstitialType === "consent_wall") reasons.push("consent_interstitial");
    if (interstitialType === "meta_login") reasons.push("meta_login_wall");
    if (interstitialType === "human_verification") reasons.push("human_verification_interstitial");
    if (interstitialType === "region_selector") reasons.push("regional_selector_interstitial");
    if (interstitialType === "browser_support") reasons.push("browser_support_interstitial");
    if (interstitialType === "access_error") reasons.push("access_error_interstitial");
    if (interstitialType === "site_unavailable") reasons.push("site_unavailable_interstitial");
    if (interstitialType === "not_found" && !(docsLike && readableDocsPage)) reasons.push("not_found_interstitial");
    if (interstitialType === "subscription") reasons.push("subscription_interstitial");
    if (interstitialType === "auth_wall") reasons.push("auth_or_login_interstitial");
    if (interstitialType === "meta_login" && /cookie/i.test(combined)) reasons.push("consent_interstitial");
    if (!(docsLike && readableDocsPage) && (challengeType || /(verify you are human|unusual traffic|are you a robot|access denied|security verification|checking your browser)/.test(combined))) {
      reasons.push("bot_or_access_interstitial");
    }
    if (!(docsLike && readableDocsPage) && (interstitialType === "human_verification" || interstitialType === "access_error")) reasons.push("bot_or_access_interstitial");
    if (emptyExtraction && page.length > 80) reasons.push("empty_extraction");
    // Flag empty/near-empty markdown even when pageText is also sparse (JS SPA failure)
    if (!challengeType && !interstitialType && normalizeText(markdown || "").length < 10 && (metadata.title || "").length > 3) {
      if (reasons.indexOf("empty_extraction") === -1 && reasons.indexOf("short_extraction") === -1) reasons.push("short_extraction");
    }

    if (!challengeType && !interstitialType && content && content.contentType !== "search") {
      var extractedLength = body.length;
      var pageLength = page.length;
      var slugTerms = slugKeywords();
      var hasArticlePath = slugTerms.length >= 2;

      if (content.contentType === "article" && !readableDocsPage && !glossaryPage) {
        if (hasArticlePath && extractedLength < 500 && pageLength > 2000) {
          reasons.push("truncated_content");
        }
      }

      // General short extraction: substantial page content was lost during extraction
      if (extractedLength < 200 && pageLength > 1000 && !readableDocsPage && !glossaryPage) {
        reasons.push("short_extraction");
      }

      // Glossary-specific: dictionary/definition page title but very little content extracted
      if (glossaryPage && extractedLength < 60 && pageLength > 500) {
        reasons.push("short_extraction");
      }
    }

    var keywords = slugKeywords();
    var queryListPage = content && content.contentType === "list" && (
      queryParam("q") || queryParam("_nkw") || queryParam("st") || /^\/search\//.test(location.pathname)
    );
    if (!challengeType && !interstitialType && keywords.length >= 2 && !queryListPage && !docsLike) {
      // Skip slug-keyword mismatch check when extracted body is predominantly non-Latin script
      // (e.g. Devanagari, Bengali, CJK) since URL slugs are typically ASCII transliterations
      var latinChars = (body.match(/[a-zA-Z]/g) || []).length;
      var totalChars = body.replace(/\s/g, "").length;
      var latinRatio = totalChars > 0 ? latinChars / totalChars : 1;
      if (latinRatio > 0.25) {
        var overlap = keywords.filter(function(token) {
          return combined.indexOf(token) !== -1;
        }).length;
        if ((overlap / keywords.length) < 0.34) reasons.push("url_content_mismatch");
      }
    }

    // Language mismatch: URL or page lang indicates one language, but body content is in another
    if (!challengeType && !interstitialType && body.length > 200) {
      var expectedLang = urlLanguageHint() || (metadata.language || "").slice(0, 2).toLowerCase();
      if (expectedLang && langStopwords[expectedLang] && !bodyMatchesLanguage(expectedLang, body)) {
        reasons.push("url_content_mismatch");
      }
    }

    if (content && content.contentType === "search") {
      if ((content.resultCount || 0) < 3) reasons.push("search_results_unusable");
      if (/^aplikacje google$/i.test(title) || /^google apps$/i.test(title)) reasons.push("search_engine_shell_page");
      if (/zawartość została wygenerowana przy użyciu ai|generated with ai|ai-generated/i.test(combined)) reasons.push("search_engine_ai_summary_only");
    }

    return reasons;
  }
