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

  global.FetchUtilExtract = {
    extract: function(options) {
      var metadata = collectMetadata();
      var pageText = pageReadableText();
      var signals = domSignals();
      var content;

      if (isSearchEnginePage()) content = searchResultsContent(metadata);
      if (!content) content = hostAwareContent(metadata, pageText);
      if (!content) content = challengeContent(metadata, pageText, signals);
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
      if (!content) content = glossaryContent(metadata);
      if (!content) content = recipeStructuredDataContent(metadata);
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

      var productList = genericProductListContent(metadata);
      if (productList && content && content.contentType !== "list") {
        var currentText = normalizeText(content.markdown || content.textContent || "").toLowerCase();
        if (queryParam("q") || queryParam("k") || /\/(search|category|collections?|fragrances)\b/.test(location.pathname) || consentWallDominates(currentText)) {
          content = productList;
        }
      }

      var strongArticle = substantialArticleContent(content) || strongArticleMetadata(metadata, content);
      if (content.contentType === "article" && !content.hostAware && !content.docsLike && !articleLikePath() && legalFooterText(content.textContent || content.markdown || "")) {
        var footerListFallback = listContent(metadata);
        if (normalizeText(footerListFallback.markdown || "").length >= 400) content = footerListFallback;
      }
      if (content.contentType !== "list" && !content.hostAware && !content.docsLike && isProbablyListPage(content) && (likelyListPath() || !articleLikePath()) && !strongArticle) content = listContent(metadata);
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
      if (content.contentType === "article" && !content.readerMode && content.html && content.html.length > 50000 && contentText.length >= 1200 && normalizedMarkdown.length < contentText.length * 0.2) {
        markdown = cleanupMarkdownNoise(contentText);
      }
      var primaryTitle = normalizeText((content.title || metadata.title || "").replace(/\s*Stay organized with collections\s*Save and categorize content based on your preferences\.?\s*/gi, ""));
      if (content.contentType === "article" && primaryTitle && normalizeText(markdown)) {
        var lines = markdown.split("\n");
        var titleIndex = -1;
        var primaryTitleLower = primaryTitle.toLowerCase();
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
          var keepBefore = beforeMeaningful.some(function(line) { return !/^!\[[^\]]*\]\([^)]*\)$/.test(normalizeText(line)); });
          var bodyLines = (keepBefore ? beforeLines : []).concat(lines.slice(titleIndex + 1));
          markdown = "# " + primaryTitle + "\n\n" + bodyLines.join("\n").trim();
        } else if (!markdownStartsWithTitle(markdown, primaryTitle)) {
          markdown = "# " + primaryTitle + "\n\n" + markdown;
        }
      }
      markdown = cleanupMarkdownNoise(markdown);
      var warnings = suspicionReasons(metadata, content, markdown, pageText, signals);
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
        html: content.html,
        markdown: markdown,
        readerMode: content.readerMode,
        contentType: content.contentType || "article",
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
