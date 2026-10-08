function sourceOwnedHeadedBranchOwnership(metadata) {
  if (!metadata || homepageRootPath()) return null;
  var headings = Array.from(document.querySelectorAll("h1")).filter(function(heading) {
    return !elementVisuallyHidden(heading) && !sourceOwnershipInChrome(heading);
  });
  if (headings.length !== 1) return null;
  var heading = headings[0];
  var title = normalizeText(heading.textContent || "");
  var pageTitle = normalizeText(metadata.title || "");
  var remainder = pageTitle.slice(title.length);
  if (!title || (articleTitleFromOwnedHeading(heading.outerHTML, pageTitle, metadata.siteName) !== title &&
      !(pageTitle.indexOf(title) === 0 && /^\s*(?:-|–|—|:|：|\|)\s*\S/.test(remainder)))) return null;
  var mains = Array.from(document.querySelectorAll("main, [role~='main' i]")).filter(function(main) {
    return main.contains(heading) && !elementSubtreeHidden(main);
  });
  if (mains.length !== 1 || Array.from(document.querySelectorAll("article")).some(function(article) {
    return !elementSubtreeHidden(article) && !sourceOwnershipInChrome(article) && !commentRecordMarker(article);
  })) return null;
  var main = mains[0];
  var root = heading.parentElement;
  var paragraphs;
  while (root && root !== main) {
    paragraphs = headedBranchVisibleParagraphs(root);
    if (paragraphs.length >= 2) break;
    root = root.parentElement;
  }
  if (!root || root === main || !root.matches("div, section") || !paragraphs ||
      !paragraphs.every(function(paragraph) {
        return !!(heading.compareDocumentPosition(paragraph) & Node.DOCUMENT_POSITION_FOLLOWING);
      }) || !headedBranchDateBeforeProse(root, heading, paragraphs[0])) return null;
  var text = normalizeText(paragraphs.map(function(paragraph) { return paragraph.textContent || ""; }).join(" "));
  if (text.length < 60) return null;
  var contexts = [];
  for (var branch = root; branch && branch !== main; branch = branch.parentElement) {
    if (headedBranchTopicContext(branch.nextElementSibling)) contexts.push(branch.nextElementSibling);
  }
  if (!headedBranchOutsideMaterialAccounted(main, root, contexts)) return null;
  var ownership = {
    node: root,
    ownerRoot: root,
    heading: heading,
    title: title,
    titleIdentityProven: true,
    body: { sourceNode: root, text: text, paragraphs: paragraphs.length },
    contextNodes: contexts,
    terminalProseEllipsis: /(?:…|\.{3})\s*$/.test(text),
    proof: "unique-dated-heading-and-physical-prose-branch"
  };
  return sourceOwnedArticleHasUncoveredMaterial(ownership) ? null : ownership;
}
