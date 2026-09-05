function staleOpacitySectionText(node) {
  if (!node) return "";

  var clone = node.cloneNode(true);
  Array.from(clone.querySelectorAll("script, style, noscript, template, svg")).forEach(function(removeNode) {
    removeNode.remove();
  });
  return normalizeText(clone.textContent || "");
}

function staleOpacitySectionChrome(node) {
  if (!node) return true;

  var identity = normalizeText([
    node.id || "",
    node.className || "",
    node.getAttribute && node.getAttribute("role") || "",
    node.getAttribute && node.getAttribute("aria-label") || ""
  ].join(" ")).toLowerCase();
  return /(?:^|[\s_-])(?:slider|carousel|swiper|slick|tab|tabs|tabpanel|dialog|modal|nav|navigation|menu|header|footer|sidebar|toolbar|drawer|popup|overlay|cookie|consent|privacy|newsletter|subscribe|subscription|auth|login)(?:$|[\s_-])/.test(identity);
}

function staleOpacityInlineZeroBranch(node, section) {
  if (!node || !node.style || !node.style.opacity || Number(node.style.opacity) !== 0) return false;
  if (node.hidden || node.hasAttribute("inert") || node.getAttribute("aria-hidden") === "true") return false;

  var style = getComputedStyle(node);
  if (style.display === "none" || style.visibility === "hidden" || style.visibility === "collapse") return false;
  if (Number(style.opacity) !== 0 || staleOpacitySectionChrome(node)) return false;

  var parent = node.parentElement;
  while (parent && parent !== section) {
    if (elementVisuallyHiddenWithin(parent, section)) return false;
    parent = parent.parentElement;
  }
  return parent === section;
}

function staleOpacityMaterialLinkCount(node) {
  return Array.from(node.querySelectorAll("a[href]")).filter(function(link) {
    return !!materializedHttpUrl(link.getAttribute("href"));
  }).length;
}

function staleOpacitySectionEvidence(root) {
  var clone = safeDeepClone(root, document);
  pruneHiddenClone(root, clone, [root]);
  Array.from(clone.querySelectorAll("[hidden], [inert], [aria-hidden='true']")).forEach(function(node) {
    node.remove();
  });
  return clone;
}

function staleOpacityNestedChromeMaterial(root) {
  return Array.from(root.querySelectorAll("*")).some(function(node) {
    if (!staleOpacitySectionChrome(node)) return false;
    return staleOpacitySectionText(node).length >= 30 || staleOpacityMaterialLinkCount(node) > 0;
  });
}

function staleOpacityNestedHiddenRecord(root) {
  var hiddenRoots = Array.from(root.querySelectorAll("*")).filter(function(node) {
    return node.hasAttribute("hidden") || node.hasAttribute("inert") ||
      String(node.getAttribute("aria-hidden") || "").toLowerCase() === "true" ||
      elementVisuallyHiddenWithin(node, root);
  });

  return hiddenRoots.some(function(node) {
    if (staleOpacityMaterialLinkCount(node) === 0) return false;

    var substantive = node.querySelector("h1, h2, h3, h4, h5, h6, p, time, picture, video, img[alt]");
    var identity = normalizeText([
      node.getAttribute("id"),
      node.getAttribute("class"),
      node.getAttribute("role"),
      node.getAttribute("aria-label")
    ].join(" ")).toLowerCase();
    if (!substantive && /\b(?:category|filter|taxonomy|tag)\b/.test(identity)) return false;

    return !!substantive || node.matches("article, li, [role='listitem']") ||
      !!node.querySelector("article, li, [role='listitem']");
  });
}

function staleOpacitySectionBranch(section) {
  if (!section || elementVisuallyHidden(section) || staleOpacitySectionChrome(section)) return null;

  var roots = topLevelQualifiedDescendants(section, "[style]", function(node) {
    if (!staleOpacityInlineZeroBranch(node, section)) return false;
    if (staleOpacityNestedHiddenRecord(node)) return false;

    var evidence = staleOpacitySectionEvidence(node);
    var text = staleOpacitySectionText(evidence);
    if (text.length < 30) return false;

    var blocks = Array.from(evidence.querySelectorAll("h1, h2, h3, h4, h5, h6, p")).filter(function(block) {
      return normalizeText(block.textContent || "");
    });
    return blocks.length > 0 || staleOpacityMaterialLinkCount(evidence) > 0;
  });
  if (roots.length !== 1) return null;

  var root = roots[0];
  var evidence = staleOpacitySectionEvidence(root);
  if (staleOpacityNestedChromeMaterial(evidence)) return null;

  var sectionText = staleOpacitySectionText(section);
  var rootText = staleOpacitySectionText(evidence);
  if (!sectionText || rootText.length * 100 < sectionText.length * 85) return null;
  return root;
}

