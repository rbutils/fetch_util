function sourceHeaderMetadataDateKey(value) {
  var instant = Date.parse(value || "");
  return Number.isFinite(instant) ? new Date(instant).toISOString().slice(0, 10) :
    sourceRecordTextKey(value);
}

function sourceHeaderMetadataRegion(list, main) {
  for (var current = list && list.parentElement; current && current !== main; current = current.parentElement) {
    var region = current.matches("header, [itemprop~='author' i]") ||
      Array.from(current.classList || []).some(function(token) {
        return /(?:^|[-_])(?:metadata|byline|author)(?:$|[-_])/i.test(token);
      });
    if (region) return current;
  }
  return null;
}

function sourceHeaderMetadataRegionIsOwned(region, main, body) {
  if (!region || region === main || region.contains(body)) return false;
  var foreignRegion = "nav, aside, footer, [role='navigation'], [role='complementary'], " +
    "[class*='related' i], [id*='related' i], [class*='sidebar' i], [id*='sidebar' i], " +
    "[class*='recommend' i], [id*='recommend' i]";
  if (main.matches(foreignRegion)) return false;
  for (var current = region; current && current !== main; current = current.parentElement) {
    if (current.matches(foreignRegion)) return false;
  }
  return main.contains(region);
}

function sourceOwnedFallbackHeaderMatchesPrimary(primary, headerMetadata) {
  if (!primary || primary.contentType !== "article" || !headerMetadata) return false;
  if (!headerMetadata.bodyRoot || !headerMetadata.bodyParagraphNodes) return false;
  var titleMatches = sourceRecordTextKey(primary.title) === sourceRecordTextKey(headerMetadata.title);
  var selectedParagraphs = Array.from(primary.sourceOwnedReaderParagraphSources || []);
  var bodyParagraphs = headerMetadata.bodyParagraphNodes;
  var selectedBodyParagraphs = selectedParagraphs.filter(function(paragraph) {
    return bodyParagraphs.indexOf(paragraph) !== -1;
  });
  var allSelectedOwned = selectedParagraphs.length >= 2 && selectedParagraphs.every(function(paragraph) {
    return bodyParagraphs.indexOf(paragraph) !== -1 || paragraph === headerMetadata.leadNode;
  });
  var bodyMatches = allSelectedOwned && selectedBodyParagraphs.length > 0 &&
    selectedBodyParagraphs[0] === bodyParagraphs[0] &&
    selectedBodyParagraphs.every(function(paragraph, index) {
      return index === 0 || bodyParagraphs.indexOf(paragraph) > bodyParagraphs.indexOf(selectedBodyParagraphs[index - 1]);
    });
  return titleMatches && bodyMatches;
}

function sourceOwnedFallbackHeaderMetadata(selected, title, metadata) {
  if (!selected) return null;
  var mains = Array.prototype.filter.call(document.querySelectorAll("main, [role='main']"), function(main) {
    return !elementVisuallyHidden(main) && main.contains(selected);
  });
  if (mains.length !== 1) return null;

  var main = mains[0];
  var headings = sourceRecordVisibleHeadings(main).filter(function(heading) { return heading.matches("h1"); });
  if (headings.length !== 1 || !main.contains(selected)) return null;
  var heading = headings[0];
  var headline = normalizeText(visibleMetadataNodeText(heading));
  if (!headline || articleTitleFromOwnedHeading(heading.outerHTML, title, metadata.siteName) !== headline) return null;

  var bodyRoots = Array.prototype.filter.call(main.querySelectorAll(
    "article, [itemprop~='articleBody' i], [data-article-body], [data-module~='govspeak'], [class*='article-content' i], [class*='article-body' i], [class*='story-content' i]"
  ), function(body) {
    return !elementVisuallyHidden(body) &&
      !body.closest("nav, aside, footer, [role='navigation'], [role='complementary']");
  });
  if (bodyRoots.length !== 1 || (!bodyRoots[0].contains(selected) && !selected.contains(bodyRoots[0]))) return null;

  var groups = visibleLabeledMetadataGroups(main).filter(function(group) {
    if (!sourceRecordBefore(heading, group.list) || !sourceRecordBefore(group.list, bodyRoots[0])) return false;
    var hasAuthor = sourceRecordFieldValues(group, ["From", "Author", "By"]).length > 0;
    var hasDate = sourceRecordFieldValues(group, ["Published", "Publication Date", "Date"]).length > 0;
    var region = sourceHeaderMetadataRegion(group.list, main);
    return hasAuthor && hasDate && sourceHeaderMetadataRegionIsOwned(region, main, bodyRoots[0]);
  });
  if (groups.length !== 1) return null;
  var group = groups[0];
  var from = sourceRecordUniqueField(group, ["From", "Author", "By"]);
  var published = sourceRecordUniqueField(group, ["Published", "Publication Date", "Date"]);
  if (!from || !published) return null;
  if (metadata.byline && sourceRecordTextKey(metadata.byline) !== sourceRecordTextKey(from)) return null;
  if (metadata.publishedTime && sourceHeaderMetadataDateKey(metadata.publishedTime) !== sourceHeaderMetadataDateKey(published)) return null;
  var leads = Array.prototype.filter.call(main.querySelectorAll("p"), function(paragraph) {
    return !elementVisuallyHidden(paragraph) && sourceRecordBefore(heading, paragraph) &&
      sourceRecordBefore(paragraph, group.list) && normalizeText(visibleMetadataNodeText(paragraph));
  });
  if (leads.length !== 1) return null;
  var bodyParagraphNodes = Array.prototype.filter.call(bodyRoots[0].querySelectorAll("p"), function(paragraph) {
    return !elementVisuallyHidden(paragraph) &&
      !paragraph.closest("nav, aside, footer, [role='navigation'], [role='complementary'], " +
        "[class*='related' i], [id*='related' i], [class*='sidebar' i], [id*='sidebar' i], " +
        "[class*='recommend' i], [id*='recommend' i]");
  });
  if (bodyParagraphNodes.length < 2) return null;
  var result = {
    title: headline,
    byline: from,
    publishedTime: published,
    lead: normalizeText(visibleMetadataNodeText(leads[0]))
  };
  Object.defineProperty(result, "bodyRoot", { value: bodyRoots[0] });
  Object.defineProperty(result, "bodyParagraphNodes", { value: bodyParagraphNodes });
  Object.defineProperty(result, "leadNode", { value: leads[0] });
  return result;
}
