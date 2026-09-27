function contentsComponentLabelKey(value) {
  return normalizeText(value || "").replace(/\(\s+/g, "(").replace(/\s+\)/g, ")");
}

function contentsComponentMetadataRegion(list, main) {
  for (var current = list && list.parentElement; current && current !== main; current = current.parentElement) {
    var semanticRegion = current.matches("header, [itemprop~='author' i]") ||
      Array.from(current.classList || []).some(function(token) { return /(?:metadata|byline|author)/i.test(token); });
    if (semanticRegion) return current;
  }
  return null;
}

function contentsComponentSchemaPageIdentity(headline, lead, byline, publishedTime, metadata) {
  var pageTypes = ["FAQPage", "WebPage", "ProfilePage"];
  var pageNodes = structuredDataNodes().filter(function(node) {
    return nodeTypes(node).some(function(type) { return pageTypes.indexOf(type) !== -1; });
  });
  if (!pageNodes.length) return { valid: true, modifiedTime: null };

  var pageKey = structuredDataDocumentKey(metadata.canonicalUrl || location.href);
  var matching = pageNodes.filter(function(node) {
    var mainEntity = node.mainEntityOfPage;
    var identity = typeof mainEntity === "string" ? mainEntity :
      (mainEntity && (mainEntity["@id"] || mainEntity.url));
    var candidates = [node.url, node["@id"], identity].map(structuredDataDocumentKey).filter(Boolean);
    return candidates.indexOf(pageKey) !== -1;
  });
  if (matching.length !== 1) return { valid: false, modifiedTime: null };

  var node = matching[0];
  var name = entityName(node.name || node.headline);
  var summary = entityText(node.text || node.description);
  var author = entityName(node.author);
  var datePublished = entityText(node.datePublished);
  if (name !== headline || summary !== lead || !datePublished ||
      contentsComponentDateKey(datePublished) !== contentsComponentDateKey(publishedTime) ||
      (author && sourceRecordTextKey(author) !== sourceRecordTextKey(byline))) {
    return { valid: false, modifiedTime: null };
  }
  return { valid: true, modifiedTime: entityText(node.dateModified) || null };
}

function contentsComponentPath(component, node) {
  var path = [];
  for (var current = node; current && current !== component; current = current.parentElement) path.unshift(current);
  return path.length && path[0].parentElement && component.contains(path[0]) ? path : null;
}

function contentsComponentDivergentBranches(component, first, second) {
  var firstPath = contentsComponentPath(component, first);
  var secondPath = contentsComponentPath(component, second);
  if (!firstPath || !secondPath) return null;
  var index = 0;
  while (index < firstPath.length && index < secondPath.length && firstPath[index] === secondPath[index]) index += 1;
  if (index >= firstPath.length || index >= secondPath.length || firstPath[index] === secondPath[index]) return null;
  return { first: firstPath[index], second: secondPath[index] };
}

