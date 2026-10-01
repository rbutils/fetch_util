var TERMINAL_ARTICLE_AUTHORED_CONTEXT_SELECTOR = [
  "blockquote", "q", "li", "td", "th", "figure", "figcaption", "caption", "pre", "code", "form",
  "[role='doc-quote' i]", "[role='note' i]", "[role='main' i]", "[role='article' i]",
  "[role='listitem' i]", "[role='table' i]", "[role='row' i]", "[role='cell' i]",
  "[role='columnheader' i]", "[role='rowheader' i]", "[role='figure' i]", "[role='comment' i]",
  "[itemprop~='comment' i]", "[itemprop~='commentText' i]", ".comments", ".comentarios",
  ".comments-area", ".comment-list", ".comments-section", ".commentlist", ".comment-body",
  ".comment_content", ".comment-form", ".comment-content", ".comment-text", "#comments", "#respond",
  "#disqus_thread", ".disqus-comment-count", "[class*='comment-respond' i]", ".wp-block-comments",
  ".post-comments", "[data-fetchutil-social-comment]"
].join(", ");

function terminalArticleAuthoredContext(node, article) {
  for (var ancestor = node; ancestor && ancestor !== article; ancestor = ancestor.parentElement) {
    if (ancestor.matches && ancestor.matches(TERMINAL_ARTICLE_AUTHORED_CONTEXT_SELECTOR)) return true;
  }
  return false;
}

function terminalArticleFurnitureOwner(selectedRoot, sourceClones) {
  if (!selectedRoot || !sourceClones || typeof sourceClones.get !== "function") return null;
  var sourceArticle = relatedRailSourceArticle();
  if (!sourceArticle) return null;

  var mappedArticle = sourceClones.get(sourceArticle);
  var selectedArticle = mappedArticle && selectedRoot.contains(mappedArticle) ? mappedArticle :
    (selectedRoot.matches && selectedRoot.matches("article") ? selectedRoot : selectedRoot.querySelector("article"));
  if (!selectedArticle || (mappedArticle && mappedArticle !== selectedArticle) ||
      !relatedRailRootOwnsArticle(selectedArticle)) return null;

  return { source: sourceArticle, selected: selectedArticle, sourceClones: sourceClones };
}

function stripSourceOwnedTerminalArticleFurniture(selectedRoot, sourceClones) {
  var owner = terminalArticleFurnitureOwner(selectedRoot, sourceClones);
  if (!owner) return selectedRoot;

  stripSourceOwnedInlineRelatedRecords(owner);
  stripSourceOwnedRecirculationRail(owner);
  stripSourceOwnedTerminalRelatedStoryLeaves(owner);
  return selectedRoot;
}

function stripSourceOwnedInlineRelatedRecords(owner) {
  var headings = Array.from(owner.source.querySelectorAll("h2, h3, h4")).filter(function(heading) {
    return !elementVisuallyHidden(heading) && heading.closest("article") === owner.source &&
      !terminalArticleAuthoredContext(heading, owner.source) &&
      relatedRecordCollectionHeading(heading.textContent || "");
  });

  headings.forEach(function(heading) {
    var list = terminalArticleNextSignificantSibling(heading);
    if (!list || !list.matches("ul, ol") || list.closest("article") !== owner.source) return;
    if (terminalArticleAuthoredContext(list, owner.source)) return;
    var sourceGroup = document.createElement("div");
    sourceGroup.appendChild(heading.cloneNode(true));
    sourceGroup.appendChild(list.cloneNode(true));
    if (!relatedHeadingRecordRail(sourceGroup)) return;

    var headingClone = terminalArticleMappedClone(heading, owner);
    var listClone = terminalArticleMappedClone(list, owner);
    if (!headingClone || !listClone || headingClone.parentElement !== listClone.parentElement ||
        terminalArticleNextSignificantSibling(headingClone) !== listClone ||
        terminalArticleAuthoredContext(headingClone, owner.selected) ||
        terminalArticleAuthoredContext(listClone, owner.selected)) return;

    var selectedGroup = document.createElement("div");
    selectedGroup.appendChild(headingClone.cloneNode(true));
    selectedGroup.appendChild(listClone.cloneNode(true));
    if (!relatedHeadingRecordRail(selectedGroup)) return;
    headingClone.remove();
    listClone.remove();
  });
}

