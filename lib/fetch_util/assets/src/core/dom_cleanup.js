  function cleanupAgentRoot(root) {
    cleanupCookieChrome(root);

    // Strip comment sections (WordPress, Disqus, generic)
    root.querySelectorAll("#comments, #respond, .comments-area, .comment-list, .comments-section, #disqus_thread, .disqus-comment-count, [class*='comment-respond'], .wp-block-comments, .post-comments").forEach(function(el) {
      el.remove();
    });

    // Strip related-article containers by class/id patterns
    root.querySelectorAll("[class*='related-posts'], [class*='related_posts'], [id*='related-posts'], [id*='related_posts'], .yarpp-related, [class*='recommended-posts'], [class*='more-stories'], [class*='also-like'], [class*='you-may-also'], .jp-relatedposts, [class*='more-from'], [class*='more_from'], [class*='latest-news'], [class*='latest_news'], [class*='trending'], [class*='popular-posts'], [class*='popular_posts'], [class*='related-articles'], [class*='related_articles'], [id*='related-articles'], [id*='related_articles']").forEach(function(el) {
      el.remove();
    });

    // Strip sections introduced by headings that indicate related/non-article content.
    // Detects h2/h3/h4 whose text matches "Related", "More from this category", etc.
    // and removes the heading plus all following siblings within the same parent.
    stripRelatedSectionsByHeading(root);

    root.querySelectorAll("section, div, aside, form, table, ul").forEach(function(el) {
      if (utilitySectionNode(el)) el.remove();
    });

    stripPromoAdModules(root);

    root.querySelectorAll('a[href^="#"]').forEach(function(el) {
      var text = normalizeText(el.textContent);
      var className = (el.className || "").toString();
      if (!text || /anchor|heading/i.test(className)) el.remove();
      if (/^skip\s+(to\s+)?(main\s+)?/i.test(text)) el.remove();
      // Strip skip-navigation markers in Arabic/Hebrew/RTL: "تخطى" (skip), "דלג" (skip)
      if (/^(تخطى|تجاوز|דלג)\s/i.test(text)) el.remove();
      // Strip skip-navigation in Greek, Ukrainian, Vietnamese, Thai, Indonesian
      if (/^(μετάβαση στο |παράλειψη |перейти до |пропустити |bỏ qua |ข้ามไปยัง|lewati |langsung ke )/i.test(text)) el.remove();
      // Strip skip-navigation in Dutch, Serbian, Malay, Portuguese
      if (/^(ga naar |doorgaan naar |overslaan|spring naar |прескочи |пређи на |langkau |ir para |pular para |saltar )/i.test(text)) el.remove();
      // Strip skip-navigation in Czech, Swedish, Danish, Filipino, Norwegian, Catalan
      if (/^(přejít na |přeskočit |gå til |spring over |hoppa till |gå vidare |pumunta sa |laktawan |hopp over |gå til innhold|anar a |saltar a )/i.test(text)) el.remove();
      // Strip skip-navigation in Polish
      if (/^(przejdź do |pomiń )/i.test(text)) el.remove();
    });

    root.querySelectorAll("a, button").forEach(function(el) {
      var text = normalizeText(el.textContent).toLowerCase();
      if (/^(report this article|\+?\s*follow|sign in|join now|show more|show less|log in|inloggen|iniciar sessão|entrar|prijavi se|пријави се|log masuk|maak een account|criar conta|registreer|cadastre-se|přihlásit se|logga in|log ind|logg inn|inicia sessió|iniciar sessió|giriş yap|შესვლა|පිවිසෙන්න|daxil ol|zaloguj się|zarejestruj się|zaloguj|załóż konto|moje konto|dołącz do nas|zobacz więcej|czytaj więcej|czytaj dalej|pokaż więcej|zwiń|rozwiń)$/.test(text)) el.remove();
    });

    root.querySelectorAll("p, div, span, a, button, li").forEach(function(el) {
      var text = normalizeText(el.textContent).toLowerCase();
      if (/^(skip ad|continue watching|visit advertiser website|go to page|advertisement \d+\/\d+|advertisement|close ad|skip this ad|skip in \d+|ad \d+ of \d+|sponsored|reklama|materiał sponsorowany|materiał promocyjny|materiał partnerski|autopromocja|ad$)/.test(text) && textLength(el) < 80) el.remove();
    });

    root.querySelectorAll("p, div").forEach(function(el) {
      if (isBadgeNode(el)) el.remove();
    });

    root.querySelectorAll("p, div, li, span, strong, button").forEach(function(el) {
      if (audioFallbackText(el.textContent) || videoFallbackText(el.textContent)) el.remove();
    });

    root.querySelectorAll("svg, .octicon").forEach(function(el) {
      el.remove();
    });

    root.querySelectorAll(".anchor, .heading-link, .header-anchor").forEach(function(el) {
      var text = normalizeText(el.textContent);
      if (el.closest("h1, h2, h3, h4, h5, h6") && text.length >= 8) {
        el.replaceWith(document.createTextNode(text));
      } else {
        el.remove();
      }
    });

    root.querySelectorAll("p, div, span, li, td").forEach(function(el) {
      if (looksLikeInlineJS(el.textContent) && !el.querySelector("p, h1, h2, h3, h4, h5, h6, ul, ol, table, blockquote, pre, article")) el.remove();
    });

    root.querySelectorAll("p, div, span, li, td").forEach(function(el) {
      if (looksLikeDebugData(el.textContent) && !el.querySelector("p, h1, h2, h3, h4, h5, h6, ul, ol, table, blockquote, pre, article")) el.remove();
    });

    stripTrackingPixels(root);
    resolveLazyImages(root);
    stripUIWidgets(root);
    stripNavigationLeaks(root);

    return root;
  }

  function sanitizedHtml(html) {
    var root = document.createElement("div");
    root.innerHTML = html;
    cleanupAgentRoot(root);
    return root.innerHTML;
  }

  function looksLikeInlineJS(text) {
    var normalized = normalizeText(text || "");
    if (!normalized || normalized.length > 1200 || normalized.length < 12) return false;
    var jsPatterns = /\b(document\.(body|getElementById|querySelector|createElement|cookie|write)|window\.(location|addEventListener|dataLayer|gtag|ga\()|function\s*\(|var\s+\w+\s*=\s*|\.push\s*\(\s*function|\.classList\.(add|remove|toggle)|\.style\.\w+\s*=|\.innerHTML\s*=|\.setAttribute\s*\(|addEventListener\s*\(|\.insertBefore\s*\(|\.appendChild\s*\(|\.parentNode\s*\.|new\s+(Date|Array|Object|RegExp|Map|Set)\s*\(|typeof\s+\w+\s*[!=]==?\s*|===?\s*['"]undefined['"]|console\.(log|warn|error)|setTimeout\s*\(|setInterval\s*\(|JSON\.(parse|stringify)|Promise\.(resolve|reject|all)|Object\.(keys|values|assign|defineProperty)|Array\.(isArray|from|prototype)|return\s+(true|false|null|void|this)\b|if\s*\([^)]*\)\s*\{|try\s*\{|catch\s*\(\w+\)\s*\{|throw\s+new\s+\w+)/;
    if (!jsPatterns.test(normalized)) return false;
    var jsTokens = normalized.match(/[{};()=]|function\s|var\s|const\s|let\s|return\s|\.push\(|\.call\(|\.apply\(|=>|===?|!==?|&&|\|\|/g) || [];
    return jsTokens.length >= 3;
  }

  function looksLikeDebugData(text) {
    var normalized = normalizeText(text || "");
    if (!normalized || normalized.length < 40) return false;
    return /\bdebug info:|fetchCache\[|\.expirationTime:|cache key:/i.test(normalized);
  }

  function stripTrackingPixels(root) {
    root.querySelectorAll("img").forEach(function(img) {
      var w = parseInt(img.getAttribute("width") || "", 10);
      var h = parseInt(img.getAttribute("height") || "", 10);
      var src = (img.getAttribute("src") || "").toLowerCase();
      if ((w <= 2 && h <= 2) || (w === 0 || h === 0)) { img.remove(); return; }
      if (/\/(pixel|beacon|track|rt)\.(gif|png|jpg)|\/pixel\?|\/beacon\?|1x1\.|spacer\.|transparent\.|blank\.(gif|png)|\/tr\?|\.gif\?.*utm_|__utm\.gif|\/pixel\.php/i.test(src)) img.remove();
      // Strip tiny base64 placeholder images (lazy-load placeholders)
      if (/^data:image\/(svg\+xml|png|gif|jpeg);base64,/.test(src) && src.length < 300) img.remove();
    });
    return root;
  }

  function resolveLazyImages(root) {
    root.querySelectorAll("img").forEach(function(img) {
      var src = img.getAttribute("src");
      var lazySrc = img.getAttribute("data-lazy-src") || img.getAttribute("data-src") || img.getAttribute("data-original") || img.getAttribute("data-lazy");
      if (lazySrc && (!src || /^data:image\//i.test(src))) {
        img.setAttribute("src", absoluteUrl(lazySrc));
      }
    });
    return root;
  }

  function stripUIWidgets(root) {
    root.querySelectorAll("a, button, span, div").forEach(function(el) {
      var text = normalizeText(el.textContent).toLowerCase();
      if (/^(like|dislike|share|save|bookmark|pin it|tweet|follow us|subscribe|view all|show more comments?|load more|report|flag|print|copy link|copy url|edit|delete|reply|retweet|repost|reblog|thanks for your feedback!?)$/.test(text) && textLength(el) < 60) el.remove();
      if (playerControlText(text) && textLength(el) < 80) el.remove();
    });

    // Strip social media join/follow CTAs
    root.querySelectorAll("a, button, div, p, span, li").forEach(function(el) {
      var text = normalizeText(el.textContent).toLowerCase();
      if (textLength(el) > 200) return;
      if (/^(join (?:us )?on (?:telegram|whatsapp|instagram|facebook|youtube|twitter|x|viber)|follow (?:us )?on (?:telegram|whatsapp|instagram|facebook|youtube|twitter|x|viber)|join (?:our )?(?:telegram|whatsapp|viber) (?:group|channel)|download (?:our|the) app|get (?:our|the) app|install (?:our|the) app|डाउनलोड करें|ऐप डाउनलोड|टेलीग्राम|व्हाट्सएप ग्रुप|হোয়াটসঅ্যাপ|টেলিগ্রাম|(?:become|be) a (?:member|subscriber|patron)|subscribe (?:now|today|here)|sign up (?:for|to) (?:our )?(?:newsletter|updates|emails?)|サブスクライブ|구독하기|підписуйтесь на наш|приєднуйтесь до нас|підписатися на телеграм|підписатися на канал|ακολουθήστε μας|εγγραφείτε|ikuti kami di|gabung (?:di )?(?:telegram|whatsapp)|berlangganan|ติดตาม(?:เรา)?(?:ที่|ใน|ได้ที่)|theo dõi chúng tôi|volg ons|schrijf je in|abonneer|meld je aan|пратите нас|пријавите се|претплатите се|pratite nas|prijavite se|pretplatite se|ikut(?:i)? kami|langgan|inscreva-se|siga-nos|assine|sledujte nás|odebírejte|přihlaste se k odběru|připojte se|följ oss|prenumerera|registrera dig|følg os|abonner|tilmeld dig|følg oss|abonner på|meld deg på|registrer deg|subscriu-te|fes-te subscriptor|fes-te'n subscriptor|გამოიწერეთ|შემოგვიერთდით|მოგვყევით|අපව අනුගමනය කරන්න|bizə qoşulun|abunə olun|bizi izləyin|subskrybuj|zasubskrybuj|zapisz się na newsletter|dołącz do nas|obserwuj nas|śledź nas)$/.test(text)) el.remove();
    });

    // Strip app download / subscription promo containers
    root.querySelectorAll("[class*='app-download'], [class*='app_download'], [class*='download-app'], [class*='download_app'], [class*='subscribe-cta'], [class*='subscribe_cta'], [class*='newsletter-signup'], [class*='newsletter_signup'], [class*='push-notification'], [class*='push_notification'], [class*='telegram-cta'], [class*='whatsapp-cta']").forEach(function(el) {
      if (textLength(el) < 300) el.remove();
    });

    // Strip close/dismiss buttons with icon images
    root.querySelectorAll("img").forEach(function(img) {
      var alt = (img.getAttribute("alt") || "").toLowerCase();
      var src = (img.getAttribute("src") || "").toLowerCase();
      if (/^close$/.test(alt) && /(close|cross|dismiss|x-icon)/i.test(src)) img.remove();
    });

    root.querySelectorAll("[class*='share'], [class*='social'], [class*='rating'], [class*='vote'], [class*='like-button'], [class*='dislike'], [data-testid*='share'], [data-testid*='like'], [class*='ad-overlay'], [class*='ad_overlay'], [class*='video-ad'], [class*='adWrapper'], [class*='ad-wrapper'], [class*='ad-container'], [id*='ad-overlay'], [id*='ad_overlay'], [class*='announcement-bar'], [class*='global-alert'], [id*='announcement-bar']").forEach(function(el) {
      var text = normalizeText(el.textContent || "");
      if (text.length < 120 || /covid|coronavirus|shipping|discount/i.test(text)) el.remove();
    });

    // Strip Taboola/Outbrain/other ad network containers
    root.querySelectorAll("[class*='taboola'], [id*='taboola'], [class*='outbrain'], [id*='outbrain'], [data-widget-type*='taboola'], [data-widget-type*='outbrain'], [class*='promoted-content'], [class*='promoted_content'], [id*='promoted-content'], [class*='sponsored-content'], [class*='sponsored_content'], [class*='mgid'], [id*='mgid'], [class*='zergnet'], [id*='zergnet'], [class*='revcontent'], [id*='revcontent']").forEach(function(el) {
      el.remove();
    });

    // Strip comment count badges/links
    root.querySelectorAll("[class*='comment-count'], [class*='comment_count'], [class*='comments-count'], [class*='commentCount'], [class*='komentari'], [data-type='comment-count']").forEach(function(el) {
      if (textLength(el) < 30) el.remove();
    });

    // Strip map tile images and zoom controls
    root.querySelectorAll("img").forEach(function(img) {
      var src = (img.getAttribute("src") || "");
      if (/maps\.wikimedia\.org\/osm|\/osm-intl\/\d+\/|tile\.openstreetmap\.org|maps\.wikimedia\.org\/v4\/marker/i.test(src)) img.remove();
    });
    root.querySelectorAll("a, button, div, span").forEach(function(el) {
      var text = normalizeText(el.textContent).toLowerCase();
      var title = (el.getAttribute("title") || "").toLowerCase();
      if (/^(zoom in|zoom out|show in full screen|layers|leaflet|maplibre)$/.test(text) && textLength(el) < 40) el.remove();
      else if (/^(zoom in|zoom out)$/.test(title) && textLength(el) < 10) el.remove();
    });
    // Strip map container elements (Leaflet, MapLibre, etc.)
    root.querySelectorAll("[class*='leaflet-'], [class*='maplibre-'], [class*='map-container'], [class*='kartographer']").forEach(function(el) {
      // Only strip if it doesn't contain substantial text content
      if (textLength(el) < 200) el.remove();
    });

    return root;
  }

  function stripPromoAdModules(root) {
    root.querySelectorAll("aside, section, div, figure, picture").forEach(function(el) {
      if (el.matches("main, article, [role='main']")) return;
      if (el.querySelector("article, main, [role='main']")) return;

      var text = normalizeText(el.textContent || "");
      var textLower = text.toLowerCase();
      var attrs = [
        el.className || "",
        el.id || "",
        el.getAttribute("data-testid") || "",
        el.getAttribute("data-test") || "",
        el.getAttribute("aria-label") || ""
      ].join(" ").toLowerCase();
      var imageSrcs = Array.prototype.map.call(el.querySelectorAll("img, source"), function(img) {
        return (img.getAttribute("src") || img.getAttribute("srcset") || "").toLowerCase();
      }).join(" ");

      var promoAttrs = /(?:^|[-_\s])(ad|ads|advert|advertisement|promo|promoted|sponsor|sponsored|subscription|subscribe|subscriber|paywall|upsell|marketing|newsletter|cta)(?:[-_\s]|$)/i.test(attrs);
      var promoText = /\b(save\s+\d+%|subscribe\s+(?:now|today)|subscription|subscriber|sign\s+up\s+for|limited\s+time\s+offer|annual\s+subscriptions?|trusted\s+destination\s+for)\b/i.test(textLower);
      var promoMedia = /(?:\/|[-_])(ad|ads|advert|promo|sponsor|sponsored|subscription|subscribe|marketing|upsell)(?:\/|[-_.?]|$)/i.test(imageSrcs);

      if ((promoAttrs || promoMedia) && (text.length < 900 || promoText)) {
        el.remove();
      } else if (promoText && promoMedia && text.length < 1200) {
        el.remove();
      }
    });
  }

  // Pattern for heading text that introduces non-article sections (related articles,
  // category listings, etc.) — multilingual coverage for European news sources.
  var relatedSectionHeadingPattern = /^(related\s*(articles?|stories|news|posts|content)?|more\s*(from|in|stories|articles?|news)|see\s*also|you\s*may\s*(also\s*)?like|recommended|trending|popular|latest\s*news|other\s*news|also\s*read|read\s*more\s*:?|further\s*reading|więcej\s*(z\s*tej\s*kategorii|artykułów|wiadomości|na\s*ten\s*temat)|zobacz\s*również|polecamy|czytaj\s*również|inne\s*wiadomości|повезано|погледајте|сродне\s*вијести|слично|такође\s*прочитајте|още\s*от|виж\s*също|свързани\s*новини|más\s*de|noticias\s*relacionadas|ver\s*también|plus\s*de|à\s*lire\s*aussi|lire\s*aussi|sur\s*le\s*même\s*sujet|mehr\s*aus|lesen\s*sie\s*auch|das\s*könnte\s*sie\s*auch\s*interessieren|altre\s*notizie|leggi\s*anche|ook\s*interessant|lees\s*ook|läs\s*också|relateret|relaterte\s*saker|les\s*også|aiheeseen\s*liittyvät|lue\s*myös|ilgili\s*haberler|daha\s*fazla|saistītie|susijusios\s*naujienos|поврзано|citește\s*și|articole\s*similare|також\s*читайте|схожі\s*новини|σχετικά\s*νέα|διαβάστε\s*επίσης)$/i;

  function stripRelatedSectionsByHeading(root) {
    root.querySelectorAll("h2, h3, h4").forEach(function(heading) {
      var text = normalizeText(heading.textContent || "").trim();
      if (!text || !relatedSectionHeadingPattern.test(text)) return;

      // Check if the heading is inside an article/main — only strip content after it,
      // not the whole container
      var parent = heading.parentElement;
      if (!parent) return;

      // Remove the heading and all following siblings within the same parent
      var toRemove = [];
      var sibling = heading.nextElementSibling;
      while (sibling) {
        // Stop if we hit another heading at the same or higher level (don't over-strip)
        var siblingTag = sibling.tagName;
        if (/^H[1-4]$/.test(siblingTag) && !relatedSectionHeadingPattern.test(normalizeText(sibling.textContent || "").trim())) break;
        toRemove.push(sibling);
        sibling = sibling.nextElementSibling;
      }

      // Only strip if the section after the heading is link-heavy (safety check)
      var totalLinks = 0;
      var totalText = 0;
      toRemove.forEach(function(el) {
        totalLinks += el.querySelectorAll ? el.querySelectorAll("a[href]").length : 0;
        totalText += normalizeText(el.textContent || "").length;
      });
      // Require at least 2 links and either link-dense content or short total text
      if (totalLinks >= 2 && (totalText < 1500 || totalLinks >= 4)) {
        heading.remove();
        toRemove.forEach(function(el) { el.remove(); });
      }
    });
  }

  function stripNavigationLeaks(root) {
    // ARIA roles: navigation, menubar, menu, toolbar, complementary (sidebar), banner (header), contentinfo (footer)
    root.querySelectorAll("[role='navigation'], [role='menubar'], [role='menu'], [role='toolbar'], [role='complementary'], [role='banner'], [role='contentinfo'], [aria-label*='navigation' i], [aria-label*='menu' i], [aria-label*='breadcrumb' i], [aria-label*='sidebar' i]").forEach(function(el) {
      el.remove();
    });

    root.querySelectorAll("header").forEach(function(el) {
      var links = el.querySelectorAll("a[href]").length;
      var text = normalizeText(el.textContent || "");
      if (links >= 4 && text.length < 800) el.remove();
    });

    // Strip generic sidebar/toc/mobile-menu containers by class pattern when link-dense
    root.querySelectorAll("[class*='sidebar'], [class*='side-nav'], [class*='sidenav'], [class*='mobile-menu'], [class*='mobile-nav'], [class*='hamburger-menu'], [class*='toc']").forEach(function(el) {
      var links = el.querySelectorAll("a[href]").length;
      var text = normalizeText(el.textContent || "");
      // Only strip if it has multiple links and no heavy content children
      if (links >= 3 && !el.querySelector("article, main, [role='main'], pre, blockquote, table")) {
        el.remove();
      } else if (links >= 3 && text.length < 1200) {
        // Even with content children, strip if it's small and link-dense
        var words = text.split(/\s+/).length;
        if (words > 0 && (links / words) > 0.3) el.remove();
      }
    });

    root.querySelectorAll("div, section, ul").forEach(function(el) {
      if (el.closest("article, main, [role='main']") && el.matches("article *, main *, [role='main'] *")) return;
      var text = normalizeText(el.textContent || "");
      var links = el.querySelectorAll("a[href]").length;
      var words = text.split(/\s+/).length;
      if (links >= 6 && words > 0 && (links / words) > 0.5 && text.length < 600 && !el.querySelector("article, main, [role='main'], p, h1, h2, h3, blockquote, pre, table")) {
        el.remove();
      }
    });

    return root;
  }
