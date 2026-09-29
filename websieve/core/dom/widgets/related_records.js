function relatedHeadingRecordRail(block) {
  if (!block || !block.matches || !block.matches("article, div, section, aside")) return false;
  if (relatedHeadingLinkedRecordGroup(block)) return true;
  if (relatedHeadingLinkedCardGroup(block)) return true;
  var directHeadings = Array.from(block.children).filter(function(child) {
    var text = normalizeText(child.textContent || "").replace(/[:：]\s*$/, "");
    return child.matches("h2, h3, h4") && RELATED_SECTION_HEADING_PATTERN.test(text);
  });
  if (directHeadings.length !== 1 || block.firstElementChild !== directHeadings[0]) return false;

  var records = Array.from(block.children).filter(function(child) { return child.matches("article"); });
  if (records.length < 3 || records.length !== block.children.length - 1) return false;
  var titles = new Set();
  return records.every(function(record) {
    if (record.querySelector("a[href], p, blockquote, img, picture, figure, video, audio, iframe, object, embed, ul, ol, dl, table, pre, code, form, input, button")) return false;
    var headings = record.querySelectorAll("h2, h3, h4");
    if (headings.length !== 1) return false;
    var times = Array.from(record.querySelectorAll("time")).filter(function(time) {
      return !elementVisuallyHidden(time) && normalizeText(time.getAttribute("datetime") || time.textContent || "");
    });
    if (!times.length) return false;
    var title = normalizeText(headings[0].textContent || "");
    if (title.length < 8 || titles.has(title)) return false;
    titles.add(title);

    var remainder = record.cloneNode(true);
    var heading = remainder.querySelector("h2, h3, h4");
    if (heading) heading.remove();
    remainder.querySelectorAll("time").forEach(function(node) { node.remove(); });
    return !normalizeText(remainder.textContent || "");
  });
}

function relatedRecordCollectionHeading(value) {
  var text = normalizeText(value || "").replace(/[:：]\s*$/, "");
  if (!text || SOURCE_REFERENCE_HEADING_PATTERN.test(text)) return false;
  return RELATED_SECTION_HEADING_PATTERN.test(text) || /^(?:most\s+read|الأكثر\s+قراءة)$/i.test(text);
}

function relatedRailHasUniqueVisibleArticleOwner() {
  var headings = Array.from(document.querySelectorAll("h1")).filter(function(heading) {
    return !elementVisuallyHidden(heading) && !heading.closest("nav, aside, footer, [role~='navigation' i], [role~='complementary' i]");
  });
  if (headings.length !== 1) return false;

  var heading = headings[0];
  var article = heading.closest("article");
  if (!article || elementSubtreeHidden(article)) return false;
  var paragraphs = Array.from(article.querySelectorAll("p, blockquote")).filter(function(paragraph) {
    return relatedArticleBodyParagraph(paragraph, article);
  });
  return paragraphs.length >= 2 && paragraphs.reduce(function(total, paragraph) {
    return total + normalizeText(paragraph.textContent || "").length;
  }, 0) >= 60;
}

function relatedArticleBodyParagraph(paragraph, article) {
  if (paragraph.closest("article") !== article || elementVisuallyHidden(paragraph) ||
      normalizeText(paragraph.textContent || "").length < 20) return false;
  for (var parent = paragraph.parentElement; parent && parent !== article; parent = parent.parentElement) {
    if (relatedHeadingRecordRail(parent)) return false;
  }
  return true;
}

function relatedHeadingLinkedRecordGroup(block) {
  var headings = Array.from(block.querySelectorAll("h2, h3, h4")).filter(function(heading) {
    return !elementVisuallyHidden(heading);
  });
  var labels = headings.filter(function(heading) { return relatedRecordCollectionHeading(heading.textContent || ""); });
  if (labels.length !== 1) return false;
  var records = headings.filter(function(heading) { return heading !== labels[0]; });
  if (records.length < 2) return false;
  var headingLinks = [];
  var destinations = [];
  var currentUrl = sourceOwnershipPageUrl(location.href);
  var valid = headings.every(function(heading) {
    var links = Array.from(heading.querySelectorAll("a[href]")).filter(function(link) { return !elementVisuallyHidden(link); });
    if (links.length !== 1 || normalizeText(links[0].textContent || "") !== normalizeText(heading.textContent || "")) return false;
    var destination = sourceOwnershipPageUrl(links[0].getAttribute("href"));
    if (!destination) return false;
    headingLinks.push(links[0]);
    if (heading === labels[0]) return true;
    if (destination === currentUrl || destinations.indexOf(destination) !== -1) return false;
    destinations.push(destination);
    return true;
  });
  if (!valid || destinations.length !== records.length) return false;
  var visibleLinks = Array.from(block.querySelectorAll("a[href]")).filter(function(link) { return !elementVisuallyHidden(link); });
  if (visibleLinks.length !== headingLinks.length) return false;
  var clone = visibilityPrunedClone(block, document);
  var cloneHeadings = Array.from(clone.querySelectorAll("h2, h3, h4"));
  if (cloneHeadings.length !== headings.length) return false;
  cloneHeadings.forEach(function(heading) { heading.remove(); });
  clone.querySelectorAll("script, style, noscript, template").forEach(function(node) { node.remove(); });
  return !normalizeText(clone.textContent || "") && !clone.querySelector(
    "a[href], img, picture, video, audio, iframe, object, embed, figure, table, pre, code, blockquote, form, input, textarea, select, button"
  );
}

