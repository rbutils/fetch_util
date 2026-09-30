function sourceOwnedArticleTitleResolution(content, metadata, cleanedHtml, markdown, originalPrimaryTitle, siteTitle) {
  var primaryTitle = originalPrimaryTitle;
  var identityResolved = false;
  if ((content.contentType === "article" || content.contentType === "medical") && content.sourceOwnedLiveblog !== true) {
    var declaredDescriptionTitle = articleTitleFromDeclaredDescription(cleanedHtml, primaryTitle, siteTitle, metadata.excerpt);
    if (declaredDescriptionTitle !== primaryTitle) {
      primaryTitle = declaredDescriptionTitle;
      identityResolved = true;
    }
  }
  if ((content.contentType === "article" || content.contentType === "medical") &&
      content.sourceOwnedTitleIdentityUnproven === true && content.sourceOwnedFocalArticle === true && content.sourceOwnedLiveblog !== true) {
    var selectedHeadingTitle = articleTitleFromVisibleArticleHeading(cleanedHtml, primaryTitle);
    if (selectedHeadingTitle === normalizeText(content.sourceOwnedHeadingTitle || "") && selectedHeadingTitle !== primaryTitle) {
      primaryTitle = selectedHeadingTitle;
      identityResolved = true;
    }
  }
  if ((content.contentType === "article" || content.contentType === "medical") &&
      (content.sourceOwnedTitleIdentityUnproven !== true || identityResolved) && content.sourceOwnedLiveblog !== true) {
    primaryTitle = articleTitleFromOwnedHeading(cleanedHtml, primaryTitle, siteTitle);
    primaryTitle = articleTitleFromVisibleArticleHeading(cleanedHtml, primaryTitle);
    primaryTitle = articleTitleFromAdjacentHeading(cleanedHtml, primaryTitle);
    primaryTitle = articleTitleFromOwnedExternalHeading(cleanedHtml, primaryTitle, siteTitle);
    primaryTitle = articleTitleFromSelfLinkedHeading(cleanedHtml, primaryTitle);
    if (!content.docsLike && !content.legalProvision) {
      markdown = articleSelfLinkedHeadlineMarkdown(markdown, cleanedHtml, primaryTitle);
    }
    if (primaryTitle !== originalPrimaryTitle) {
      var removedBrandedHeading = false;
      markdown = markdown.replace(/^#{1,6}[ \t]+([^\n]+)\n?/gm, function(line, heading) {
        if (removedBrandedHeading || normalizeText(heading) !== originalPrimaryTitle) return line;
        removedBrandedHeading = true;
        return "";
      });
    }
  }
  return { title: primaryTitle, markdown: markdown, identityResolved: identityResolved };
}
