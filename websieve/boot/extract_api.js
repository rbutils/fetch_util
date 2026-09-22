  var fetchUtilExtractApi = {
    extract: withComposedDomRead(function(options) {
      resetTerminalArticleCollectionMarker();
      mwananchiPrePageTextCleanup();
      var metadata = collectMetadata();
      var ownedSocialPost = socialPostOwnedContent(metadata);
      var focalArticleRoute = articleRouteFocalContent();
      var content;
      var provisionalHomepageContent = null;
      var provisionalHomepageAlternative = null;

      function deferProvisionalHomepage(candidate) {
        if (!candidate || !candidate.provisionalPortal) return candidate;
        provisionalHomepageContent = candidate;
        return null;
      }

      function cachedFocalArticleContent(candidate) {
        return !!(focalArticleRoute && candidate &&
          (candidate.contentType === "article" || candidate.contentType === "medical"));
      }

      function strongArticleContent(candidate, medicalArticle) {
        return cachedFocalArticleContent(candidate) || articleRouteFocalContent(candidate) || medicalArticle ||
          substantialArticleContent(candidate) || strongArticleMetadata(metadata, candidate);
      }

      function genericListMayReplace(candidate) {
        return candidate && !candidate.hostAware && !candidate.docsLike &&
          !cachedFocalArticleContent(candidate) && !articleRouteFocalContent(candidate);
      }

      function emptyListCandidateLosesContent(current, candidate) {
        if (!candidate || candidate.contentType !== "list") return false;
        var candidateText = normalizeText(candidate.markdown || candidate.textContent || "");
        var currentText = normalizeText(current && (current.markdown || current.textContent) || "");
        return !candidateText && !!currentText;
      }

      function indexListCandidateAllowed(candidate) {
        return candidate && candidate.contentType !== "list" && candidate.contentType !== "social" &&
          candidate.contentType !== "medical" && candidate.contentType !== "product" &&
          candidate.contentType !== "recipe" && candidate.contentType !== "property" &&
          candidate.contentType !== "hotel" && candidate.contentType !== "event" &&
          !sportsTypedContent(candidate) && !candidate.hostAware && !candidate.docsLike &&
          !candidate.legalProvision;
      }

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
      if (content && content.contentType === "search") {
        return finalizeExtractResult(content, metadata, pageText, signals, null);
      }
      if (!content) {
        var earlyInterstitialType = interstitialPageType(metadata, pageText);
        var earlyInterstitial = interstitialContent(metadata, pageText, earlyInterstitialType);
        var earlyInterstitialText = normalizeText((document.body && document.body.textContent) || "").toLowerCase();
        var nonEnglishNotFound = /ご利用のページが見つかりません|ページまたはファイルが存在しません|移動または削除されている|urlに誤りがある|urlには.*存在しません/i.test(earlyInterstitialText);
        if (earlyInterstitial && earlyInterstitialType === "not_found" && nonEnglishNotFound) {
          content = earlyInterstitial;
        }
      }
      if (!content) {
        content = recipeStructuredDataContent(metadata);
      }
      if (!content && homepageRootPath()) {
        content = deferProvisionalHomepage(hostAwareContent(metadata, pageText));
      }
      if (!content) {
        var podcastRootContext = normalizeText([
          location.pathname,
          document.title,
          metadata && metadata.title,
          metadata && metadata.siteName
        ].join(" ")).toLowerCase();
        if (/\b(?:podcast|podcasts|episodes?)\b/.test(podcastRootContext)) {
          content = crediblePortalRootListContent(metadata, null);
        }
      }
      if (!content) {
        content = podcastEpisodeContent(metadata);
      }
      if (!content) {
        content = deferProvisionalHomepage(hostAwareContent(metadata, pageText));
      }
      if (!content) {
        content = challengeContent(metadata, pageText, signals);
      }
      if (!content) {
        // For consent walls: try real extraction first. Only use synthetic interstitial
        // content when real extraction is consent-dominated or empty. The Ruby-side
        // consent dismissal already attempts to click "accept" buttons, so by the time
        // JS runs, the actual article may be accessible behind the wall remnants.
        var interstitialType = interstitialPageType(metadata, pageText);
        var interstitial = interstitialContent(metadata, pageText, interstitialType);
        if (interstitial && interstitialType !== "consent_wall") {
          content = interstitial;
        } else if (interstitial && interstitialType === "consent_wall") {
          // Try real extraction — consent wall may have been dismissed
          var realContent = readableOrFallbackContent(options, metadata);
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
        content = readableOrFallbackContent(options, metadata);
      }
      if (provisionalHomepageContent) provisionalHomepageAlternative = content;

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
        var spaContent = nextDataContent();
        if (spaContent) content = spaContent;
      }

      content = applyPropertyListingContent(content, metadata);
      content = applySportsContent(content, metadata);
      content = applyProductPageContent(content, metadata);
      content = applySocialContentType(content, metadata, ownedSocialPost);
      var strongArticle = strongArticleContent(content, false);

      var productList = genericProductListContent(metadata);
      var supportingProductCollection = productList && productList.supportingCollection;
      if (productList && productList.supportingCollection && content && content.contentType === "article" &&
          normalizeText(content.markdown || content.textContent || "").length >= 280) {
        content.supportingProductCollection = true;
        productList = null;
      }
      if (productList && content && content.contentType !== "social" && content.contentType !== "product" && content.contentType !== "property" && content.contentType !== "hotel" && !content.hostAware && !content.docsLike) {
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

      if (content === productList) content = mixedHomepageProductListContent(metadata, productList) || content;

      var jobList = genericJobListContent(metadata);
      if (jobList && genericListMayReplace(content) &&
          (content.contentType === "article" || content.contentType === "list")) {
        content = jobList;
      }

      var eventArticle = content && content.contentType === "article" &&
        (substantialArticleContent(content) || strongArticleMetadata(metadata, content));
      var eventList = genericEventListContent(metadata);
      var strongEventList = strongEventListingPage();
      if (eventList && genericListMayReplace(content) && content.contentType !== "event" &&
          (!eventArticle || strongEventList) && (content.contentType !== "list" || strongEventList)) {
        content = eventList;
      }

       content = applyMedicalContentType(content, metadata);

       var portalRootContent = crediblePortalRootListContent(metadata, content);
       var ownedDetailArticle = portalRootContent && ownedStructuredDetailArticleContent(content, metadata, portalRootContent);
       if (ownedDetailArticle) {
         content = ownedDetailArticle;
       } else if (portalRootContent) {
         content = portalRootContent;
       }

       if (provisionalHomepageContent && provisionalHomepageAlternative) {
          if (emptyListCandidateLosesContent(provisionalHomepageAlternative, provisionalHomepageContent)) {
            content = provisionalHomepageAlternative;
          } else if (!listCandidateLosesArticleMaterial(provisionalHomepageAlternative, provisionalHomepageContent)) {
            content = provisionalHomepageContent;
          } else if (!content || listCandidateLosesArticleMaterial(provisionalHomepageAlternative, content)) {
            content = provisionalHomepageAlternative;
         }
       }

       var medicalArticle = medicalArticlePage(metadata, content);
      strongArticle = strongArticleContent(content, medicalArticle);
      if (content && !content.hostAware && hostMatches(/(^|\.)gitlab\.com$/) && /data-testid=["']blob-viewer-content["']/.test(content.html || "")) {
        content.hostAware = true;
      }
      if (content.contentType === "article" && !content.hostAware && !content.docsLike &&
          !cachedFocalArticleContent(content) && !articleRouteFocalContent(content) &&
          legalFooterText(content.textContent || content.markdown || "")) {
        var footerListFallback = listContent(metadata);
        if (normalizeText(footerListFallback.markdown || "").length >= 400 &&
            !listCandidateLosesArticleMaterial(content, footerListFallback) &&
            !listCandidateLosesArticleListMaterial(content, footerListFallback)) content = footerListFallback;
      }
      if (content.contentType === "article" && !content.docsLike && !content.legalProvision && legalTableOfContentsPage(null, content.textContent || content.markdown || "")) content = relabelAsListContent(content, { strongList: true });
      var indexListCandidate = null;
      var indexListAllowed = indexListCandidateAllowed(content);
      if (indexListAllowed && dominantIndexListPage(content)) {
        indexListCandidate = listContent(metadata);
      } else if (indexListAllowed && isProbablyListPage(content) &&
          (likelyListPath() || (!cachedFocalArticleContent(content) && !articleRouteFocalContent(content))) &&
          !strongArticle) {
        indexListCandidate = listContent(metadata);
      }
      if (indexListCandidate && !emptyListCandidateLosesContent(content, indexListCandidate) &&
          !(supportingProductCollection && content.contentType === "article") &&
          !listCandidateLosesArticleMaterial(content, indexListCandidate) &&
          !selectedArticleHasExplicitDetailOwnership(content, metadata, indexListCandidate)) content = indexListCandidate;
      if ((content.contentType === "article" || content.contentType === "medical") && !content.docsLike && !content.legalProvision && !strongArticle && thinSearchOrCategoryPage(content)) content = relabelAsListContent(content, { strongList: true });
      if (content.contentType === "list" && queryParam("q") && glossaryLikePage(metadata)) {
        var glossaryListFallback = glossaryMetadataContent(metadata);
        if (glossaryListFallback) content = glossaryListFallback;
      }

      var dormantBodyList = dormantBodyRootListContent(content, metadata);
      if (dormantBodyList) content = dormantBodyList;

      var staleOpacityList = staleOpacitySectionListContent(content, metadata);
      if (staleOpacityList) content = staleOpacityList;

       var hiddenMainArticle = hiddenSubstantiveMainContent(content, metadata, pageText);
       var result = finalizeExtractResult(content, metadata, pageText, signals, medicalArticle);
       if (!hiddenMainArticle || result.contentType !== "article") return result;

      hiddenMainArticle.warningReasons = (hiddenMainArticle.warningReasons || []).concat(result.warnings || []);
      var hiddenMainResult = finalizeExtractResult(hiddenMainArticle, metadata, pageText, signals, medicalArticle);
      return hiddenSubstantiveMainFinalResultSafe(result, hiddenMainResult) ? hiddenMainResult : result;
    })
  };

  if (typeof deliverExtractApi === "function") {
    deliverExtractApi(fetchUtilExtractApi);
  } else {
    global.FetchUtilExtract = fetchUtilExtractApi;
  }
