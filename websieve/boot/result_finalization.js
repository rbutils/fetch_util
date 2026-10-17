function finalizationWarnings(content, metadata, markdown, pageText, signals, primaryTitle) {
  var warnings = suspicionReasons(metadata, content, markdown, pageText, signals);
  (Array.isArray(content.warningReasons) ? content.warningReasons : []).forEach(function(reason) {
    reason = normalizeText(reason);
    if (reason && warnings.indexOf(reason) === -1) warnings.push(reason);
  });
  if (content.spaDataGuard && warnings.indexOf("spa_data_traversal_guard") === -1) warnings.push("spa_data_traversal_guard");
  var normalizedMarkdown = normalizeText(markdown);
  if (!visibleMaterialResultsOwner(content, metadata) &&
      notFoundInterstitialEvidence(primaryTitle || metadata.title, normalizedMarkdown, { maxTextLength: 1800, checkStructured: true })) {
    if (warnings.indexOf("not_found_interstitial") === -1) warnings.push("not_found_interstitial");
  }
  var errorContext = normalizeText([primaryTitle, metadata.title, metadata.siteName, location.hostname, location.pathname, markdown].join(" "));
  if (notFoundInterstitialEvidence(primaryTitle || metadata.title, errorContext, { maxTextLength: 2000 }) && /\b(court|courts|case law|caselaw|legal|law|opinion|citation)\b/i.test(errorContext) && warnings.indexOf("not_found_interstitial") === -1) {
    warnings.push("not_found_interstitial");
  }
  promoteWarningToInterstitial(content, warnings, "not_found_interstitial");
  promoteWarningToInterstitial(content, warnings, "consent_interstitial", 500, markdown);
  promoteWarningToInterstitial(content, warnings, "auth_or_login_interstitial", 1200, markdown);
  if (warnings.indexOf("meta_login_wall") !== -1 && warnings.indexOf("consent_interstitial") !== -1 && content.contentType !== "social") {
    content.contentType = "interstitial";
    clearSocialFields(content);
  }
  if (normalizedMarkdown.length < 1200 && /\b(?:service|site|product|platform|application|app)\b/i.test(errorContext) && /\b(?:no longer available|has been retired|have been retired|is retired|was retired|shutdown|shut down|sunset|discontinued)\b/i.test(errorContext) && warnings.indexOf("access_error_interstitial") === -1) {
    warnings.push("access_error_interstitial");
  }
  if (normalizedMarkdown.length < 10 && warnings.indexOf("empty_extraction") === -1) {
    warnings.push("empty_extraction");
  }
  if (normalizedMarkdown.length < 140 && /copyright\b.*\ball rights reserved\b/i.test(normalizedMarkdown) && warnings.indexOf("empty_extraction") === -1) {
    warnings.push("empty_extraction");
  }
  if (normalizedMarkdown.length < 500 && /(?:^|:\s*)error$/i.test(primaryTitle || metadata.title || "") && warnings.indexOf("access_error_interstitial") === -1) {
    warnings.push("access_error_interstitial");
  }
  promoteWarningToInterstitial(content, warnings, "access_error_interstitial", 1200, markdown);
  return warnings;
}