function relatedHeadingLinkedCardGroup(block) {
  if (Array.from(block.childNodes).some(function(node) {
    return node.nodeType === Node.TEXT_NODE && normalizeText(node.nodeValue || "");
  })) return false;
  var label = Array.from(block.children).find(function(child) {
    return child.matches("h2, h3, h4") && relatedRecordCollectionHeading(child.textContent || "");
  });
  if (!label || block.firstElementChild !== label) return false;
  var labelLinks = Array.from(label.querySelectorAll("a[href]")).filter(function(link) {
    return !elementVisuallyHidden(link);
  });
  if (label.matches("a[href]")) labelLinks.unshift(label);
  if (labelLinks.length > 1 || (labelLinks.length === 1 &&
      normalizeText(labelLinks[0].textContent || "") !== normalizeText(label.textContent || ""))) return false;

  var records = Array.from(block.children).filter(function(child) { return child !== label; });
  if (records.length === 1 && records[0].matches("div, section, ul, ol")) {
    var wrapper = records[0];
    var nestedRecords = Array.from(wrapper.children);
    var wrapperText = Array.from(wrapper.childNodes).some(function(node) {
      return node.nodeType === Node.TEXT_NODE && normalizeText(node.nodeValue || "");
    });
    if (!wrapperText && nestedRecords.length >= 2 && nestedRecords.every(function(record) {
      return record.matches("article, div, li, h2, h3, h4") && !elementSubtreeHidden(record);
    })) records = nestedRecords;
  }
  if (records.length < 2) return false;
  var destinations = [];
  return records.every(function(record) {
    if (!record.matches("article, div, li, h2, h3, h4") || elementSubtreeHidden(record)) return false;
    var headings = record.matches("h2, h3, h4") ? [record] : Array.from(record.querySelectorAll("h2, h3, h4")).filter(function(heading) {
      return !elementVisuallyHidden(heading);
    });
    var links = Array.from(record.querySelectorAll("a[href]")).filter(function(link) { return !elementVisuallyHidden(link); });
    if (!headings.length) {
      if (links.length !== 1 || normalizeText(record.textContent || "") !== normalizeText(links[0].textContent || "")) return false;
      var plainDestination = sourceOwnershipPageUrl(links[0].getAttribute("href"));
      if (!plainDestination || plainDestination === sourceOwnershipPageUrl(location.href) || destinations.indexOf(plainDestination) !== -1 ||
          sourceOwnedLinkedCardHasUnownedMaterial(record, plainDestination)) return false;
      destinations.push(plainDestination);
      return true;
    }
    if (headings.length !== 1) return false;
    var title = headings[0];
    var titleText = normalizeText(title.textContent || "");
    var titleLinks = links.filter(function(link) {
      var linkText = normalizeText(link.textContent || "");
      var titleIsLinked = link === title || title.contains(link);
      var cardOwnsTitle = link.contains(title) && linkText.endsWith(titleText);
      return titleIsLinked && linkText === titleText || cardOwnsTitle;
    });
    if (titleLinks.length !== 1) return false;
    var destination = sourceOwnershipPageUrl(titleLinks[0].getAttribute("href"));
    if (!destination || destination === sourceOwnershipPageUrl(location.href) || destinations.indexOf(destination) !== -1) return false;
    if (links.some(function(link) { return sourceOwnershipPageUrl(link.getAttribute("href")) !== destination; })) return false;
    if (typeof sourceOwnedLinkedCardHasUnownedMaterial !== "function" ||
        sourceOwnedLinkedCardHasUnownedMaterial(record, destination)) return false;
    destinations.push(destination);
    return true;
  });
}
