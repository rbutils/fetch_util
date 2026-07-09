  function sanitizeByline(raw) {
    if (!raw) return raw;
    var text = normalizeText(raw);
    if (!text) return null;
    // Reject if byline is a URL (Facebook profile, website, etc.)
    if (/^https?:\/\//i.test(text)) return null;
    // Strip everything after first newline or tab (follower counts, buttons, handles)
    text = text.split(/[\n\t]/)[0];
    text = normalizeText(text);
    // Reject common UI phrases mistakenly captured as byline
    if (/^(devam(ın)?ı okuyun|read more|leer más|weiterlesen|lire la suite|leggi di più|czytaj dalej|tümünü gör|اقرأ المزيد|ادامه مطلب|המשך לקרוא|مزید پڑھیں)$/i.test(text)) return null;
    // Strip trailing follower / tab / button noise: "Author @handle 242 Takipçi Takip Et"
    text = text.replace(/\s*@[\w.-]+.*$/i, "").replace(/\s*\d+\s*(takipçi|followers?|متابع|دنبال‌کننده|עוקבים|فالوور).*$/i, "");
    text = normalizeText(text);
    // Reject if only whitespace or too short
    if (!text || text.length < 2) return null;
    return text;
  }

  function readableOrFallbackContent(options) {
    var content = options && options.reader_mode !== false ? readabilityContent() : null;
    if (content) content = preferFallbackContent(content, fallbackContent());
    if (!content) content = fallbackContent();
    return content;
  }

  function promoteWarningToInterstitial(content, warnings, warning, maxMarkdownLength, markdown) {
    if (warnings.indexOf(warning) === -1) return;
    if (maxMarkdownLength && normalizeText(markdown || content.markdown || content.textContent || "").length >= maxMarkdownLength) return;
    content.contentType = "interstitial";
  }

  function mwananchiPrePageTextCleanup() {
    if (!/(^|\.)mwananchi\.co\.tz$/i.test(location.hostname || "")) return;

    removeAll(document, [
      "#paywall",
      "[data-paywall]",
      "[id*='paywall' i]",
      "[class*='paywall' i]",
      "[class*='subscribe' i]",
      "[class*='premium' i]"
    ].join(", "));

    document.querySelectorAll("script[type='application/ld+json']").forEach(function(script) {
      var text = normalizeText(script.textContent || "");
      if (/\b(?:NewsArticle|Article)\b/.test(text)) script.remove();
    });

    document.querySelectorAll("p, div, span, section, aside, button, a").forEach(function(node) {
      var text = normalizeText(node.textContent || "");
      if (!text || text.length > 420) return;
      if (/^(ndiyo, tafadhali!?|ingia|jisajili ili kuanza safari yako ya kufikia maudhui yetu yanayolipiwa|jiunge nasi leo usikose habari muhimu|pata habari na chambuzi huru, za kina na za uhakika kutoka mwananchi|loading\.\.\.)$/i.test(text)) {
        node.remove();
      }
    });
  }

  global.FetchUtilExtract = {
    extract: function(options) {
      mwananchiPrePageTextCleanup();
      var metadata = collectMetadata();
      var content;

      if (!content) {
        var mediaWiki = mediaWikiContent(metadata);
        if (mediaWiki) {
          content = mediaWiki;
        }
      }

      var pageText = null;
      var signals = null;

      if (!content) {
        pageText = pageReadableText();
        signals = domSignals();
      }

      if (!content && isSearchEnginePage()) {
        content = searchResultsContent(metadata);
      }
      if (!content) {
        var earlyInterstitial = interstitialContent(metadata, pageText);
        var earlyInterstitialType = earlyInterstitial ? interstitialPageType(metadata, pageText) : null;
        var earlyInterstitialText = normalizeText((document.body && document.body.textContent) || "").toLowerCase();
        var nonEnglishNotFound = /ご利用のページが見つかりません|ページまたはファイルが存在しません|移動または削除されている|urlに誤りがある|urlには.*存在しません/i.test(earlyInterstitialText);
        if (earlyInterstitial && earlyInterstitialType === "not_found" && nonEnglishNotFound) {
          content = earlyInterstitial;
        }
      }
      if (!content) {
        content = recipeStructuredDataContent(metadata);
      }
      if (!content) {
        content = podcastEpisodeContent(metadata);
      }
      if (!content) {
        content = hostAwareContent(metadata, pageText);
      }
      if (!content) {
        content = challengeContent(metadata, pageText, signals);
      }
      if (!content) {
        // For consent walls: try real extraction first. Only use synthetic interstitial
        // content when real extraction is consent-dominated or empty. The Ruby-side
        // consent dismissal already attempts to click "accept" buttons, so by the time
        // JS runs, the actual article may be accessible behind the wall remnants.
        var interstitial = interstitialContent(metadata, pageText);
        var interstitialType = interstitial ? interstitialPageType(metadata, pageText) : null;
        if (interstitial && interstitialType !== "consent_wall") {
          content = interstitial;
        } else if (interstitial && interstitialType === "consent_wall") {
          // Try real extraction — consent wall may have been dismissed
          var realContent = readableOrFallbackContent(options);
          var realText = normalizeText((realContent && realContent.markdown) || (realContent && realContent.textContent) || "").toLowerCase();
          // Use real content if it's substantial and not consent-dominated
          if (realContent && realText.length > 500 && !consentWallDominates(realText)) {
            content = realContent;
          } else {
            content = interstitial;
          }
        }
      }
      if (!content) {
        content = glossaryContent(metadata);
      }
      if (!content) {
        content = jobPostingContent(metadata);
      }
      if (!content) {
        content = lodgingContent(metadata);
      }
      if (!content) {
        content = eventContent(metadata);
      }
      if (!content) {
        content = readableOrFallbackContent(options);
      }

      var weatherLikeArticle = content &&
        content.contentType === "article" &&
        content.readerMode &&
        weatherWidgetText(content.textContent || content.markdown || "") &&
        !/(weather|forecast|ve[ðd]ur|vedur|meteo)/i.test((location.pathname || "") + " " + document.title);

      if (weatherLikeArticle) {
        var weatherListFallback = listContent(metadata);
        if (normalizeText(weatherListFallback.markdown || "").length >= 400) {
          content = weatherListFallback;
        }
      }

      // SPA data fallback: if normal extraction produced very little content,
      // try extracting from embedded JSON data (e.g., Next.js __NEXT_DATA__)
      if (spaDataFallbackNeeded(content)) {
        var spaContent = spaDataContent();
        if (spaContent) content = spaContent;
      }

      content = applyPropertyListingContent(content, metadata);
      content = applyProductPageContent(content, metadata);

      var productList = genericProductListContent(metadata);
      if (productList && content && content.contentType !== "product" && content.contentType !== "property" && content.contentType !== "hotel" && !content.hostAware && !content.docsLike) {
        var currentText = normalizeText(content.markdown || content.textContent || "").toLowerCase();
        if (content.contentType !== "list" && (queryOrCategoryPage() || productList.itemCount >= 4 || consentWallDominates(currentText))) {
          content = productList;
        } else if (content.contentType === "list" && queryOrCategoryPage() && productList.itemCount >= 4) {
          content = productList;
        }
      }

      var jobList = genericJobListContent(metadata);
      if (jobList && content && !content.hostAware && !content.docsLike) {
        content = jobList;
      }

      var eventList = genericEventListContent(metadata);
      if (eventList && content && !content.hostAware && !content.docsLike && content.contentType !== "event") {
        content = eventList;
      }

      var strongArticle = substantialArticleContent(content) || strongArticleMetadata(metadata, content);
      if (content && !content.hostAware && hostMatches(/(^|\.)gitlab\.com$/) && /data-testid=["']blob-viewer-content["']/.test(content.html || "")) {
        content.hostAware = true;
      }
      if (content.contentType === "article" && !content.hostAware && !content.docsLike && !articleLikePath() && legalFooterText(content.textContent || content.markdown || "")) {
        var footerListFallback = listContent(metadata);
        if (normalizeText(footerListFallback.markdown || "").length >= 400) content = footerListFallback;
      }
      if (content.contentType === "article" && !content.docsLike && !content.legalProvision && legalTableOfContentsPage(null, content.textContent || content.markdown || "")) content = relabelAsListContent(content);
      if (content.contentType !== "list" && content.contentType !== "product" && content.contentType !== "recipe" && content.contentType !== "property" && content.contentType !== "hotel" && content.contentType !== "event" && !content.hostAware && !content.docsLike && !content.legalProvision && dominantIndexListPage(content)) content = listContent(metadata);
      if (content.contentType !== "list" && content.contentType !== "product" && content.contentType !== "recipe" && content.contentType !== "property" && content.contentType !== "hotel" && content.contentType !== "event" && !content.hostAware && !content.docsLike && !content.legalProvision && isProbablyListPage(content) && (likelyListPath() || !articleLikePath()) && !strongArticle) content = listContent(metadata);
      if (content.contentType === "article" && !content.docsLike && !content.legalProvision && !strongArticle && thinSearchOrCategoryPage(content)) content = relabelAsListContent(content);
      if (content.contentType === "list" && queryParam("q") && glossaryLikePage(metadata)) {
        var glossaryListFallback = glossaryMetadataContent(metadata);
        if (glossaryListFallback) content = glossaryListFallback;
      }

      var cleanedHtml = sanitizedHtml(content.html);
      // Clean known docs-chrome pollution from title
      if (content.title) content.title = normalizeText(content.title.replace(/\s*Stay organized with collections\s*Save and categorize content based on your preferences\.?\s*/gi, ""));
      var markdown = cleanupMarkdownNoise(content.markdown || markdownFor(cleanedHtml || content.html));
      var contentText = normalizeText(content.textContent || "");
      var normalizedMarkdown = normalizeText(markdown);
      if (!normalizedMarkdown && contentText.length > 40) markdown = cleanupMarkdownNoise(markdownFor(cleanedHtml) || contentText);
      normalizedMarkdown = normalizeText(markdown);
      if (content.contentType === "list" && referenceTableArticleMarkdown(markdown)) content.contentType = "article";
      if (content.contentType === "article" && !content.readerMode && content.html && content.html.length > 50000 && contentText.length >= 1200 && normalizedMarkdown.length < contentText.length * 0.2) {
        markdown = cleanupMarkdownNoise(contentText);
      }
      var originalPrimaryTitle = normalizeText((content.title || metadata.title || "").replace(/\s*Stay organized with collections\s*Save and categorize content based on your preferences\.?\s*/gi, ""));
      var siteTitle = normalizeText(content.siteName || metadata.siteName || "");
      var primaryTitle = originalPrimaryTitle;
      if (content.contentType === "article" && normalizeText(markdown) && siteTitle && primaryTitle.toLowerCase() === siteTitle.toLowerCase()) {
        markdown.split("\n").slice(0, 12).some(function(line) {
          var match = normalizeText(line).match(/^#+\s+(.*)/);
          var heading = normalizeText(match && match[1]).replace(/[`*_]/g, "");
          if (heading && heading.length >= 8 && heading.toLowerCase() !== siteTitle.toLowerCase()) {
            primaryTitle = heading;
            return true;
          }
          return false;
        });
      }
      if (content.contentType === "article" && primaryTitle && normalizeText(markdown)) {
        var lines = markdown.split("\n");
        var titleIndex = -1;
        var primaryTitleLower = primaryTitle.toLowerCase();
        var originalPrimaryTitleLower = originalPrimaryTitle.toLowerCase();
        var siteTitleLower = siteTitle.toLowerCase();
        for (var i = 0; i < Math.min(lines.length, 12); i += 1) {
          var normalized = normalizeText(lines[i]).replace(/^#+\s*/, "").replace(/[`*_]/g, "");
          if (normalized && normalizeText(normalized).toLowerCase() === primaryTitleLower) {
            titleIndex = i;
            break;
          }
        }
        // Also look for H1 headings that start with the title but have extra text merged in
        // (e.g., "# Add data to Cloud Firestore This document explains...")
        if (titleIndex < 0) {
          for (var k = 0; k < Math.min(lines.length, 12); k += 1) {
            var lineText = normalizeText(lines[k]);
            var headingMatch = lineText.match(/^(#+)\s+(.*)/);
            if (headingMatch && headingMatch[1] === "#") {
              var headingBody = normalizeText(headingMatch[2]).replace(/[`*_]/g, "");
              if (headingBody.toLowerCase().indexOf(primaryTitleLower) === 0 && headingBody.length > primaryTitle.length + 5) {
                // Split the merged heading: extract title and remaining text
                var remainder = headingBody.substring(primaryTitle.length).trim();
                lines[k] = "# " + primaryTitle;
                if (remainder) lines.splice(k + 1, 0, "", remainder);
                markdown = lines.join("\n");
                titleIndex = k;
                break;
              }
            }
          }
        }
        if (titleIndex > 0) {
          var beforeLines = lines.slice(0, titleIndex);
          var beforeMeaningful = beforeLines.filter(function(line) { return normalizeText(line); });
          var keepBefore = beforeMeaningful.some(function(line) {
            var beforeText = normalizeText(line).replace(/^#+\s*/, "").replace(/[`*_]/g, "");
            if (!beforeText) return false;
            if (/^!\[[^\]]*\]\([^)]*\)$/.test(normalizeText(line))) return false;
            if (beforeText.toLowerCase() === originalPrimaryTitleLower || beforeText.toLowerCase() === siteTitleLower) return false;
            return true;
          });
          var bodyLines = (keepBefore ? beforeLines : []).concat(lines.slice(titleIndex + 1));
          markdown = "# " + primaryTitle + "\n\n" + bodyLines.join("\n").trim();
        } else if (!markdownStartsWithTitle(markdown, primaryTitle)) {
          markdown = "# " + primaryTitle + "\n\n" + markdown;
        }
      }
      markdown = cleanupMarkdownNoise(markdown);
      if (/^(article|podcast)$/i.test(content.contentType || "") && !/\btranscript\b/i.test(markdown)) {
        var transcriptCue = podcastTranscriptMarkdown(document.body || document);
        if (transcriptCue) markdown = cleanupMarkdownNoise([markdown, transcriptCue].filter(Boolean).join("\n\n"));
      }
      if (content.contentType === "article" && searchResultsListPage(content, markdown)) content = relabelAsListContent(content);
      if (content.contentType === "article" && !content.hostAware && !content.docsLike && !content.legalProvision && markdownIndexListPage(markdown, content)) content = relabelAsListContent(content);
      var legalChromeMarkdown = stripLeadingLegalInstitutionalChrome(markdown);
      if (legalChromeMarkdown !== markdown && normalizeText(legalChromeMarkdown).length >= 5000) content.contentType = "article";
      markdown = legalChromeMarkdown;
      if (legalStatuteArticleContent(null, markdown)) {
        if (content.contentType === "list") content.contentType = "article";
      }
      if (content.contentType === "list" && opaqueDetailPath()) {
        var firstMarkdownLine = (markdown.split("\n").map(function(line) { return normalizeText(line).replace(/^#+\s*/, ""); }).filter(Boolean)[0] || "");
        if (firstMarkdownLine.length >= 100 && !/^[-*]\s+\[/.test(firstMarkdownLine)) content.contentType = "article";
      }
      var warnings = suspicionReasons(metadata, content, markdown, pageText, signals);
      var normalizedMarkdownForWarnings = normalizeText(markdown);
      if (notFoundInterstitialEvidence(primaryTitle || metadata.title, normalizedMarkdownForWarnings, { maxTextLength: 1800, checkStructured: true })) {
        if (warnings.indexOf("not_found_interstitial") === -1) warnings.push("not_found_interstitial");
      }
      if (notFoundInterstitialEvidence(primaryTitle || metadata.title, normalizedMarkdownForWarnings, { maxTextLength: 900 }) && warnings.indexOf("not_found_interstitial") === -1) {
        warnings.push("not_found_interstitial");
      }
      var errorContext = normalizeText([primaryTitle, metadata.title, metadata.siteName, location.hostname, location.pathname, markdown].join(" "));
      if (notFoundInterstitialEvidence(primaryTitle || metadata.title, errorContext, { maxTextLength: 2000 }) && /\b(court|courts|case law|caselaw|legal|law|opinion|citation)\b/i.test(errorContext) && warnings.indexOf("not_found_interstitial") === -1) {
        warnings.push("not_found_interstitial");
      }
      promoteWarningToInterstitial(content, warnings, "not_found_interstitial");
      promoteWarningToInterstitial(content, warnings, "consent_interstitial", 500, markdown);
      promoteWarningToInterstitial(content, warnings, "auth_or_login_interstitial", 1200, markdown);
      if (normalizeText(markdown).length < 1200 && /\b(?:service|site|product|platform|application|app)\b/i.test(errorContext) && /\b(?:no longer available|has been retired|have been retired|is retired|was retired|shutdown|shut down|sunset|discontinued)\b/i.test(errorContext) && warnings.indexOf("access_error_interstitial") === -1) {
        warnings.push("access_error_interstitial");
      }
      if (normalizeText(markdown).length < 10 && warnings.indexOf("empty_extraction") === -1) {
        warnings.push("empty_extraction");
      }
      if (normalizeText(markdown).length < 140 && /copyright\b.*\ball rights reserved\b/i.test(normalizeText(markdown)) && warnings.indexOf("empty_extraction") === -1) {
        warnings.push("empty_extraction");
      }
      if (normalizeText(markdown).length < 500 && /(?:^|:\s*)error$/i.test(primaryTitle || metadata.title || "") && warnings.indexOf("access_error_interstitial") === -1) {
        warnings.push("access_error_interstitial");
      }
      var pageTextLength = normalizeText(pageText || "").length;
      var markdownLength = normalizeText(markdown || "").length;
      var completenessRatio = pageTextLength > 0 ? Math.round((markdownLength / pageTextLength) * 100) / 100 : 1.0;
      var contentFormat = detectContentFormat(metadata, content, markdown);
      var paywall = paywallSignals();
      var paywallState = null;
      if (paywall) {
        // "full_block" when subscription_interstitial fires (no usable content)
        // "detected" when paywall detected but some content was extracted
        paywallState = warnings.indexOf("subscription_interstitial") !== -1 ? "full_block" : "detected";
      }

      return {
        title: primaryTitle || normalizeText(metadata.title),
        byline: sanitizeByline(content.byline || metadata.byline),
        excerpt: content.excerpt || metadata.excerpt,
        siteName: content.siteName || metadata.siteName,
        publishedTime: content.publishedTime || metadata.publishedTime,
        canonicalUrl: metadata.canonicalUrl,
        language: metadata.language,
        name: content.name || null,
        company: content.company || null,
        location: content.location || null,
        description: content.description || null,
        bedrooms: content.bedrooms === undefined ? null : content.bedrooms,
        bathrooms: content.bathrooms === undefined ? null : content.bathrooms,
        areaSqft: content.areaSqft === undefined ? null : content.areaSqft,
        html: content.html,
        markdown: markdown,
        readerMode: content.readerMode,
        contentType: content.contentType || "article",
        ingredients: content.ingredients || null,
        instructions: content.instructions || null,
        price: content.price || null,
        rating: content.rating || null,
        address: content.address || null,
        legalProvision: !!content.legalProvision,
        hostAware: !!content.hostAware,
        statusPage: !!content.statusPage,
        suspect: warnings.length > 0,
        warnings: warnings,
        contentCompletenessRatio: completenessRatio,
        contentFormat: contentFormat,
        paywallState: paywallState,
        textContent: content.textContent,
        url: location.href
      };
    }
  };