function stripSourceOwnedRecirculationRail(owner) {
  var candidates = Array.from(owner.source.querySelectorAll("p")).filter(function(node) {
    return node.closest("article") === owner.source && !elementSubtreeHidden(node) &&
      !terminalArticleAuthoredContext(node, owner.source) &&
      terminalArticleRecirculationRole(node) && !node.children.length && normalizeText(node.textContent || "");
  });

  candidates.forEach(function(role) {
    var heading = terminalArticleNextSignificantSibling(role);
    var list = heading && terminalArticleNextSignificantSibling(heading);
    if (!heading || !heading.matches("h2, h3, h4") || !list || !list.matches("ul, ol") ||
        heading.parentElement !== role.parentElement || list.parentElement !== role.parentElement ||
        heading.closest("article") !== owner.source || list.closest("article") !== owner.source ||
        terminalArticleAuthoredContext(heading, owner.source) ||
        terminalArticleAuthoredContext(list, owner.source) ||
        terminalArticleHasFollowingVisibleSibling(list) || !terminalArticlePureTextList(list)) return;

    var laterBodyParagraph = Array.from(owner.source.querySelectorAll("p, blockquote")).some(function(paragraph) {
      if (paragraph === role || !relatedArticleOwnedBodyParagraph(paragraph, owner.source)) return false;
      return !!(list.compareDocumentPosition(paragraph) & Node.DOCUMENT_POSITION_FOLLOWING);
    });
    if (laterBodyParagraph) return;

    var roleClone = terminalArticleMappedClone(role, owner);
    var headingClone = terminalArticleMappedClone(heading, owner);
    var listClone = terminalArticleMappedClone(list, owner);
    if (!roleClone || !headingClone || !listClone ||
        roleClone.parentElement !== headingClone.parentElement || headingClone.parentElement !== listClone.parentElement ||
        terminalArticleNextSignificantSibling(roleClone) !== headingClone ||
        terminalArticleNextSignificantSibling(headingClone) !== listClone ||
        terminalArticleAuthoredContext(roleClone, owner.selected) ||
        terminalArticleAuthoredContext(headingClone, owner.selected) ||
        terminalArticleAuthoredContext(listClone, owner.selected) ||
        terminalArticleHasFollowingVisibleSibling(listClone) || !terminalArticlePureTextList(listClone)) return;

    roleClone.remove();
    headingClone.remove();
    listClone.remove();
  });
}

function stripSourceOwnedTerminalRelatedStoryLeaves(owner) {
  var groupsByParent = new Map();
  Array.from(owner.source.querySelectorAll("div")).forEach(function(node) {
    if (node.closest("article") !== owner.source || terminalArticleAuthoredContext(node, owner.source) ||
        !terminalArticleRelatedStoryRole(node)) return;
    var parent = node.parentElement;
    if (!parent) return;
    if (!groupsByParent.has(parent)) groupsByParent.set(parent, []);
    groupsByParent.get(parent).push(node);
  });

  groupsByParent.forEach(function(nodes, parent) {
    if (nodes.length < 2 || nodes.some(function(node) {
      return elementSubtreeHidden(node) || node.children.length ||
        !normalizeText(node.textContent || "") || !terminalArticleClassOnlyLeaf(node);
    })) return;

    var visibleChildren = Array.from(parent.children).filter(function(child) { return !elementSubtreeHidden(child); });
    var firstIndex = visibleChildren.indexOf(nodes[0]);
    if (firstIndex < 0 || visibleChildren.length - firstIndex !== nodes.length ||
        !visibleChildren.slice(firstIndex).every(function(node, index) { return node === nodes[index]; })) return;

    var laterBodyParagraph = Array.from(owner.source.querySelectorAll("p, blockquote")).some(function(paragraph) {
      return relatedArticleOwnedBodyParagraph(paragraph, owner.source) &&
        !!(nodes[0].compareDocumentPosition(paragraph) & Node.DOCUMENT_POSITION_FOLLOWING);
    });
    if (laterBodyParagraph) return;

    var clones = nodes.map(function(node) { return terminalArticleMappedClone(node, owner); });
    if (clones.some(function(node) {
      return !node || terminalArticleAuthoredContext(node, owner.selected);
    })) return;
    var cloneParent = clones[0].parentElement;
    if (!cloneParent || clones.some(function(node) { return node.parentElement !== cloneParent; })) return;
    var selectedChildren = Array.from(cloneParent.children).filter(function(child) { return !elementSubtreeHidden(child); });
    var cloneFirstIndex = selectedChildren.indexOf(clones[0]);
    if (cloneFirstIndex < 0 || selectedChildren.length - cloneFirstIndex !== clones.length ||
        !selectedChildren.slice(cloneFirstIndex).every(function(node, index) { return node === clones[index]; })) return;

    clones.forEach(function(node) { node.remove(); });
  });
}

