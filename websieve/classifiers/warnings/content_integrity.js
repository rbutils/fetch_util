  function contentIntegrityWarningReasons(metadata, content, markdown, body, page, combined, title, docsLike,
                                          readableDocsPage, glossaryPage, packagePage, credibleListFeed,
                                          challengeType, interstitialType, clearStructure, compactNonLatinBody,
                                          extractedNotFoundBody, hasPublicContent, substantialContent) {
    var reasons = [];
    if (!challengeType && !interstitialType && content && content.contentType !== "search") {
      var extractedLength = body.length;
      var pageLength = page.length;
      var slugTerms = slugKeywords();
      var hasArticlePath = slugTerms.length >= 2;
      var protothemaArticlePage = hostMatches(/(^|\.)protothema\.gr$/i) && content.contentType === "article" && extractedLength >= 500;

      if (content.contentType === "article" && !content.legalProvision && !readableDocsPage && !glossaryPage && !packagePage) {
        if (!protothemaArticlePage) {
          if (hasArticlePath && extractedLength < 500 && pageLength > 2000) { if (!clearStructure && !compactNonLatinBody) reasons.push("truncated_content"); }
          // Ratio-based truncation: catch moderate truncation where body is 500-1500 chars
          // but represents less than 15% of the full page (e.g. paywall cut-off, lazy-load failure)
          if (hasArticlePath && extractedLength >= 500 && extractedLength < 1500 && pageLength > 3000 && (extractedLength / pageLength) < 0.15 && !clearStructure && !compactNonLatinBody) { reasons.push("truncated_content"); }
          // Broader moderate truncation: body is 1500-3000 chars but represents less than 12%
          // of the full page text -- catches cases where a longer teaser is extracted but the
          // bulk of the article content is missing (common with SPA lazy-load or paywall teasers)
          if (hasArticlePath && extractedLength >= 1500 && extractedLength < 3000 && pageLength > 8000 && (extractedLength / pageLength) < 0.12 && !clearStructure && !compactNonLatinBody) { reasons.push("truncated_content"); }
          if (missingPrimaryContent(metadata, content, markdown, body) && !compactNonLatinBody) { reasons.push("truncated_content"); }
        }
      }

      // General short extraction: substantial page content was lost during extraction
      if (extractedLength < 200 && pageLength > 1000 && !readableDocsPage && !glossaryPage && !packagePage && !clearStructure && !compactNonLatinBody) { reasons.push("short_extraction"); }

      if (content.contentType === "article" && extractedLength >= 200 && extractedLength < 700 && pageLength > 2500 && !readableDocsPage && !glossaryPage && !packagePage && !clearStructure) { var teaserContext = normalizeText([markdown, title, metadata.title, metadata.description].join(" ")); if (!compactNonLatinBody && /\b(?:Published:\s*\d{4}|Duration:\s*P?T|featured video|watch video|learn more)\b/i.test(teaserContext)) { reasons.push("short_extraction"); } }

      if ((content.contentType === "list" || content.contentType === "article") && detailRecordPath(location.pathname || "") && extractedLength < 500 && shortNavOnlyMarkdown(markdown) && !clearStructure) { if (!(content.contentType === "article" && compactNonLatinBody)) reasons.push("short_extraction"); }

      // Nav-only / chrome-only extraction: short markdown dominated by links with little prose
      if (content.contentType === "article" && !readableDocsPage && !glossaryPage && !packagePage && extractedLength >= 200 && extractedLength < 1000 && pageLength > 2000 && !clearStructure) {
        var mdText = normalizeText(markdown || "");
        var linkCount = (mdText.match(/\[([^\]]*)\]\([^)]+\)/g) || []).length;
        var headingCount = (mdText.match(/^#{1,6}\s/gm) || []).length;
        var proseWords = mdText.replace(/\[([^\]]*)\]\([^)]+\)/g, "").replace(/^#{1,6}\s.*$/gm, "").split(/\s+/).filter(function(w) { return w.length >= 3; }).length;
        // Flag if link-dense (more links than prose words) or heading-heavy with few words,
        // but allow compact article shells that still have clear paragraph structure.
        if (!clearStructure && !compactNonLatinBody && ((linkCount >= 3 && proseWords < linkCount * 2) || (headingCount >= 3 && proseWords < 20))) { reasons.push("short_extraction"); }
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
    if (!challengeType && !interstitialType && keywords.length >= 2 && !queryListPage && !docsLike && !courtNumberCasePath(safeDecodeURI(location.pathname || "").toLowerCase()) && !legalCaseContext(title, body)) {
      // Skip slug-keyword mismatch check when extracted body is predominantly non-Latin script
      // (e.g. Devanagari, Bengali, CJK) since URL slugs are typically ASCII transliterations
      var latinChars = (body.match(/[a-zA-Z]/g) || []).length;
      var totalChars = body.replace(/\s/g, "").length;
      var latinRatio = totalChars > 0 ? latinChars / totalChars : 1;
      if (latinRatio > 0.25) {
        // Normalize both slug keywords and content by stripping diacritics so
        // "rzad" matches "rząd", "isbirligi" matches "işbirliği", etc.
        var normalizedCombined = stripDiacritics(combined);
        var overlap = keywords.filter(function(token) {
          return normalizedCombined.indexOf(token) !== -1;
        }).length;
        // Use a stricter threshold (0.25) to catch more mismatches.
        // For slugs with many keywords (5+), require at least 30% overlap to avoid
        // false positives from long descriptive slugs where some words are generic.
        var overlapThreshold = keywords.length >= 5 ? 0.30 : 0.25;
        if ((overlap / keywords.length) < overlapThreshold) {
          // Secondary check: verify slug keywords against title/headline before flagging.
          // Many transliterated slugs match the headline even when body text uses diacritics.
          var normalizedTitle = stripDiacritics(title);
          var titleOverlap = keywords.filter(function(token) {
            return normalizedTitle.indexOf(token) !== -1;
          }).length;
          if ((titleOverlap / keywords.length) < overlapThreshold && !credibleListFeed && !localizedSlugArticleGuard(metadata, content, body, markdown) && !investorArchivePageGuard(metadata, content, body, markdown) && !scientificDatasetRecordUrl(metadata, content, body) && !patentPublicationIdMatchesContent(combined)) {
            reasons.push("url_content_mismatch");
          }
        }
      }
    }

    // Language mismatch: URL or page lang indicates one language, but body content is in another
    if (!challengeType && !interstitialType && body.length > 200 && !courtNumberCasePath(safeDecodeURI(location.pathname || "").toLowerCase()) && !legalCaseContext(title, body)) {
      var expectedLang = urlLanguageHint() || (metadata.language || "").slice(0, 2).toLowerCase();
      if (expectedLang && langStopwords[expectedLang] && !credibleListFeed && !bodyMatchesLanguage(expectedLang, body) && !(expectedLang !== urlLanguageHint() && localizedSlugArticleGuard(metadata, content, body, markdown)) && !investorArchivePageGuard(metadata, content, body, markdown) && !normalizedArticleSlugMatchesTitle(metadata, content)) {
        reasons.push("url_content_mismatch");
      }
    }

    if (content && content.contentType === "search") {
      if ((content.resultCount || 0) < 3) reasons.push("search_results_unusable");
      if (/^aplikacje google$/i.test(title) || /^google apps$/i.test(title)) reasons.push("search_engine_shell_page");
      if (/zawartość została wygenerowana przy użyciu ai|generated with ai|ai-generated/i.test(combined)) reasons.push("search_engine_ai_summary_only");
    }

    // Multi-topic / liveblog warning: page contains multiple stories that can't be isolated
    if (!challengeType && !interstitialType && content && content.contentType !== "search" && content.contentType !== "press_release" && !content.isolatedLiveblogEntry && !docsLike && !packagePage) {
      var formatView = multiTopicExtractionView(content, markdown);
      var formatMarkdown = formatView.markdown || markdown || "";
      var format = detectContentFormat(metadata, content, formatMarkdown);
      var credibleDocsIndex = credibleDocsIndexReferenceList(metadata, content, formatMarkdown, body);
      var shortNewsArticle = !!structuredDataNode(["NewsArticle", "ReportageNewsArticle", "AnalysisNewsArticle", "OpinionNewsArticle"]) && body.length < 1000;
      if (format && !credibleListFeed && !credibleDocsIndex && !(format === "video" && content.hostAware) && !shortNewsArticle && !strongSingleTopicPage(metadata, content, formatMarkdown, body) && !scientificRecordContext(metadata, content, markdown, body) && !legalInstrumentContext(title, body)) reasons.push("multi_topic_page");
    }

    // Paywall partial content: paywall detected and content appears truncated
    if (!challengeType && !interstitialType && content && content.contentType === "article" && !likelyListPath()) {
      var paywall = paywallSignals();
      if (paywall && reasons.indexOf("subscription_interstitial") === -1) {
        var publicArticle = metadata && metadata.isAccessibleForFree === true;
        // Flag if we got some content but it looks incomplete:
        // - Short absolute length (< 5000 chars), OR
        // - Content represents less than 40% of page text (paywall cut articles often have
        //   a teaser paragraph then truncation, while full page has nav/footer text), OR
        // - Longer content (< 12000 chars) but very low ratio (< 0.25) — catches cases where
        //   a substantial teaser is extracted but the full article is much longer (common with
        //   premium publishers like handelsblatt, nzz, luxtimes where teasers can be 5-10K chars)
        var paywallRatio = page.length > 0 ? body.length / page.length : 1;
        if (body.length > 0 && ((!publicArticle && body.length < 5000) || (!publicArticle && body.length < 8000 && paywallRatio < 0.40) || (body.length < 12000 && paywallRatio < 0.25))) {
          reasons.push("paywall_partial_content");
        }
      }
    }

    // Photo gallery / low-text media page detection
    if (!challengeType && !interstitialType && content && content.contentType !== "search" && !docsLike) {
      var galleryPath = /\/(foto|fotos|photos?|gallery|galleries|galerie|galerij|galleria|galeria|fotogalerie|bildergalerie|bildspel|fotogalleri|valokuvat|fotoalbum|fotoreportaz|фото|фотогалерея|φωτογραφίες)\b/i.test(location.pathname || "");
      if (galleryPath && body.length < 800) {
        reasons.push("photo_gallery_page");
      }
    }

    // Stale content detection: flag articles with published dates more than 30 days old
    if (!challengeType && !interstitialType && staleContentApplies(metadata, content, title, body)) {
      var pubTime = normalizeText((content && content.publishedTime) || metadata.publishedTime || "");
      if (pubTime) {
        var pubDate = Date.parse(pubTime);
        if (!isNaN(pubDate)) {
          var ageMs = Date.now() - pubDate;
          var ageDays = ageMs / (1000 * 60 * 60 * 24);
          if (ageDays > 30 && body.length >= 1200 && !clearStructure) {
            reasons.push("stale_content");
          }
        }
      }
    }

    // Syndicated / wire-service repost detection
    if (!challengeType && !interstitialType && content && content.contentType !== "search" && !docsLike) {
      if (syndicatedRepostApplies(title, body, page)) {
        reasons.push("syndicated_repost");
      }
    }

    return reasons;
  }
