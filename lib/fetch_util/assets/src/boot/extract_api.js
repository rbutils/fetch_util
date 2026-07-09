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
        content = pressReleaseContent(metadata);
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

      if (spaDataFallbackNeeded(content)) {
        var spaContent = spaDataContent();
        if (spaContent) content = spaContent;
      }

      content = applyPropertyListingContent(content, metadata);
      content = applySportsContent(content, metadata);
      content = applyProductPageContent(content, metadata);
      var strongArticle = substantialArticleContent(content) || strongArticleMetadata(metadata, content);

      var productList = genericProductListContent(metadata);
      if (productList && content && content.contentType !== "product" && content.contentType !== "property" && content.contentType !== "hotel" && !content.hostAware && !content.docsLike) {
        var currentText = normalizeText(content.markdown || content.textContent || "").toLowerCase();
        var commerceContext = normalizeText([document.title, location.pathname, location.search, metadata && metadata.siteName].join(" ")).toLowerCase();
        var commerceLikePage = queryOrCategoryPage() || /\b(?:shop|shopping|store|marketplace|catalog|products?|furniture|search results?)\b|\/p\/|\/sb\d*\//.test(commerceContext);
        if (strongArticle && !commerceLikePage) {
          productList = null;
        } else if (content.contentType !== "list" && (commerceLikePage || productList.itemCount >= 4 || consentWallDominates(currentText))) {
          content = productList;
        } else if (content.contentType === "list" && queryOrCategoryPage() && productList.itemCount >= 4) {
          content = productList;
        }
      }

      var jobList = genericJobListContent(metadata);
      if (jobList && content && (content.contentType === "article" || content.contentType === "list") && !content.hostAware && !content.docsLike) {
        content = jobList;
      }

      var eventList = genericEventListContent(metadata);
      if (eventList && content && !content.hostAware && !content.docsLike && content.contentType !== "event") {
        content = eventList;
      }

      content = applyMedicalContentType(content, metadata);

      var medicalArticle = medicalArticlePage(metadata, content);
      var strongArticle = medicalArticle || substantialArticleContent(content) || strongArticleMetadata(metadata, content);
      if (content && !content.hostAware && hostMatches(/(^|\.)gitlab\.com$/) && /data-testid=["']blob-viewer-content["']/.test(content.html || "")) {
        content.hostAware = true;
      }
      if (content.contentType === "article" && !content.hostAware && !content.docsLike && !articleLikePath() && legalFooterText(content.textContent || content.markdown || "")) {
        var footerListFallback = listContent(metadata);
        if (normalizeText(footerListFallback.markdown || "").length >= 400) content = footerListFallback;
      }
      if (content.contentType === "article" && !content.docsLike && !content.legalProvision && legalTableOfContentsPage(null, content.textContent || content.markdown || "")) content = relabelAsListContent(content);
      if (content.contentType !== "list" && content.contentType !== "medical" && content.contentType !== "product" && content.contentType !== "recipe" && content.contentType !== "property" && content.contentType !== "hotel" && content.contentType !== "event" && !sportsTypedContent(content) && !content.hostAware && !content.docsLike && !content.legalProvision && dominantIndexListPage(content)) content = listContent(metadata);
      if (content.contentType !== "list" && content.contentType !== "medical" && content.contentType !== "product" && content.contentType !== "recipe" && content.contentType !== "property" && content.contentType !== "hotel" && content.contentType !== "event" && !sportsTypedContent(content) && !content.hostAware && !content.docsLike && !content.legalProvision && isProbablyListPage(content) && (likelyListPath() || !articleLikePath()) && !strongArticle) content = listContent(metadata);
      if ((content.contentType === "article" || content.contentType === "medical") && !content.docsLike && !content.legalProvision && !strongArticle && thinSearchOrCategoryPage(content)) content = relabelAsListContent(content);
      if (content.contentType === "list" && queryParam("q") && glossaryLikePage(metadata)) {
        var glossaryListFallback = glossaryMetadataContent(metadata);
        if (glossaryListFallback) content = glossaryListFallback;
      }

      return finalizeExtractResult(content, metadata, pageText, signals, medicalArticle);
    }
  };
