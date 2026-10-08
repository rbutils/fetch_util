function headedBranchVisibleParagraphs(root) {
  return Array.from(root.querySelectorAll("p, blockquote")).filter(function(node) {
    return !elementSubtreeHidden(node) && !sourceOwnershipInChrome(node) &&
      !node.closest(VISIBLE_COMMENT_THREAD_SELECTOR) && !!normalizeText(node.textContent || "");
  });
}

function headedBranchDateBeforeProse(root, heading, firstParagraph) {
  return Array.from(root.querySelectorAll("time, div, span")).some(function(node) {
    if (node.children.length || elementVisuallyHidden(node) || sourceOwnershipInChrome(node)) return false;
    if (!(heading.compareDocumentPosition(node) & Node.DOCUMENT_POSITION_FOLLOWING) ||
        !(node.compareDocumentPosition(firstParagraph) & Node.DOCUMENT_POSITION_FOLLOWING)) return false;
    return visiblePublicationDateLike(node.getAttribute("datetime") || node.textContent || "");
  });
}

function headedBranchTopicContext(node) {
  if (!node || !node.matches("div, section") || elementSubtreeHidden(node) || sourceOwnershipInChrome(node)) return false;
  var heading = node.firstElementChild;
  if (!heading || !heading.matches("h2, h3") ||
      !/^(?:topics?|tags?|keywords?|themen|タグ|注目ワード)$/i.test(normalizeText(heading.textContent || ""))) return false;
  var children = Array.from(node.children);
  var links = children.slice(1);
  if (!links.length || !links.every(function(link) {
    return link.matches("a[href]") && !elementSubtreeHidden(link) &&
      normalizeText(link.textContent || "") && materializedHttpUrl(link.getAttribute("href"));
  })) return false;
  return Array.from(node.childNodes).every(function(child) {
    return child.nodeType !== Node.TEXT_NODE || !normalizeText(child.nodeValue || "");
  });
}

function headedBranchIndependentPanel(node, beforeHeading) {
  if (elementSubtreeHidden(node) || sourceOwnershipInChrome(node)) return true;
  if (!normalizeText(node.textContent || "") && !node.querySelector("img, picture, video, audio, iframe, pre, table")) return true;
  var children = Array.from(node.children);
  if (children.length === 1 && node.matches("div, section")) return headedBranchIndependentPanel(children[0], beforeHeading);
  var heading = children[0];
  if (!heading || !heading.matches("h2, h3, h4") || SOURCE_REFERENCE_HEADING_PATTERN.test(normalizeText(heading.textContent))) return false;
  var label = normalizeText(heading.textContent || "");
  var leadingAlert = beforeHeading && /^(?:just in|breaking news|速報|最新ニュース)$/i.test(label);
  var supplementaryHeading = relatedRecordCollectionHeading(label) ||
    /^(?:(?:latest|recent|local|regional) (?:news|videos)|deep dives?|weather(?: forecast)?(?: and disaster information)?|深掘りコンテンツ|最新・注目の動画|天気予報・防災情報|新着ニュース|各地のニュース)$/i.test(label);
  if (!leadingAlert && !supplementaryHeading) return false;
  var records = children.slice(1);
  if (Array.from(node.childNodes).some(function(child) {
    return child.nodeType === Node.TEXT_NODE && normalizeText(child.nodeValue || "");
  })) return false;
  // After the focal branch, unlinked panels require record-like children;
  // authored sentences, code, media and nested sections decline this path.
  return records.length > 0 && records.every(function(record) {
    if (!record.matches("p, a") || record.querySelector("p, blockquote, pre, code, ul, ol, table, img, picture, video, audio, iframe")) return false;
    var text = normalizeText(record.textContent || "");
    return !!text && (leadingAlert || !/[。.!?…](?:["'”’」』)]*)\s*$/.test(text));
  });
}

function headedBranchOutsideMaterialAccounted(main, root, contexts) {
  for (var branch = root; branch && branch !== main; branch = branch.parentElement) {
    var parent = branch.parentElement;
    if (!parent || !main.contains(parent)) return false;
    if (!Array.from(parent.children).every(function(sibling) {
      var precedes = !!(sibling.compareDocumentPosition(root) & Node.DOCUMENT_POSITION_FOLLOWING);
      return sibling === branch || contexts.indexOf(sibling) !== -1 || headedBranchIndependentPanel(sibling, precedes);
    })) return false;
    if (Array.from(parent.childNodes).some(function(node) {
      return node.nodeType === Node.TEXT_NODE && normalizeText(node.nodeValue || "");
    })) return false;
  }
  return true;
}