function finalizeExtractResult(content, metadata, pageText, signals, medicalArticle) {
  var materialResultsOwnerCandidateRejected = !!(content && content.materialResultsOwnerCandidateRejected);
  // Additional material must not change the preceding root-selection decision.
  content = enrichMainArticleContent(content, metadata);
  content = supplementNotFoundTickerRecords(content, metadata, pageText);
  content = contentWithoutTerminalArticleFurniture(content);
  content = sourceOwnedReaderHeadlineContent(content);
  content = sourceOwnedFigureCaptionContent(content);
  content = sourceOwnedReaderMissingHeadlineContent(content, metadata);
  content = contentsComponentFinalizationHtml(content);
  content = applyMediaOwnedArticleMetadata(content, metadata);
  var contentByline = sanitizeByline(content.byline);
  var sourceOwnedLiveblogParent = content.sourceOwnedLiveblog === true && !content.isolatedLiveblogEntry;
  var sourceOwnedArticlePublication = content.contentType === "article" && content.sourceOwnedArticlePublicationResolved === true;
  var sourceOwnedUnattributedReference = content.sourceOwnedDataRecord === true || content.sourceOwnedNumberedInstrument === true ||
    content.sourceOwnedIndexedPlay === true || content.sourceOwnedDeclaredNewsPortal === true || content.sourceOwnedUnattributedManual === true ||
    content.sourceOwnedDatedReferenceIndex === true || content.sourceOwnedHomepageCollection === true || content.sourceOwnedSoftwareLanding === true ||
    content.sourceOwnedDisclosureCatalog === true;
  var metadataByline = sourceOwnedLiveblogParent || sourceOwnedUnattributedReference ? null : sanitizeByline(metadata.byline);
  var readerParagraphs = content.sourceOwnedReaderBodyParagraphSources;
  var readerAnswerTime = Array.isArray(readerParagraphs) ?
    sourceOwnedReaderAnswerPublicationTime(readerParagraphs, metadata.canonicalUrl, content.title || metadata.title) : null;
  var metadataQuestionAnswerTime = !Array.isArray(readerParagraphs) && metadata.publishedTime &&
    metadata.sourceOwnedQuestionAnswerPublicationTime === metadata.publishedTime ? metadata.publishedTime : null;
  var displayedPublishedTime = sourceOwnedLiveblogParent || sourceOwnedArticlePublication || sourceOwnedUnattributedReference ? content.publishedTime :
    readerAnswerTime || metadataQuestionAnswerTime || visiblePublishedTime(content);
  var visibleBylineRaw = sourceOwnedLiveblogParent || sourceOwnedUnattributedReference ? null : visibleByline();
  var namedAuthorByline = sourceOwnedLiveblogParent || sourceOwnedUnattributedReference ? null : visibleNamedAuthorByline();
  var bylinePublishedTime = [contentByline, metadataByline, visibleBylineRaw].some(function(value) {
    return bylineContainsPublishedTime(value, displayedPublishedTime);
  });
  contentByline = bylineWithoutHostIdentity(
    bylineWithoutPublishedTime(contentByline, displayedPublishedTime, metadataByline),
    namedAuthorByline
  );
  metadataByline = bylineWithoutHostIdentity(
    bylineWithoutPublishedTime(metadataByline, displayedPublishedTime),
    namedAuthorByline
  );
  contentByline = bylineWithoutSiblingActions(contentByline, metadataByline);
  var sourceOwnedByline = sourceOwnedUnattributedReference ? null : readerSourceOwnedBylineForContent(content, metadata, contentByline, metadataByline);
  if (sourceOwnedByline) contentByline = metadataByline = sourceOwnedByline;
  var sourceBylineEligible = content.readerMode || (content.contentType === "article" && content.sourceOwnedFocalArticle);
  var readerAuthor = sourceBylineEligible ? readerBylineSourceAuthorLink(content, metadataByline) : null;
  var readerTextByline = content.readerMode && !readerAuthor ? readerTextBylineSource(content, metadataByline) : null;
  var expandsByline = readerBylineCanExpand(content, readerAuthor);
  if (expandsByline) {
    contentByline = null;
  }
  if (readerAuthor && (expandsByline || !contentByline || contentByline.toLowerCase() === metadataByline.toLowerCase())) {
    content = supplementReaderBylineLink(content, readerAuthor);
  }
  if (readerTextByline) {
    content = supplementReaderTextByline(content, readerTextByline);
    contentByline = null;
  }
  if (content.readerMode && metadataByline && /^\d{1,2}:\d{2}(?:\s*[ap]\.?m\.?)?\b/i.test(contentByline || "")) contentByline = null;
  var visibleBylineValue = bylineWithoutHostIdentity(
    bylineWithoutPublishedTime(visibleBylineRaw, displayedPublishedTime, metadataByline || contentByline),
    namedAuthorByline
  );
  var byline = contentByline || metadataByline || visibleBylineValue;
  var cleanResultMarkdown = resultMarkdownCleanup(content);
  var preserveInlineMailtoUntilFinalType = inlineArticleMailtoMaySurviveUntilFinalType(content);
  var cleanedHtml = content.sourceOwnedUnattributedManual === true && content.sourceOwnedCleanedManualHtml === content.html ?
    content.html : sanitizedHtml(content.html, !!content.focalPublicPreview);
  if (content.title) content.title = normalizeText(content.title.replace(/\s*Stay organized with collections\s*Save and categorize content based on your preferences\.?\s*/gi, ""));
  var markdown = cleanResultMarkdown(content.markdown && !content.focalPublicPreview ? content.markdown :
    markdownFor(cleanedHtml || content.html, !!content.focalPublicPreview, preserveInlineMailtoUntilFinalType));
  var contentText = normalizeText(content.textContent || "");
  var normalizedMarkdown = normalizeText(markdown);
  if (!normalizedMarkdown && contentText.length > 40) {
    markdown = cleanResultMarkdown(markdownFor(cleanedHtml, false, preserveInlineMailtoUntilFinalType) || contentText);
  }
  normalizedMarkdown = normalizeText(markdown);
  if (content.contentType === "list" && content.sourceOwnedHomepagePeerTables !== true &&
      referenceTableArticleMarkdown(markdown)) content.contentType = "article";
  if (content.contentType === "article" && !content.secFiling && !content.readerMode && content.html && content.html.length > 50000 && contentText.length >= 1200 && normalizedMarkdown.length < contentText.length * 0.2) {
    markdown = cleanResultMarkdown(contentText);
  }
  var originalPrimaryTitle = normalizeText((content.title || metadata.title || "").replace(/\s*Stay organized with collections\s*Save and categorize content based on your preferences\.?\s*/gi, ""));
  var siteTitle = normalizeText(content.siteName || metadata.siteName || "");
  var titleResolution = sourceOwnedArticleTitleResolution(content, metadata, cleanedHtml, markdown, originalPrimaryTitle, siteTitle);
  var primaryTitle = titleResolution.title;
  var sourceOwnedTitleIdentityResolved = titleResolution.identityResolved;
  markdown = titleResolution.markdown;
  if ((content.contentType === "article" || content.contentType === "medical") &&
      (content.sourceOwnedTitleIdentityUnproven !== true || sourceOwnedTitleIdentityResolved) && content.sourceOwnedLiveblog !== true && normalizeText(markdown) && siteTitle && primaryTitle.toLowerCase() === siteTitle.toLowerCase()) {
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
  if ((content.contentType === "article" || content.contentType === "medical") &&
      (content.sourceOwnedTitleIdentityUnproven !== true || sourceOwnedTitleIdentityResolved) && primaryTitle && normalizeText(markdown)) {
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
    if (titleIndex < 0) {
      for (var k = 0; k < Math.min(lines.length, 12); k += 1) {
        var lineText = normalizeText(lines[k]);
        var headingMatch = lineText.match(/^(#+)\s+(.*)/);
        if (headingMatch && headingMatch[1] === "#") {
          var headingBody = normalizeText(headingMatch[2]).replace(/[`*_]/g, "");
          if (headingBody.toLowerCase().indexOf(primaryTitleLower) === 0 && headingBody.length > primaryTitle.length + 5) {
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
    } else if (titleIndex === 0 && /^#{2,}\s+/.test(lines[0])) {
      lines[0] = "# " + primaryTitle;
      markdown = lines.join("\n");
    } else if (!markdownStartsWithTitle(markdown, primaryTitle)) {
      markdown = "# " + primaryTitle + "\n\n" + markdown;
    }
  }
  markdown = cleanResultMarkdown(content.sourceOwnedTitleIdentityUnproven === true && !sourceOwnedTitleIdentityResolved ?
    preserveUnprovenSourceTitleExtension(markdown, content.sourceOwnedHeadingTitle, originalPrimaryTitle) : markdown);
  if ((content.contentType === "article" || content.contentType === "medical") &&
      content.sourceOwnedLiveblog !== true && !content.docsLike && !content.legalProvision) {
    markdown = articleSelfLinkedHeadlineMarkdown(markdown, cleanedHtml, primaryTitle);
  }
  if (/^(article|podcast)$/i.test(content.contentType || "") && !/\btranscript\b/i.test(markdown)) {
    var transcriptCue = podcastTranscriptMarkdown(document.body || document);
    if (transcriptCue) markdown = cleanupMarkdownNoise([markdown, transcriptCue].filter(Boolean).join("\n\n"));
  }
  if (content.contentType === "article") markdown = financialStatementLinksMarkdown(markdown);
  var legalChromeMarkdown = content.sourceOwnedGeneratedDocs === true || content.sourceOwnedProduct === true ||
    content.sourceOwnedIndexedPlay === true || content.sourceOwnedDatedReferenceIndex === true || content.sourceOwnedDisclosureCatalog === true ?
    markdown : stripLeadingLegalInstitutionalChrome(markdown);
  var legalChromeRemoved = legalChromeMarkdown !== markdown;
  markdown = materializedMarkdown(legalChromeMarkdown, preserveInlineMailtoUntilFinalType);
  if (content.sourceOwnedLiveblog && content.contentType === "list") content.contentType = "article";
  if (content.contentType === "article" && !materialResultsOwnerCandidateRejected &&
      !content.sourceOwnedLiveblog && !medicalArticle && searchResultsListPage(content, markdown)) {
    content = relabelAsListContent(content, { strongList: true });
  }
  if (content.contentType === "article" && !content.sourceOwnedLiveblog && !medicalArticle && !content.hostAware && !content.docsLike && !content.legalProvision &&
      !materialResultsOwnerCandidateRejected && !content.supportingProductCollection && markdownIndexListPage(markdown, content)) {
    content = relabelAsListContent(content, { strongList: true });
  }
  if (legalChromeRemoved && normalizeText(legalChromeMarkdown).length >= 5000) content.contentType = "article";
  if (!content.sourceOwnedDatedReferenceIndex && !content.sourceOwnedDisclosureCatalog && legalStatuteArticleContent(null, markdown)) {
    if (content.contentType === "list") content.contentType = "article";
  }
  if (content.contentType === "list" && opaqueDetailPath()) {
    var firstMarkdownLine = (markdown.split("\n").map(function(line) { return normalizeText(line).replace(/^#+\s*/, ""); }).filter(Boolean)[0] || "");
    if (firstMarkdownLine.length >= 100 && !/^[-*]\s+\[/.test(firstMarkdownLine)) content.contentType = "article";
  }
  content = applySocialContentType(content, metadata);
  if (content.contentType === "article") markdown = articleCitationResourceMarkdown(content, markdown);
  if (!content.portalRootEvidence) content.portalRootEvidence = sourceOwnedHomepageRecordEvidence(content, markdown);
  var warnings = finalizationWarnings(content, metadata, markdown, pageText, signals, primaryTitle);
  markdown = interstitialRequestedContextMarkdown(content, metadata, markdown, warnings);
  markdown = deferredListFinalizationMarkdown(content, metadata, markdown);
  markdown = contentsComponentFinalizationMarkdown(content, markdown);
  markdown = stripStructuredCardFieldMarkers(markdown);
  markdown = materializedMarkdown(markdown, inlineArticleMailtoAllowed(content));
  content.textContent = stripStructuredCardFieldMarkers(content.textContent);
  var pageTextLength = normalizeText(pageText || "").length;
  var markdownLength = normalizeText(markdown || "").length;
  var completenessRatio = pageTextLength > 0 ? Math.round((markdownLength / pageTextLength) * 100) / 100 : 1.0;
  var contentFormat = detectContentFormat(metadata, content, markdown);
  var paywallState = finalizedPaywallState(content, warnings);
  if (content.contentType === "interstitial") clearSocialFields(content);
  var socialFields = content.contentType === "social" ? content : {};
  byline = listPageByline(byline, metadata, content, markdown);

  var publishedTime = collectionPublishedTime(content, metadata);
  if (content.contentType !== "list" && !byline && bylinePublishedTime) publishedTime = displayedPublishedTime;
  if (content.sourceOwnedProduct === true) publishedTime = content.publishedTime || null;
  if (sourceOwnedUnattributedReference) {
    byline = null;
    publishedTime = null;
  }
  var result = {
    title: primaryTitle || normalizeText(metadata.title),
    byline: byline,
    excerpt: content.excerpt || metadata.excerpt,
    siteName: content.siteName || metadata.siteName,
    publishedTime: normalizeLocalizedPublicationDigits(publishedTime),
    canonicalUrl: metadata.canonicalUrl,
    language: metadata.language,
    name: content.name || null,
    company: content.company || null,
    location: content.location || null,
    description: contentDescriptionForResult(content, metadata),
    bedrooms: content.bedrooms === undefined ? null : content.bedrooms,
    bathrooms: content.bathrooms === undefined ? null : content.bathrooms,
    areaSqft: content.areaSqft === undefined ? null : content.areaSqft,
    html: content.sourceOwnedUnattributedManual === true && typeof content.html === "string" &&
      content.sourceOwnedMaterializedManualHtml === content.html ? content.html :
      materializedHtml(content.html, inlineArticleMailtoAllowed(content)),
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
    portalRootEvidence: content.portalRootEvidence || null,
    sportsDetailEvidence: content.sportsDetailEvidence || null,
    statusPage: !!content.statusPage,
    socialKind: socialFields.socialKind || null,
    platform: socialFields.platform || null,
    handle: socialFields.handle || null,
    replyCount: socialFields.replyCount === undefined ? null : socialFields.replyCount,
    community: socialFields.community || null,
    score: socialFields.score === undefined ? null : socialFields.score,
    suspect: warnings.length > 0,
    warnings: warnings,
    contentCompletenessRatio: completenessRatio,
    contentFormat: contentFormat,
    paywallState: paywallState,
    textContent: credentialFreeHttpText(content.textContent),
    url: credentialFreeHttpUrl(location.href)
  };
  if (content.sourceOwnedLiveblog === true) result.sourceOwnedLiveblog = true;
  Object.keys(result).forEach(function(key) {
    if (key !== "markdown" && key !== "html") result[key] = credentialFreeHttpValue(result[key]);
  });
  return result;
}