function staleOpacityMarkdownText(markdown) {
  return normalizeText(String(markdown || "")
    .replace(/!\[([^\]]*)\]\([^)]+\)/g, "$1")
    .replace(/\[([^\]]+)\]\([^)]+\)/g, "$1")
    .replace(/[#>*_~`\[\]-]+/g, " "));
}

function staleOpacityMarkdownLines(markdown) {
  return String(markdown || "").split(/\r?\n/).map(staleOpacityMarkdownText).filter(Boolean);
}

function staleOpacityKeepsCurrentMarkdown(currentMarkdown, recoveredMarkdown) {
  var recoveredLines = staleOpacityMarkdownLines(recoveredMarkdown);
  var recoveredIndex = 0;

  return staleOpacityMarkdownLines(currentMarkdown).every(function(line) {
    var index = recoveredLines.indexOf(line, recoveredIndex);
    if (index < 0) return false;
    recoveredIndex = index + 1;
    return true;
  });
}

function staleOpacityListLineIndex(markdown, line, fromIndex) {
  var index = markdown.indexOf(line, fromIndex);
  while (index >= 0) {
    var startsLine = index === 0 || markdown.charAt(index - 1) === "\n";
    var lineEnd = index + line.length;
    var endsLine = lineEnd === markdown.length || markdown.charAt(lineEnd) === "\n";
    if (startsLine && endsLine) return index;
    index = markdown.indexOf(line, index + 1);
  }
  return -1;
}

function staleOpacityDetailedListMarkdown(recovered) {
  var markdown = recovered.sectionMarkdownWithDescription || recovered.markdown || "";
  var items = recovered.listExtraction && recovered.listExtraction.items || [];
  var searchIndex = 0;

  items.forEach(function(item) {
    var currentLine = listMarkdown([item]);
    var detailedItem = {};
    Object.keys(item || {}).forEach(function(key) { detailedItem[key] = item[key]; });
    detailedItem.card = null;
    detailedItem.contentCard = null;
    var itemDetail = normalizeText(detailedItem.detail || "");
    var actionDetail = /^(?:learn more|read more|view all|see all|show more)$/i.test(itemDetail);
    if ((!itemDetail || genericListControlText(itemDetail) || actionDetail) && item.card && item.card.querySelectorAll) {
      var itemTitle = normalizeText(item.text || "").toLowerCase();
      var seenHeadings = {};
      var headingDetails = Array.from(item.card.querySelectorAll("h1, h2, h3, h4, h5, h6")).map(function(heading) {
        return normalizeText(heading.textContent || "");
      }).filter(function(text) {
        var key = text.toLowerCase();
        if (!text || key === itemTitle || seenHeadings[key] || genericListControlText(text)) return false;
        seenHeadings[key] = true;
        return true;
      });
      detailedItem.detail = headingDetails.join(" - ");
    }
    var detailedLine = listMarkdown([detailedItem]);
    var index = staleOpacityListLineIndex(markdown, currentLine, searchIndex);
    if (index < 0) return;
    if (normalizeText(detailedLine).length <= normalizeText(currentLine).length) {
      searchIndex = index + currentLine.length;
      return;
    }

    markdown = markdown.slice(0, index) + detailedLine + markdown.slice(index + currentLine.length);
    searchIndex = index + detailedLine.length;
  });
  return markdown;
}

function staleOpacitySectionListContent(content, metadata) {
  if (!content || content.contentType !== "list" || content.hostAware || content.docsLike || !content.listExtraction) {
    return null;
  }

  var currentMarkdown = content.markdown || "";
  if (normalizeText(currentMarkdown).length > 120 || materializedListItemCount(content.listExtraction.items || [])) {
    return null;
  }
  if (!document.body) return null;

  var roots = Array.from(document.body.children).filter(function(node) {
    return node.matches && node.matches("section, [role='region']");
  }).map(staleOpacitySectionBranch).filter(Boolean);
  if (roots.length < 3) return null;

  var evidenceRoots = roots.map(staleOpacitySectionEvidence);
  var combinedText = evidenceRoots.map(staleOpacitySectionText).join(" ");
  var materialLinks = evidenceRoots.reduce(function(total, root) {
    return total + staleOpacityMaterialLinkCount(root);
  }, 0);
  var blockCount = evidenceRoots.reduce(function(total, root) {
    return total + Array.from(root.querySelectorAll("h1, h2, h3, h4, h5, h6, p")).filter(function(block) {
      return normalizeText(block.textContent || "");
    }).length;
  }, 0);
  if (combinedText.length < 350 || materialLinks < 3 || blockCount < 4) return null;

  var recovered = listContent(metadata, { preservedRoots: roots });
  if (!recovered) return null;
  var recoveredMarkdown = staleOpacityDetailedListMarkdown(recovered);
  if (normalizeText(recoveredMarkdown).length < 400) return null;
  if (materializedListItemCount(recovered.listExtraction && recovered.listExtraction.items || []) < 3) return null;

  if (!staleOpacityKeepsCurrentMarkdown(currentMarkdown, recoveredMarkdown)) return null;

  recovered.markdown = recoveredMarkdown;
  recovered.textContent = normalizeText(recoveredMarkdown);
  recovered.sectionMarkdownWithDescription = recoveredMarkdown;
  return recovered;
}
