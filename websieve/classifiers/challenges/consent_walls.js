var COOKIE_CONSENT_KEYWORDS = "cookie|cookies|cookie settings|we use cookies|we use cookies and data|accept all cookies|accept all|reject all|reject optional cookies|reject optional|more options|cookie preferences|let us know your cookie preferences|allow the use of cookies|cookies from other companies|essential cookies|cookie notice|use cookies and similar technologies|manage cookie preferences|manage cookies|manage your privacy settings|privacy choices|personalize advertising|personalized content|welcome we and our .+ partners? wish to store|about your privacy|wish to store and access information|access information on your devices|collect personal data|personalized ads|trusted third party partners|trusted third party|browsing history|device identifiers|personal data|preferences|consent|manage consent|advertising cookies|strictly necessary|social media cookies|legitimate interest|pliki cookie|ustawienia prywatności|polityka prywatności|prywatności|datenschutz|données personnelles|datos personales|dati personali|utilizamos cookies|utilizziamo i cookie|preferenze cookie|accetta tutto|クッキー|Cookieプリファレンス|cookieプリファレンスセンター|Cookie設定|クッキー設定|同意設定|同意の優先設定|すべて受け入れる|すべて許可|同意|受け入れる|쿠키|쿠키 설정|개인정보 설정|동의|모두 허용|허용|全部接受|接受全部|cookie 偏好设置|隐私设置|接受|隐私|файлы cookie|настройки cookie|принять все|принять|we gebruiken cookies|nastavení souhlasu|nastaveni cookies|souhlas s personalizací|souhlas|personalizac|soukromí|soubory cookie|sutikmeny|vi bruger cookies|vi använder cookies|vi anvander kakor|kakor|sekretess|samtycke|samtykke|informasjonskapsler|vi bruker informasjonskapsler|personvern|personverninnstillinger|dine personverninnstillinger|ditt personvern|dine data|aller media|aller media er ansvarlig for dine data|privatlivs|galetes|protecció de dades|protecció|о вашој приватности|пристанак|колачић|колачиће|подешавања приватности|приватности|evästeet|evasteasetukset|evästeasetukset|evästeitä|kaytamme evasteita|käytämme evästeitä|hyväksy evästeet|tietosuoja|slapukai|slapuku nustatymai|slapukų nustatymai|naudojame slapukus|slapukų|slapukus|колачиња|приватност|поставки за колачиња|cookie-uri|confidențialitate|utilizăm cookie-uri|siklapuku iestatijumi|sīkdatnes|sīkdatņu iestatījumi|sīkdatņu|sīkfailus|izmantojam siklapukus|izmantojam sīkdatnes|privātums|privātuma iestatījumi|privātuma|sütiket|süti beállítások|süti|adatvédelem|adatvédelmi beállítások|adatvédelmi|o vašoj privatnosti|o vašoj privatnosti|пристанак|колачић|подешавања приватности|before you continue|before you continue to (google|youtube)|privacy gate|jouw privacy-instellingen|cookie-indstillinger|siklapuku iestatijumi";

function consentKeywordPattern(flags) {
  return new RegExp(COOKIE_CONSENT_KEYWORDS, flags || "");
}

