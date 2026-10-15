  var fetchUtilExtractApi = {
    extract: withComposedDomRead(function(options) {
      resetTerminalArticleCollectionMarker();
      var preparedPage = metadataWithPreparedStandaloneManual();
      var metadata = preparedPage.metadata;
      var ownedSocialPost = socialPostOwnedContent(metadata);
      var ownedPrimary = ownedSocialPost && ownedSocialPost.sourceOwnedPublishedFeed ? null : sourceOwnedPrimaryContent(metadata, preparedPage.manual);
      if ((ownedSocialPost && ownedSocialPost.sourceOwnedPublishedFeed) || ownedPrimary) {
        return finalizeExtractResult(ownedPrimary || ownedSocialPost, metadata, pageReadableText(), null, null);
      }
      var focalArticleRoute = articleRouteFocalContent();
      var focalArticleRouteOwner = focalArticleRoute ? articleRouteFocalContent(null, true) : null;
      var articleBodyCollection = independentArticleBodyCollection();
      var content;
      var selectedFocalArticleOwner = null;
      var provisionalHomepageContent = null;
      var provisionalHomepageAlternative = null;

      function deferProvisionalHomepage(candidate) {
        if (!candidate || !candidate.provisionalPortal) return candidate;
        provisionalHomepageContent = candidate;
        return null;
      }

      function cachedFocalArticleContent(candidate) {
        return !!(candidate && (candidate.focalPermalinkContent || focalArticleRoute) &&
          (candidate.contentType === "article" || candidate.contentType === "medical"));
      }

      function strongArticleContent(candidate, medicalArticle) {
        if (candidate && candidate.sourceOwnedMediaArticle) return true;
        if (articleBodyCollection && !cachedFocalArticleContent(candidate) && !articleRouteFocalContent(candidate)) return false;
        return cachedFocalArticleContent(candidate) || articleRouteFocalContent(candidate) || medicalArticle ||
          substantialArticleContent(candidate) || strongArticleMetadata(metadata, candidate);
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
        content = deferProvisionalHomepage(ownedPageContent(metadata, pageText));
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
        content = deferProvisionalHomepage(ownedPageContent(metadata, pageText));
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
          var realContent = genericFocalArticleContent(metadata) || readableOrFallbackContent(options, metadata);
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
        content = genericFocalArticleContent(metadata) || readableOrFallbackContent(options, metadata);
      }
      if (content && (content.sourceOwnedProduct === true || content.sourceOwnedHomepagePeerTables === true)) {
        return finalizeExtractResult(content, metadata, pageText, signals, null);
      }
      if (content && content.contentType === "article" && !content.hostAware && !content.docsLike) {
        sourceOwnedSearchHistoryContent(metadata, content);
      }
      if (content && content.sourceOwnedSearchHistoryArticleVeto) {
        return finalizeExtractResult(content, metadata, pageText, signals, null);
      }
      if (provisionalHomepageContent) provisionalHomepageAlternative = content;
      selectedFocalArticleOwner = articleRouteFocalContent(content, true) || focalArticleRouteOwner || null;
      content = sourceOwnedPrimaryArticleMaterial(content, metadata);

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
      content = prepareSourceOwnedBrowseIndex(content, metadata);
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
        if (productListLosesArticleMaterial(content, productList, strongArticle, commerceLikePage, metadata)) {
          productList = null;
        } else if (content.contentType !== "list" && (commerceLikePage || productList.itemCount >= 4 || consentWallDominates(currentText))) {
          content = productList;
        } else if (content.contentType === "list" && queryOrCategoryPage() && productList.itemCount >= 4) {
          content = productList;
        }
      }

      if (content === productList) content = mixedHomepageProductListContent(metadata, productList) || content;

      var jobList = genericJobListContent(metadata);
      if (jobList && genericListMayReplace(content, focalArticleRoute) &&
          (content.contentType === "article" || content.contentType === "list")) {
        content = jobList;
      }

      var eventArticle = content && content.contentType === "article" &&
        (content.sourceOwnedMediaArticle || substantialArticleContent(content) || strongArticleMetadata(metadata, content));
      var eventList = genericEventListContent(metadata);
      var strongEventList = strongEventListingPage();
      if (eventList && genericListMayReplace(content, focalArticleRoute) && content.contentType !== "event" &&
          (!eventArticle || strongEventList) && (content.contentType !== "list" || strongEventList)) {
        content = eventList;
      }

        content = applyMedicalContentType(content, metadata);

        var materialResultsOwner = visibleMaterialResultsOwner(content, metadata, selectedFocalArticleOwner);
        var materialResultsReaderOwner = !!(materialResultsOwner && materialResultsOwner.complete) &&
          materialResultsReaderContentOwnedByQuery(materialResultsOwner, content, metadata);
        var institutionalCaseIndex = institutionalCaseRecordListPage(document.body, null, true, true);
        var repeatedCollectionAssessment = institutionalCaseIndex && !institutionalCaseIndex.focalArticle ? null : repeatedRecordAssessmentForContent(content, selectedFocalArticleOwner);
        var listArticleOwnershipConflict = !!(institutionalCaseIndex && institutionalCaseIndex.focalArticle) ||
          !!(repeatedCollectionAssessment && repeatedCollectionAssessment.articleOwnershipConflict && !materialResultsReaderOwner);
        var repeatedCollection = repeatedCollectionAssessment &&
          !repeatedCollectionAssessment.articleOwnershipConflict ? repeatedCollectionAssessment : null;
          var repeatedListCandidate = repeatedRecordListCandidate(content, metadata, repeatedCollection);
          if (!materialResultsOwner && repeatedListCandidate && !sourceMaterialBlocksListCandidate(content, repeatedListCandidate, metadata)) content = repeatedListCandidate;
        var portalRootContent = content && !materialResultsOwner && !listArticleOwnershipConflict && !repeatedCollectionAssessment && !content.browseIndexContent ?
         crediblePortalRootListContent(metadata, content) : null;
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
       if (content.contentType === "article" && !materialResultsOwner && !content.browseIndexContent && !content.hostAware && !content.docsLike &&
          !cachedFocalArticleContent(content) && !articleRouteFocalContent(content) && !listArticleOwnershipConflict &&
          legalFooterText(content.textContent || content.markdown || "")) {
        var footerListFallback = listContent(metadata);
        if (normalizeText(footerListFallback.markdown || "").length >= 400 &&
            !listCandidateLosesArticleMaterial(content, footerListFallback) &&
            !listCandidateLosesArticleListMaterial(content, footerListFallback)) content = footerListFallback;
      }
       if (content.contentType === "article" && !materialResultsOwner && !content.docsLike && !content.legalProvision &&
          !listArticleOwnershipConflict && legalTableOfContentsPage(null, content.textContent || content.markdown || "")) {
        content = relabelAsListContent(content, { strongList: true });
      }
        var materialResultsListSelection = selectIndexListCandidate(content, metadata, {
        repeatedCollection: repeatedCollection,
        materialResultsOwner: materialResultsOwner,
        institutionalCaseIndex: institutionalCaseIndex,
        listArticleOwnershipConflict: listArticleOwnershipConflict,
        supportingProductCollection: supportingProductCollection,
        strongArticle: strongArticle,
        articleBodyCollection: articleBodyCollection,
        focalArticleRoute: focalArticleRoute
        });
        content = materialResultsListSelection.content;
      if (materialResultsOwner && !materialResultsListSelection.materialResultsCandidateAccepted && content) {
        content.materialResultsOwnerCandidateRejected = true;
      }
      if (!materialResultsOwner && (content.contentType === "article" || content.contentType === "medical") && !content.docsLike &&
          !content.legalProvision && !strongArticle && !listArticleOwnershipConflict && thinSearchOrCategoryPage(content)) {
        content = relabelAsListContent(content, { strongList: true });
      }
      if (!materialResultsOwner && content.contentType === "list" && queryParam("q") && glossaryLikePage(metadata)) {
        var glossaryListFallback = glossaryMetadataContent(metadata);
        if (glossaryListFallback) content = glossaryListFallback;
      }

      var dormantBodyList = materialResultsOwner || listArticleOwnershipConflict ? null : dormantBodyRootListContent(content, metadata);
      if (dormantBodyList) content = dormantBodyList;

      var staleOpacityList = materialResultsOwner || listArticleOwnershipConflict ? null : staleOpacitySectionListContent(content, metadata);
      if (staleOpacityList) content = staleOpacityList;

      if (content && !content.hostAware && !content.docsLike &&
          (content.contentType === "article" || content.contentType === "list")) {
        content = sourceOwnedSearchHistoryContent(metadata, content) || content;
      }
      if (content && content.sourceOwnedSearchHistoryArticleVeto) {
        return finalizeExtractResult(content, metadata, pageText, signals, medicalArticle);
      }
      var hiddenMainArticle = hiddenSubstantiveMainContent(content, metadata, pageText);
       var result = finalizeExtractResult(content, metadata, pageText, signals, medicalArticle);
       if (!hiddenMainArticle || result.contentType !== "article") return result;

      hiddenMainArticle.warningReasons = (hiddenMainArticle.warningReasons || []).concat(result.warnings || []);
      var hiddenMainResult = finalizeExtractResult(hiddenMainArticle, metadata, pageText, signals, medicalArticle);
      return hiddenSubstantiveMainFinalResultSafe(result, hiddenMainResult) ? hiddenMainResult : result;
    })
  };
