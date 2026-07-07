  function hostMatches(pattern, host) {
    host = host || location.hostname || "";

    if (!pattern) return false;
    if (Array.isArray(pattern)) {
      for (var i = 0; i < pattern.length; i += 1) {
        if (hostMatches(pattern[i], host)) return true;
      }
      return false;
    }
    if (pattern instanceof RegExp) return pattern.test(host);
    if (typeof pattern === "function") return pattern(host);
    if (typeof pattern === "string") return host === pattern || host.slice(-(pattern.length + 1)) === "." + pattern;
    return false;
  }

  function domainLikeText(text) {
    return /^[\w.-]+\.[a-z]{2,}$/i.test(normalizeText(text || ""));
  }

  function cloneIntoDocument(node, ownerDoc) {
    ownerDoc = ownerDoc || document;
    if (!node) return null;
    if (node.nodeType === 3) return ownerDoc.createTextNode(node.textContent || "");
    if (node.nodeType !== 1) return null;

    var tag = (node.tagName || "").toLowerCase();
    var cloneTag = tag && !/-/.test(tag) ? tag : "div";
    var clone;
    try {
      clone = ownerDoc.createElement(cloneTag || "div");
    } catch (e) {
      clone = ownerDoc.createElement("div");
    }

    Array.prototype.forEach.call(node.attributes || [], function(attr) {
      if (!attr || !attr.name || /^on/i.test(attr.name)) return;
      try {
        clone.setAttribute(attr.name, attr.value);
      } catch (e) {}
    });

    Array.prototype.forEach.call(node.childNodes || [], function(child) {
      var childClone = cloneIntoDocument(child, ownerDoc);
      if (childClone) clone.appendChild(childClone);
    });

    return clone;
  }

  function safeDeepClone(node, ownerDoc) {
    try {
      return node.cloneNode(true);
    } catch (e) {
      return cloneIntoDocument(node, ownerDoc);
    }
  }

  function safeReadableDocumentClone() {
    try {
      return document.cloneNode(true);
    } catch (e) {}

    var fallback = document.implementation.createHTMLDocument(document.title || "");
    if (document.documentElement && document.documentElement.getAttribute("lang")) {
      fallback.documentElement.setAttribute("lang", document.documentElement.getAttribute("lang"));
    }

    while (fallback.head.firstChild) fallback.head.removeChild(fallback.head.firstChild);
    Array.prototype.forEach.call((document.head && document.head.childNodes) || [], function(child) {
      var childClone = cloneIntoDocument(child, fallback);
      if (childClone) fallback.head.appendChild(childClone);
    });

    if (document.body) {
      var bodyClone = cloneIntoDocument(document.body, fallback) || fallback.createElement("body");
      fallback.documentElement.replaceChild(bodyClone, fallback.body);
    }

    return fallback;
  }

  function cleanClone(node) {
    if (cookieChromeNode(node)) {
      var empty = document.createElement("div");
      return empty;
    }

    var clone = safeDeepClone(node, document);
    if (!clone) return document.createElement("div");
    preserveMeaningfulButtons(clone);
    // Preserve ReDoc endpoint bars before removing buttons.
    // These have: <button><span class="http-verb get">get</span><span>/path</span></button>
    clone.querySelectorAll("button").forEach(function(btn) {
      var verb = btn.querySelector("[class*='http-verb']");
      if (!verb) return;
      var path = "";
      var spans = btn.querySelectorAll("span");
      for (var si = 0; si < spans.length; si++) {
        if (spans[si] !== verb && !spans[si].querySelector("[class*='http-verb']") && !/collapser|ellipsis|arrow/i.test(spans[si].className || "")) {
          var t = normalizeText(spans[si].textContent);
          if (t && /^\//.test(t)) { path = t; break; }
        }
      }
      if (path) {
        var methodLine = document.createElement("p");
        methodLine.innerHTML = "<code>" + normalizeText(verb.textContent).toUpperCase() + " " + path + "</code>";
        btn.replaceWith(methodLine);
      }
    });
    clone.querySelectorAll("script, style, noscript, template, iframe, form, button, input, aside, nav, footer").forEach(function(el) {
      el.remove();
    });
    cleanupCookieChrome(clone);
    clone.querySelectorAll("a").forEach(function(el) {
      var href = el.getAttribute("href");
      if (href) el.setAttribute("href", absoluteUrl(href));
    });
    clone.querySelectorAll("img").forEach(function(el) {
      var src = el.getAttribute("src");
      var lazySrc = el.getAttribute("data-lazy-src") || el.getAttribute("data-src") || el.getAttribute("data-original") || el.getAttribute("data-lazy");
      // Prefer lazy-load attribute when src is a placeholder (data URI or empty)
      if (lazySrc && (!src || /^data:image\//i.test(src))) src = lazySrc;
      if (!src) src = lazySrc;
      if (src) el.setAttribute("src", absoluteUrl(src));
    });
    return clone;
  }

  function pageReadableText() {
    if (!document.body) return "";

    var clone = safeDeepClone(document.body, document);
    clone.querySelectorAll("script, style, noscript, template, iframe").forEach(function(el) {
      el.remove();
    });
    cleanupCookieChrome(clone);
    return normalizeText(clone.textContent);
  }

  function homepageRootPath() {
    var path = (location.pathname || "").toLowerCase();
    return path === "" || path === "/" || /^\/(?:index|default|home)(?:\.[a-z0-9]+)?\/?$/i.test(path);
  }

  function rejectedHomepageLeadText(text, href) {
    text = normalizeText(text || "");
    href = href || "";
    if (!text) return true;
    if (text.length > 180) return true;
    if (/^(home|menu|search|sign in|log in|login|register|create account|my account|account|subscribe|newsletter|advertise|contact|about|privacy|terms|cookies?|careers?|help|support|learn more|read more|view all|see all|show more|skip to content|open menu|close|language|english|français|deutsch|español|italiano)$/i.test(text)) return true;
    if (/^(buy|sell|rent|sold|agents?|homes?|condos?|commercial|mortgages?|calculators?|guides?|news|travel|trains?|buses?|flights?|hotels?|cars?|packages?|deals?|offers?|destinations?|routes?|stations?|tickets?|timetables?)$/i.test(text) && text.length < 18) return true;
    if (/\b(?:privacy|terms|cookie|login|signin|sign-in|register|account|newsletter|subscribe|advertise|contact|about)\b/i.test(href)) return true;
    return false;
  }

  function genericHomepageLeadRoot(metadata, options) {
    options = options || {};
    if (!document.body || !homepageRootPath()) return null;
    if (typeof articleLikePath === "function" && articleLikePath()) return null;
    if (document.querySelector("article h1, article [itemprop='articleBody'], [type='application/ld+json']")) {
      var bodyText = normalizeText(document.body.textContent || "");
      if (document.querySelector("article h1") && bodyText.length < 30000) return null;
    }

    var roots = [];
    ["main", "[role='main']", "#main", ".main", "body"].forEach(function(selector) {
      document.querySelectorAll(selector).forEach(function(root) {
        if (roots.indexOf(root) === -1) roots.push(root);
      });
    });

    var best = null;
    var minItems = options.minItems || 5;
    var intentText = normalizeText([
      (metadata && metadata.title) || "",
      (metadata && metadata.siteName) || "",
      document.title || "",
      document.body.textContent || ""
    ].join(" ")).toLowerCase().slice(0, 6000);
    var portalIntent = /\b(find|search|book|compare|deals?|offers?|destinations?|routes?|tickets?|timetables?|trains?|travel|hotels?|homes?|properties|real estate|for sale|for rent|marketplaces?|listings?|latest|top stories|headlines|breaking news)\b/i.test(intentText);

    roots.forEach(function(root) {
      var seen = {};
      var items = [];
      var headings = [];
      var hero = normalizeText(((root.querySelector("h1") || {}).textContent) || "");

      root.querySelectorAll("h2, h3").forEach(function(heading) {
        if (headings.length >= 8) return;
        var text = normalizeText(heading.textContent || "");
        if (text.length >= 6 && text.length <= 90 && !rejectedHomepageLeadText(text, "")) headings.push(text);
      });

      root.querySelectorAll("a[href]").forEach(function(link) {
        if (items.length >= 18) return;
        if (link.closest("header, nav, footer, aside, form, [role='navigation'], [role='banner'], [role='contentinfo']")) return;

        var href = link.getAttribute("href") || "";
        var url = absoluteUrl(href);
        var title = normalizeText(((link.querySelector("h1, h2, h3, h4") || {}).textContent) || link.textContent || link.getAttribute("aria-label") || "");
        if (!url || seen[url] || rejectedHomepageLeadText(title, href)) return;
        if (title.length < 12 && !/[\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}\p{Script=Hangul}]/u.test(title)) return;

        var container = link.closest("article, section, li, [class*='card'], [class*='tile'], [class*='item'], [class*='listing'], [class*='result'], [class*='destination'], [class*='route'], [class*='story']") || link.parentElement;
        var detail = searchItemDetail(container, title);
        if (detail.length > 180) detail = "";

        seen[url] = true;
        items.push({ text: title, url: url, detail: detail });
      });

      var text = normalizeText(root.textContent || "");
      var links = root.querySelectorAll("a[href]").length;
      var cards = root.querySelectorAll("article, section, li, [class*='card'], [class*='tile'], [class*='item'], [class*='listing'], [class*='result'], [class*='destination'], [class*='route'], [class*='story']").length;
      var heroScore = hero && hero.length >= 8 && hero.length <= 120 ? 180 : 0;
      var sectionScore = Math.min(headings.length, 6) * 60;
      var score = items.length * 180 + heroScore + sectionScore + Math.min(cards, 18) * 12 + Math.min(links, 80);

      if (items.length < minItems && !(items.length >= 3 && heroScore && headings.length >= 2)) return;
      if (!portalIntent && !(items.length >= 6 && cards >= 6 && headings.length >= 3)) return;
      if (links < items.length || text.length < 120) return;
      if (!best || score > best.score) {
        best = { root: root, items: items, hero: hero, headings: headings, score: score };
      }
    });

    if (!best) return null;
    if (best.items.length < minItems && (!best.hero || best.headings.length < 2)) return null;
    return best;
  }

  function cookieNoticeText(text) {
    text = normalizeText(text || "").toLowerCase();
    if (!text || text.length > 5000) return false;

    var keywords = /cookie settings|cookie preferences|manage cookie preferences|manage cookies|accept all cookies|reject optional cookies|we use cookies|this website uses cookies|by accepting cookies|allow the use of cookies|privacy choices|privacy preference center|your privacy settings|your privacy choices|manage privacy preferences|manage consent preferences|cookie information|cookie declaration|cookie list|cookies details|list of partners(?: \(vendors\))?|cookies from other companies|essential cookies|personalize advertising|use cookies and similar technologies|before you continue|wish to store and access information|access information on your devices|collect personal data|personalized ads|trusted third party partners|browsing history|device identifiers|cookie declaration last updated|consent id|change your consent|your current state|configurações avançadas de cookies|declaração de cookies|gerenciar cookies|utilizamos cookies|dados pessoais|informazioni sulla vostra privacy|gestisci preferenze consenso|elenco dei cookie|pliki cookie|ustawienia prywatności|polityka prywatności i cookies|datenschutz|cookie-einstellungen|données personnelles|paramètres des cookies|datos personales|configuración de cookies|dati personali|impostazioni dei cookie|preferenze cookie|accetta tutto|クッキー|Cookieプリファレンス|Cookie設定|同意設定|すべて受け入れる|すべて許可|쿠키|동의|모두 허용|全部接受|接受全部|隐私设置|файлы cookie|настройки cookie|принять все|we gebruiken cookies|о вашој приватности|пристанак|колачић|колачиће|подешавања приватности|የእርስዎ ግላዊነት|ግላዊነት|ኩኪ|ኩኪዎች|የኩኪ ቅንብሮች|pro pokračování vyberte|technické cookies|jakou formou vám máme zobrazovat obsah/i;
    if (!keywords.test(text)) return false;

    var hits = text.match(/cookie|cookies|preferences|privacy choices|privacy preference center|your privacy settings|your privacy choices|manage privacy preferences|manage consent preferences|cookie information|cookie declaration|cookie list|cookies details|list of partners|accept all|reject optional|essential cookies|personalize advertising|personal data|browsing history|device identifiers|personalized ads|trusted third party|wish to store|consent id|change your consent|your current state|configurações avançadas de cookies|declaração de cookies|gerenciar cookies|utilizamos cookies|dados pessoais|informazioni sulla vostra privacy|gestisci preferenze consenso|elenco dei cookie|pliki cookie|prywatności|datenschutz|données|datos|dati|クッキー|쿠키|同意|接受|隐私|принять|cookie設定|ግላዊነት|ኩኪ|pokračování|technické cookies/g) || [];
    return hits.length >= 2;
  }

  function legalFooterText(text) {
    text = normalizeText(text || "").toLowerCase();
    if (!text || text.length > 5000) return false;

    var hits = text.match(/copyright|all rights reserved|privacy policy|cookie policy|terms of use|terms and conditions|impressum|link utili|contatti|chi siamo|newsletter|advertising|pubblicit[àa]|manage preferences|cookie settings/g) || [];
    return hits.length >= 2;
  }

  function cookieChromeNode(node) {
    if (!node || node.nodeType !== 1) return false;

    var attrs = normalizeText([
      node.getAttribute("id"),
      node.getAttribute("class"),
      node.getAttribute("aria-label"),
      node.getAttribute("data-testid")
    ].join(" ")).toLowerCase();
    var text = normalizeText(node.textContent || "");
    var vendorContainer = /(onetrust|ot-sdk|\bot-[\w-]*|cookiebot|cybot|cookiedeclaration|cookie-declaration|usercentrics|trustarc|didomi|quantcast|osano|cookieyes|cky-|sourcepoint|sp_message|privacy-center|privacy preference center|cookie information|cookie list|consent preferences)/.test(attrs) ||
      node.getAttribute("data-nosnippet") === "true";

    if (vendorContainer) return true;
    if (!text) return false;
    var attrCookieMatch = /(cookie|consent|privacy|gdpr|ccpa)/.test(attrs);
    if (attrCookieMatch && cookieNoticeText(text)) return true;
    if (attrCookieMatch && text.length > 5000 && /(cookie|cookies|consent|privacy|gdpr|ccpa)/i.test(text.slice(0, 2000))) return true;
    if ((node.matches("[role='dialog'], [aria-modal='true'], dialog") || /position:\s*(fixed|sticky)/i.test(node.getAttribute("style") || "")) && cookieNoticeText(text)) return true;
    if (typeof window !== "undefined" && node.ownerDocument && node.ownerDocument.defaultView) {
      try {
        var computed = node.ownerDocument.defaultView.getComputedStyle(node);
        if (computed && /fixed|sticky/.test(computed.position) && cookieNoticeText(text)) return true;
      } catch (e) {}
    }
    if (cookieNoticeText(text) && text.length < 3000 && node.querySelectorAll("button, a, input[type='button'], input[type='submit']").length >= 1) return true;

    return false;
  }

  function cleanupCookieChrome(root) {
    if (!root || !root.querySelectorAll) return root;

    root.querySelectorAll("[role='dialog'], [aria-modal='true'], dialog, [id*='cookie' i], [class*='cookie' i], [id*='consent' i], [class*='consent' i], [id*='privacy' i], [class*='privacy' i], [id*='onetrust' i], [class*='onetrust' i], [id^='ot-' i], [class*='ot-' i], [id*='gdpr' i], [class*='gdpr' i], [id*='ccpa' i], [class*='ccpa' i], [class*='CookieConsent' i], [id*='CookieConsent' i], [class*='CookieDeclaration' i], [id*='CookieDeclaration' i], [class*='cookiebar' i], [id*='cookiebar' i], [class*='cookie-banner' i], [id*='cookie-banner' i], [class*='cookie-notice' i], [id*='cookie-notice' i], [class*='privacy-center' i], [id*='privacy-center' i], [data-nosnippet='true'], .cc-banner, .cc-window, #CybotCookiebotDialog, .cky-consent-container, #usercentrics-root, .osano-cm-dialog").forEach(function(el) {
      if (cookieChromeNode(el)) el.remove();
    });

    root.querySelectorAll("section, div, aside, form").forEach(function(el) {
      if (cookieChromeNode(el)) el.remove();
    });

    return root;
  }

  function isBadgeNode(node) {
    if (!node) return false;

    var text = normalizeText(node.textContent);
    if (text.length > 200) return false;
    var imgs = node.querySelectorAll("img").length;
    var links = node.querySelectorAll("a").length;
    var altText = normalizeText(Array.prototype.map.call(node.querySelectorAll("img[alt]"), function(img) {
      return img.getAttribute("alt") || "";
    }).join(" ")).toLowerCase();

    return imgs >= 1 && links >= 1 && (text.length <= 24 || /\b(status|badge|build|coverage|workflow|ci)\b/.test(altText));
  }

  function audioFallbackText(text) {
    return /^your browser doesn't support html5 audio$/i.test(normalizeText(text || ""));
  }

  function videoFallbackText(text) {
    var normalized = normalizeText(text || "").toLowerCase();
    return normalized === "video player is loading." || 
           normalized === "play video" || 
           normalized === "playback speed" || 
           /^playback speed \d/.test(normalized) ||
           /^this is a modal window\./.test(normalized) ||
           /^beginning of dialog window\./.test(normalized) ||
           /^end of dialog window\./.test(normalized) ||
           /^current time\s+\d/.test(normalized) ||
           /^remaining time\s/.test(normalized) ||
           /^duration\s/.test(normalized) ||
           /^loaded:\s*\d/.test(normalized) ||
           /^progress:\s*\d/.test(normalized) ||
           /^fullscreen$/i.test(normalized) ||
            /^mute$/i.test(normalized) ||
            /^unmute$/i.test(normalized);
  }

  function playerControlText(text) {
    var normalized = normalizeText(text || "").toLowerCase();
    if (!normalized || normalized.length > 120) return false;

    return /^(play|pause|resume|volume\s+\d+%|rewind\s+\d+\s+seconds|forward\s+\d+\s+seconds|skip\s+(?:back|forward)|chromecast|closed captions|captions|settings|fullscreen|full screen|mute|unmute|next up|up next|current time\s+\d|remaining time\s+|duration\s+|learn more)$/.test(normalized) ||
      /^\d+:\d+$/.test(normalized);
  }

  function meaningfulButtonText(text) {
    var normalized = normalizeText(text || "");
    if (!normalized) return false;
    if (normalized.length < 30 || normalized.length > 320) return false;
    if (cookieNoticeText(normalized) || utilityHeadingText(normalized) || playerControlText(normalized)) return false;
    if (/^(log in|login|sign in|register|create account|get disney\+|accept all|reject all|confirm my choices|manage preferences|save preferences|allow all|more details|cookies details)$/i.test(normalized)) return false;

    return normalized.split(/\s+/).length >= 4;
  }

  function preserveMeaningfulButtons(root) {
    if (!root || !root.querySelectorAll) return root;

    root.querySelectorAll("button, [role='button'], input[type='button'], input[type='submit']").forEach(function(el) {
      var text = normalizeText(el.innerText || el.textContent || el.getAttribute("value") || "");
      if (!meaningfulButtonText(text)) return;

      var replacement = document.createElement("p");
      replacement.textContent = text;
      replacement.setAttribute("data-fetchutil-button-text", "true");
      el.replaceWith(replacement);
    });

    return root;
  }

  function utilityHeadingText(text) {
    return /^(nearby entries|browse nearby words|cited by|related content|more like this|people also viewed|recommended articles?|translation|numerology|citation|word of the day|quiz|discover more|related posts|latest news|trending now|popular posts|most read|you might also like|you may also like|read more|related articles?|leave a reply|cancel reply|about the authors?|#\s*tags|comments?\s*\d*|also read|further reading|see also|more stories|don't miss|privacy preference center|your privacy settings|manage privacy preferences|manage consent preferences|informazioni sulla vostra privacy|gestisci preferenze consenso|elenco dei cookie|list of partners(?: \(vendors\))?|polecane|przeczytaj (też|również)|podobne (artykuły|wpisy)|leia (também|mais)|artigos? relacionados?|também pode gostar|ähnliche (beiträge|artikel)|das könnte sie auch interessieren|weiterlesen|mehr zum thema|artículos? relacionados?|también te puede interesar|te puede interesar|lee también|noticias relacionadas|articles? (connexes?|similaires?|associée?s?)|à lire aussi|sur le même (sujet|thème)|vous aimerez aussi)$/i.test(text || "") ||
      /^more from /i.test(text || "") ||
      /^popular in /i.test(text || "") ||
      /^browse definitions\.net$/i.test(text || "") ||
      // Arabic / Hebrew / Urdu / Persian sidebar headings
      /^(الأكثر قراءة|الأكثر مشاهدة|الأكثر تعليقاً|مقالات ذات صلة|اقرأ أيضاً|أخبار ذات صلة|مواضيع ذات صلة|موضوعات متعلقة|الأكثر تداولاً|قد يهمك|المزيد|تابع القراءة|הנקראים ביותר|כתבות קשורות|פופולרי|נצפה הכי הרבה|הכי נקראים|مزید پڑھیں|سب سے زیادہ پڑھی جانے والی|متعلقہ خبریں|بیشتر بخوانید|محبوب‌ترین|پربازدیدترین)$/i.test(text || "") ||
      // Turkish sidebar headings
      /^(en çok okunan|ilgili haberler|benzer haberler|popüler haberler|çok okunanlar|ilgili içerikler)$/i.test(text || "") ||
      // Thai sidebar headings
      /^(บทความที่เกี่ยวข้อง|อ่านเพิ่มเติม|ข่าวที่เกี่ยวข้อง|ข่าวยอดนิยม|บทความยอดนิยม|อ่านต่อ|เนื้อหาที่เกี่ยวข้อง|แนะนำสำหรับคุณ|ข่าวล่าสุด)$/i.test(text || "") ||
      // Vietnamese sidebar headings
      /^(bài viết liên quan|tin liên quan|đọc thêm|xem thêm|tin tức liên quan|bài viết nổi bật|có thể bạn quan tâm|tin nổi bật|bài viết mới nhất|đọc nhiều nhất)$/i.test(text || "") ||
      // Greek sidebar headings
      /^(σχετικά άρθρα|διαβάστε (επίσης|ακόμη|περισσότερα)|δημοφιλή άρθρα|περισσότερα νέα|τελευταία νέα|δείτε επίσης|μπορεί να σας ενδιαφέρει|σχετικά νέα|τα πιο δημοφιλή)$/i.test(text || "") ||
      // Ukrainian sidebar headings
      /^(схожі (статті|матеріали|новини)|читайте (також|ще)|також читайте|популярні (статті|новини)|останні новини|найпопулярніше|вас (також )?може зацікавити|рекомендуємо|дивіться також)$/i.test(text || "") ||
      // Indonesian sidebar headings
      /^(baca juga|artikel terkait|berita terkait|berita populer|artikel populer|terpopuler|baca selengkapnya|lihat juga|rekomendasi|berita lainnya|pilihan editor)$/i.test(text || "") ||
      // Dutch sidebar headings
      /^(lees ook|gerelateerde (artikelen|berichten)|ook interessant|meer (lezen|artikelen|nieuws)|populair(st)?e? artikelen|aanbevolen|bekijk ook|misschien vind je dit ook leuk|dit vind je misschien ook interessant|meest gelezen)$/i.test(text || "") ||
      // Serbian sidebar headings (Latin + Cyrillic)
      /^(povezani (članci|tekstovi)|pročitajte (još|i|također)|slični (članci|tekstovi)|popularno|najčitanije|preporučujemo|pogledajte (još|i|takođe)|više vesti|повезани (чланци|текстови)|прочитајте (још|и|такође)|слични (чланци|текстови)|популарно|најчитаније|препоручујемо|погледајте (још|и|такође)|више вести)$/i.test(text || "") ||
      // Malay sidebar headings
      /^(baca juga|artikel berkaitan|berita berkaitan|berita popular|artikel popular|terpopular|baca lagi|lihat juga|cadangan|berita lain|pilihan editor|paling dibaca|trending)$/i.test(text || "") ||
      // Portuguese sidebar headings
      /^(leia (também|mais)|artigos? relacionados?|também pode gostar|mais (lidos?|populares?|notícias)|notícias relacionadas|veja (também|mais)|confira também|continue lendo|recomendado|sugestões?|últimas notícias)$/i.test(text || "") ||
      // Czech sidebar headings
      /^(související (články|zprávy)|čtěte (také|dále|více)|mohlo by vás zajímat|doporučujeme|nejčtenější|nejnovější zprávy|další články|přečtěte si (také|též)|více článků)$/i.test(text || "") ||
      // Swedish sidebar headings
      /^(relaterade (artiklar|nyheter)|läs (också|mer|vidare|även)|mest lästa|populärast|senaste (nyheterna|artiklarna)|fler (artiklar|nyheter)|rekommenderat|du kanske också gillar)$/i.test(text || "") ||
      // Danish sidebar headings
      /^(relaterede (artikler|nyheder)|læs (også|mere|videre)|mest læste|populært|seneste (nyheder|artikler)|flere (artikler|nyheder)|anbefalet|det kunne også interessere dig)$/i.test(text || "") ||
      // Filipino/Tagalog sidebar headings
      /^(kaugnay na (mga )?artikulo|basahin (din|rin)|mga kaugnay na balita|pinaka-?popular|pinakabagong balita|iba pang mga artikulo|maaari mo ring gustuhin)$/i.test(text || "") ||
      // Amharic sidebar headings
      /^(ተዛማጅ ዜናዎች|ተጨማሪ ያንብቡ|ተመልከቱ|ተጨማሪ ዜና|በጣም የተነበቡ|ቀጣይ ዜና)$/i.test(text || "") ||
      // Norwegian sidebar headings
      /^(relaterte (artikler|saker|nyheter)|les (også|mer|videre)|mest lest[e]?|populær[te]?|siste nytt|flere (artikler|saker|nyheter)|anbefalt|aktive debatter|se flere meldinger|du vil kanskje også like)$/i.test(text || "") ||
      // Catalan sidebar headings
      /^(articles? relaciona(ts?|des?)|notícies relacionades|llegeix (també|més)|més (llegits?|populars?|notícies)|últimes notícies|també et pot interessar|contingut relacionat|mostra'n més|temes relacionats)$/i.test(text || "") ||
      // Georgian sidebar headings
      /^(დაკავშირებული (სტატიები|ამბები|სიახლეები)|წაიკითხეთ (ასევე|მეტი)|ყველაზე (წაკითხვადი|პოპულარული)|ბოლო ამბები|მეტი (სტატიები|ამბები)|რეკომენდებული|გაიგეთ მეტი)$/i.test(text || "") ||
      // Sinhala sidebar headings
      /^(සම්බන්ධිත (පුවත්|ලිපි)|තවත් කියවන්න|වැඩි විස්තර|උණුසුම් පුවත්|නවතම පුවත්|ජනප්‍රිය (පුවත්|ලිපි)|වැඩි විස්තර කියවන්න)$/i.test(text || "") ||
      // Azerbaijani sidebar headings
      /^(əlaqəli (xəbərlər|məqalələr)|daha çox oxu(?:yun)?|ən çox oxunan(?:lar)?|son xəbərlər|digər (xəbərlər|məqalələr)|tövsiyə olunan|oxşar xəbərlər)$/i.test(text || "") ||
      // Polish sidebar headings
      /^(powiązane (artykuły|wpisy|tematy|wiadomości)|najczęściej czytane|najpopularniejsze|najnowsze (wiadomości|artykuły)|więcej (artykułów|wpisów|wiadomości)|może cię (też )?zainteresować|zobacz (też|również|także)|czytaj (też|również|także)|warto przeczytać|to też warto przeczytać|to może cię zainteresować|ostatnie (wpisy|artykuły)|popularne (wpisy|artykuły|tematy)|komentarze\s*\d*|dodaj komentarz|zostaw komentarz|napisz komentarz)$/i.test(text || "");
  }

  function utilitySectionNode(node) {
    if (!node || node.nodeType !== 1) return false;

    var heading = normalizeText((node.querySelector("h2, h3, h4, h5, h6, strong, b") || {}).textContent || "");
    if (!heading) {
      // Check first text node or first child's text as a fallback
      var firstChild = node.firstElementChild || node;
      var firstText = normalizeText(firstChild.textContent || "");
      // Only use if the first text is short enough to be a heading
      if (firstText.length <= 40) heading = firstText;
    }
    if (!utilityHeadingText(heading)) return false;

    return node.querySelectorAll("a[href], li, tr").length >= 3;
  }
