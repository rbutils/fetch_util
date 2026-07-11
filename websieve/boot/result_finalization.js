function finalizeExtractResult(content, metadata, pageText, signals, medicalArticle) {
  var byline = sanitizeByline(content.byline || metadata.byline || visibleByline());
  var cleanedHtml = sanitizedHtml(content.html);
  if (content.title) content.title = normalizeText(content.title.replace(/\s*Stay organized with collections\s*Save and categorize content based on your preferences\.?\s*/gi, ""));
  var markdown = cleanupMarkdownNoise(content.markdown || markdownFor(cleanedHtml || content.html));
  var contentText = normalizeText(content.textContent || "");
  var normalizedMarkdown = normalizeText(markdown);
  if (!normalizedMarkdown && contentText.length > 40) markdown = cleanupMarkdownNoise(markdownFor(cleanedHtml) || contentText);
  normalizedMarkdown = normalizeText(markdown);
  if (content.contentType === "list" && referenceTableArticleMarkdown(markdown)) content.contentType = "article";
  if (content.contentType === "article" && !content.secFiling && !content.readerMode && content.html && content.html.length > 50000 && contentText.length >= 1200 && normalizedMarkdown.length < contentText.length * 0.2) {
    markdown = cleanupMarkdownNoise(contentText);
  }
  var originalPrimaryTitle = normalizeText((content.title || metadata.title || "").replace(/\s*Stay organized with collections\s*Save and categorize content based on your preferences\.?\s*/gi, ""));
  var siteTitle = normalizeText(content.siteName || metadata.siteName || "");
  var primaryTitle = originalPrimaryTitle;
  if ((content.contentType === "article" || content.contentType === "medical") && normalizeText(markdown) && siteTitle && primaryTitle.toLowerCase() === siteTitle.toLowerCase()) {
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
  if ((content.contentType === "article" || content.contentType === "medical") && primaryTitle && normalizeText(markdown)) {
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
    } else if (!markdownStartsWithTitle(markdown, primaryTitle)) {
      markdown = "# " + primaryTitle + "\n\n" + markdown;
    }
  }
  markdown = cleanupMarkdownNoise(markdown);
  if (/^(article|podcast)$/i.test(content.contentType || "") && !/\btranscript\b/i.test(markdown)) {
    var transcriptCue = podcastTranscriptMarkdown(document.body || document);
    if (transcriptCue) markdown = cleanupMarkdownNoise([markdown, transcriptCue].filter(Boolean).join("\n\n"));
  }
  if (content.contentType === "article") markdown = financialStatementLinksMarkdown(markdown);
  if (content.contentType === "article" && !medicalArticle && searchResultsListPage(content, markdown)) content = relabelAsListContent(content, { strongList: true });
  if (content.contentType === "article" && !medicalArticle && !content.hostAware && !content.docsLike && !content.legalProvision && markdownIndexListPage(markdown, content)) content = relabelAsListContent(content, { strongList: true });
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
  if (content.spaDataGuard && warnings.indexOf("spa_data_traversal_guard") === -1) warnings.push("spa_data_traversal_guard");
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
  if (warnings.indexOf("meta_login_wall") !== -1 && warnings.indexOf("consent_interstitial") !== -1 && content.contentType !== "social") {
    content.contentType = "interstitial";
    clearSocialFields(content);
  }
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
    paywallState = warnings.indexOf("subscription_interstitial") !== -1 ? "full_block" : "detected";
  }
  if (content.contentType === "interstitial") clearSocialFields(content);
  var socialFields = content.contentType === "social" ? content : {};

  return {
    title: primaryTitle || normalizeText(metadata.title),
    byline: byline,
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
    portalRootEvidence: content.portalRootEvidence || null,
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
    textContent: content.textContent,
    url: location.href
  };
}