function consentKeywordLeadPattern(flags) {
  return new RegExp("^(?:" + COOKIE_CONSENT_KEYWORDS + ")", flags || "");
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

function agreementLoginGateEvidence() {
  var headings = Array.prototype.filter.call(document.querySelectorAll("h1, h2, h3, [role='heading']"), function(node) {
    return consentSummaryVisible(node) && /\b(?:log in|login|sign in|sign up|create (?:an )?account)\b/i.test(consentSummaryText(node));
  });

  for (var headingIndex = 0; headingIndex < headings.length; headingIndex += 1) {
    var owner = headings[headingIndex];
    while (owner && owner !== document.body) {
      if (consentSummaryVisible(owner)) {
        var visibleLinks = Array.prototype.filter.call(owner.querySelectorAll("a[href]"), consentSummaryVisible);
        var agreementLink = visibleLinks.find(function(link) {
          return /\b(?:user agreement|terms (?:of (?:service|use)|and conditions))\b/i.test(consentSummaryText(link));
        });
        var privacyLink = visibleLinks.find(function(link) {
          return /\bprivacy (?:policy|notice|statement)\b/i.test(consentSummaryText(link));
        });
        var visibleControls = Array.prototype.filter.call(owner.querySelectorAll("button, [role='button'], a[href], label, input, select, textarea"), consentSummaryVisible);
        var controls = visibleControls.filter(function(node) {
          var text = consentSummaryText(node) || node.getAttribute("placeholder") || node.getAttribute("name") || "";
          return /\b(?:continue|email|username|password|log in|login|sign in|sign up|sso|forgot|one-time|phone)\b/i.test(text);
        });
        var credentialControl = visibleControls.find(function(node) {
          var text = consentSummaryText(node) || node.getAttribute("placeholder") || node.getAttribute("name") || "";
          return String(node.getAttribute("type") || "").toLowerCase() === "password" || /\b(?:username|password|one-time|sso)\b/i.test(text);
        });
        var authAction = visibleControls.find(function(node) {
          if (!node.matches("button, [role='button'], a[href], input[type='submit'], input[type='button']")) return false;
          var text = consentSummaryText(node) || node.getAttribute("value") || node.getAttribute("aria-label") || "";
          return /\b(?:log in|login|sign in|sign up|create (?:an )?account)\b/i.test(text);
        });
        if (agreementLink && privacyLink && controls.length >= 2 && credentialControl && authAction) {
          return { owner: owner, heading: headings[headingIndex] };
        }
      }
      owner = owner.parentElement;
    }
  }

  return null;
}

function agreementLoginGateSummary(evidence) {
  var owner = evidence.owner;
  var selected = [];
  var seen = {};
  var lines = [];

  Array.prototype.forEach.call(owner.querySelectorAll("*"), function(node) {
    if (!consentSummaryVisible(node)) return;
    var semantic = node.matches("h1, h2, h3, p, li, label, button, [role='button'], a[href], input, select, textarea");
    if (!semantic && node.children.length) return;
    if (selected.some(function(parent) { return parent.contains(node); })) return;

    var rendered = "";
    if (node.matches("p, li") && node.querySelector("a[href]")) {
      rendered = cleanupMarkdownNoise(markdownFor(node.outerHTML));
    } else {
      rendered = consentSummaryText(node) || node.getAttribute("placeholder") || node.getAttribute("aria-label") || node.getAttribute("name") || "";
    }
    rendered = String(rendered || "").trim();
    var key = normalizeText(rendered);
    if (!key || seen[key]) return;
    seen[key] = true;
    selected.push(node);
    lines.push({ node: node, text: rendered, key: key });
  });

  var title = consentSummaryText(evidence.heading);
  var descriptionEntry = lines.find(function(entry) {
    return entry.node.matches("p") && entry.key !== title && entry.key.length >= 20;
  });
  return {
    title: title,
    description: descriptionEntry ? descriptionEntry.text : null,
    highlights: lines.filter(function(entry) {
      return entry.key !== title && entry !== descriptionEntry;
    }).map(function(entry) { return entry.text; })
  };
}

function consentCookieNoticeLead(text, maxLength) {
  if (text.length >= maxLength || text.indexOf("cookie") < 0 || text.indexOf("cookie") >= 140) return false;
  var lead = text.slice(0, 180);
  var usage = /\b(?:we|our (?:site|website)|this (?:site|website))\s+(?:use|uses|set)\s+cookies?\b/i;
  var choice = /\b(?:accept|reject|manage|allow|agree to)\s+(?:all\s+)?cookies?\b/i;
  var notice = /\b(?:use of cookies?|cookies?\s+(?:are|will be)\s+used|cookies?\s+(?:preferences?|settings?|notice|consent))\b/i;
  return usage.test(lead) || choice.test(lead) || notice.test(lead);
}

function consentLikeInterstitial(interstitialType, combined, body, page) {
  var normalizedBody = normalizeText(body || "").toLowerCase();
  var normalizedPage = normalizeText(page || "").toLowerCase();
  var cookiePattern = consentKeywordPattern("i");
  var cookieLeadPattern = consentKeywordLeadPattern();
  var bodySignals = cookiePattern.test(normalizedBody);
  var pageSignals = cookiePattern.test(normalizedPage);

  if (!bodySignals && !pageSignals && interstitialType !== "meta_login") return false;

  var bodyCookieLed = cookieLeadPattern.test(normalizedBody) || consentCookieNoticeLead(normalizedBody, 500);
  var pageCookieLed = cookieLeadPattern.test(normalizedPage) || consentCookieNoticeLead(normalizedPage, 260);

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