function terminalArticleRecirculationRole(node) {
  var classNames = String(node.getAttribute("class") || "").toLowerCase().split(/\s+/).filter(Boolean);
  return classNames.some(function(className) {
    return className.split(/[^a-z0-9]+/).some(function(token) {
      return token === "recirculation" || token === "recirculacao";
    });
  });
}

function terminalArticleRelatedStoryRole(node) {
  var classNames = String(node.getAttribute("class") || "").toLowerCase().split(/\s+/).filter(Boolean);
  return classNames.some(function(className) {
    var tokens = className.split(/[^a-z0-9]+/).filter(Boolean);
    return tokens.some(function(token, index) { return token === "related" && tokens[index + 1] === "story"; });
  });
}

function terminalArticleClassOnlyLeaf(node) {
  return Array.from(node.attributes || []).every(function(attribute) {
    return String(attribute.name || "").toLowerCase() === "class";
  });
}

function terminalArticlePureTextList(list) {
  if (!list.children.length) return false;
  return Array.from(list.childNodes).every(function(node) {
    if (node.nodeType === Node.TEXT_NODE) return !normalizeText(node.nodeValue || "");
    return node.nodeType === Node.ELEMENT_NODE && node.matches("li") && !node.children.length &&
      normalizeText(node.textContent || "") && terminalArticleClassOnlyLeaf(node);
  });
}

function terminalArticleNextSignificantSibling(node) {
  for (var sibling = node && node.nextSibling; sibling; sibling = sibling.nextSibling) {
    if (sibling.nodeType === Node.TEXT_NODE && !normalizeText(sibling.nodeValue || "")) continue;
    if (sibling.nodeType === Node.COMMENT_NODE) continue;
    return sibling.nodeType === Node.ELEMENT_NODE ? sibling : null;
  }
  return null;
}

function terminalArticleHasFollowingVisibleSibling(node) {
  for (var sibling = node && node.nextSibling; sibling; sibling = sibling.nextSibling) {
    if (sibling.nodeType === Node.TEXT_NODE && !normalizeText(sibling.nodeValue || "")) continue;
    if (sibling.nodeType === Node.COMMENT_NODE) continue;
    if (sibling.nodeType === Node.ELEMENT_NODE && elementSubtreeHidden(sibling)) continue;
    return true;
  }
  return false;
}

function terminalArticleMappedClone(source, owner) {
  var clone = owner.sourceClones.get(source);
  if (!clone || !owner.selected.contains(clone) || !terminalArticleMappedSubtreeMatches(source, clone, owner.sourceClones)) return null;
  return clone;
}

function terminalArticleMappedSubtreeMatches(source, clone, sourceClones) {
  var stack = [{ source: source, clone: clone }];
  while (stack.length) {
    var pair = stack.pop();
    var original = pair.source;
    var selected = pair.clone;
    if (!original || !selected || original.nodeType !== selected.nodeType) return false;
    if (original.nodeType === Node.TEXT_NODE || original.nodeType === Node.COMMENT_NODE) {
      if (original.nodeValue !== selected.nodeValue) return false;
      continue;
    }
    if (original.nodeType !== Node.ELEMENT_NODE || original.localName !== selected.localName ||
        original.childNodes.length !== selected.childNodes.length) return false;

    var originalAttributes = Array.from(original.attributes || []).filter(function(attribute) { return attribute.name !== "href"; });
    var selectedAttributes = Array.from(selected.attributes || []).filter(function(attribute) { return attribute.name !== "href"; });
    if (originalAttributes.length !== selectedAttributes.length || originalAttributes.some(function(attribute) {
      return selected.getAttribute(attribute.name) !== attribute.value;
    })) return false;
    var originalHref = original.getAttribute("href");
    var selectedHref = selected.getAttribute("href");
    if (originalHref !== selectedHref && (!originalHref || !selectedHref ||
        sourceOwnershipPageUrl(originalHref) !== sourceOwnershipPageUrl(selectedHref))) return false;

    Array.from(original.childNodes).forEach(function(child, index) {
      var childClone = selected.childNodes[index];
      if (child.nodeType === Node.ELEMENT_NODE && sourceClones.get(child) !== childClone) {
        stack.push({ source: null, clone: null });
      } else {
        stack.push({ source: child, clone: childClone });
      }
    });
  }
  return true;
}