function contentsComponentTargets(main, component, nav) {
  var links = Array.prototype.slice.call(nav.querySelectorAll("a[href]"));
  if (!links.length) return null;
  var seen = Object.create(null);
  var entries = [];
  links.forEach(function(link) {
    var href = link.getAttribute("href") || "";
    var label = contentsComponentLabelKey(visibleMetadataNodeText(link));
    if (!/^#[^#\s]+$/.test(href) || !label) return;
    var id = href.slice(1);
    if (seen[id]) return;
    seen[id] = true;
    var matches = Array.prototype.filter.call(document.querySelectorAll("[id]"), function(node) {
      return node.id === id && !elementVisuallyHidden(node);
    });
    if (matches.length !== 1 || !matches[0].matches("h2, h3, h4, h5, h6") ||
        !component.contains(matches[0]) || !main.contains(matches[0]) ||
        contentsComponentLabelKey(visibleMetadataNodeText(matches[0])) !== label) return;
    entries.push({ id: id, href: href, label: label, target: matches[0] });
  });
  if (entries.length !== links.length) return null;

  var branches = contentsComponentDivergentBranches(component, nav, entries[0].target);
  if (!branches || entries.some(function(entry, index) {
    var targetBranches = contentsComponentDivergentBranches(component, nav, entry.target);
    return !targetBranches || targetBranches.first !== branches.first || targetBranches.second !== branches.second ||
      (index > 0 && !contentsComponentBefore(entries[index - 1].target, entry.target));
  })) return null;
  return { entries: entries, bodyBranch: branches.second, navBranch: branches.first };
}

function contentsComponentUpdateHistory(component, nav, bodyBranch, lastTarget, modifiedTime) {
  var modifiedInstant = contentsComponentParseInstant(modifiedTime);
  if (!Number.isFinite(modifiedInstant)) return null;
  var headings = Array.prototype.filter.call(component.querySelectorAll("h2, h3, h4, h5, h6"), function(node) {
    return normalizeText(visibleMetadataNodeText(node)).toLowerCase() === "updates to this page";
  });
  if (headings.length !== 1) return null;
  if (nav.contains(headings[0]) || !contentsComponentBefore(lastTarget, headings[0])) return null;
  var branch = headings[0].parentElement;
  var lists = [];
  while (branch && branch !== component) {
    lists = Array.prototype.filter.call(branch.querySelectorAll("ol, ul"), function(node) {
      return !nav.contains(node);
    });
    if (lists.length === 1) break;
    if (lists.length > 1) return null;
    branch = branch.parentElement;
  }
  if (!branch || branch === component || !component.contains(branch) || nav.contains(branch) || lists.length !== 1) return null;
  var bodyHistoryOwner = sourceRecordLowestCommonAncestor([bodyBranch, branch]);
  if (!bodyHistoryOwner || !component.contains(bodyHistoryOwner) ||
      nav.contains(bodyHistoryOwner) || bodyHistoryOwner.matches("nav, aside, footer, [role='navigation'], [role='complementary']")) return null;
  var entries = Array.prototype.filter.call(lists[0].children, function(node) { return node.matches("li"); });
  if (!entries.length) return null;
  var visibleEntries = entries.filter(function(entry) { return !elementVisuallyHidden(entry); });
  var controlledHidden = !visibleEntries.length ? contentsComponentControlledHiddenHistory(component, branch, lists[0]) : null;
  if (!visibleEntries.length) {
    if (!controlledHidden || contentsComponentVisibleLastUpdatedKey(branch) !== contentsComponentDateKey(modifiedTime)) return null;
  }
  if (!controlledHidden && visibleEntries.length !== entries.length) return null;
  if (!controlledHidden) entries = visibleEntries;
  var previousInstant = null;
  var direction = 0;
  var newestInstant = -Infinity;
  var valid = entries.every(function(entry) {
    var times = entry.querySelectorAll("time[datetime]");
    var notes = Array.prototype.filter.call(entry.querySelectorAll("p"), function(node) {
      return normalizeText(controlledHidden ? node.textContent : visibleMetadataNodeText(node));
    });
    if (times.length !== 1 || !notes.length) return false;
    var instant = contentsComponentParseInstant(times[0].getAttribute("datetime"));
    if (!Number.isFinite(instant)) return false;
    if (previousInstant !== null) {
      var entryDirection = instant > previousInstant ? 1 : (instant < previousInstant ? -1 : 0);
      if (!entryDirection || (direction && direction !== entryDirection)) return false;
      direction = entryDirection;
    }
    previousInstant = instant;
    newestInstant = Math.max(newestInstant, instant);
    return true;
  });
  if (!valid || newestInstant !== modifiedInstant) return null;
  return { node: branch, list: lists[0], entries: entries, collapsed: !!controlledHidden, controlledHidden: !!controlledHidden };
}

function contentsComponentOwnedComments(main, component, bodyBranch) {
  var candidates = visibleCommentCandidates(main);
  if (!candidates.length) return [];
  var threads = visibleCommentThreadRoots(main);
  if (!threads.length || threads.some(function(thread) {
    return !thread.matches(PRIMARY_COMMENT_THREAD_SELECTOR) || !main.contains(thread) ||
      !commentThreadHasMaterial(thread) ||
      (!bodyBranch.contains(thread) && !contentsComponentBefore(component, thread));
  })) return null;
  if (candidates.some(function(node) {
    return !threads.some(function(thread) { return thread === node || thread.contains(node); });
  })) return null;
  var separateArticles = Array.prototype.filter.call(main.querySelectorAll("article"), function(article) {
    return !bodyBranch.contains(article) && !threads.some(function(thread) { return thread.contains(article); });
  });
  if (separateArticles.length) return null;
  return threads.filter(function(thread) { return !bodyBranch.contains(thread); });
}

function sourceOwnedContentsComponentOwnership(metadata) {
  if (!metadata || typeof sourceRecordVisibleMain !== "function") return null;
  var main = sourceRecordVisibleMain();
  if (!main) return null;
  var components = Array.prototype.filter.call(main.querySelectorAll("[data-module~='contents-list-with-body']"), function(node) {
    return !elementVisuallyHidden(node) &&
      !node.closest("nav, aside, footer, [role='navigation'], [role='complementary']");
  });
  if (components.length !== 1) return null;

  var component = components[0];
  var headings = sourceRecordVisibleHeadings(main).filter(function(node) { return node.matches("h1"); });
  if (headings.length !== 1) return null;
  var headlineNode = headings[0];
  var headline = normalizeText(visibleMetadataNodeText(headlineNode));
  if (!headline || articleTitleFromOwnedHeading(headlineNode.outerHTML, metadata.title, metadata.siteName) !== headline) return null;

  var navs = Array.prototype.filter.call(component.querySelectorAll("nav"), function(node) {
    return !elementVisuallyHidden(node);
  });
  if (navs.length !== 1) return null;
  var nav = navs[0];
  var navHeading = Array.prototype.filter.call(nav.querySelectorAll("h2"), function(node) {
    return !elementVisuallyHidden(node) && normalizeText(visibleMetadataNodeText(node)).toLowerCase() === "contents";
  });
  if (navHeading.length !== 1) return null;
  var targets = contentsComponentTargets(main, component, nav);
  if (!targets) return null;

  var groups = visibleLabeledMetadataGroups(main).filter(function(group) {
    var from = sourceRecordUniqueField(group, ["From"]);
    var published = sourceRecordUniqueField(group, ["Published", "Publication Date"]);
    var region = contentsComponentMetadataRegion(group.list, main);
    if (!from || !published || !region || region.matches("nav, aside, footer, [role='navigation'], [role='complementary']")) return false;
    if (!headlineNode.compareDocumentPosition(group.list) || !contentsComponentBefore(headlineNode, group.list) ||
        !contentsComponentBefore(group.list, component)) return false;
    if (metadata.declaredByline && sourceRecordTextKey(metadata.declaredByline) !== sourceRecordTextKey(from)) return false;
    return true;
  });
  if (groups.length !== 1) return null;

  var group = groups[0];
  var byline = sourceRecordUniqueField(group, ["From"]);
  var publishedTime = sourceRecordUniqueField(group, ["Published", "Publication Date"]);
  var region = contentsComponentMetadataRegion(group.list, main);
  var leads = Array.prototype.filter.call(main.querySelectorAll("p"), function(node) {
    return !elementVisuallyHidden(node) && contentsComponentBefore(headlineNode, node) &&
      contentsComponentBefore(node, group.list) && normalizeText(visibleMetadataNodeText(node));
  });
  if (leads.length !== 1) return null;
  var leadNode = leads[0];
  var lead = normalizeText(visibleMetadataNodeText(leadNode));
  var schema = contentsComponentSchemaPageIdentity(headline, lead, byline, publishedTime, metadata);
  if (!schema.valid) return null;
  var commentThreads = contentsComponentOwnedComments(main, component, targets.bodyBranch);
  if (!commentThreads) return null;
  var updateHistory = contentsComponentUpdateHistory(component, nav, targets.bodyBranch,
    targets.entries[targets.entries.length - 1].target, schema.modifiedTime);
  if (schema.modifiedTime && !updateHistory) return null;

  return {
    main: main,
    component: component,
    nav: nav,
    navTitle: normalizeText(visibleMetadataNodeText(navHeading[0])),
    entries: targets.entries,
    bodyBranch: targets.bodyBranch,
    headline: headline,
    headlineNode: headlineNode,
    lead: lead,
    leadNode: leadNode,
    metadataRegion: region,
    metadataGroup: group,
    metadataList: group.list,
    byline: byline,
    publishedTime: publishedTime,
    modifiedTime: schema.modifiedTime,
    updateHistory: updateHistory,
    commentThreads: commentThreads
  };
}

function sourceOwnedContentsComponentContent(metadata, ownership) {
  if (!ownership || !ownership.bodyBranch) return null;
  var content = profileHtmlContent(metadata, ownership.bodyBranch, {
    title: ownership.headline,
    byline: ownership.byline,
    publishedTime: ownership.publishedTime,
    excerpt: ownership.lead,
    hostAware: false,
    contentType: "article",
    cleanupRoot: false
  });
  if (!content) return null;
  content.hostAware = false;
  content.sourceOwnedContentsComponent = ownership;
  return content;
}
