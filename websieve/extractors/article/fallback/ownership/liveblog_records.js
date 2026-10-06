function liveblogComparableUrl(value) {
  if (!value) return "";
  try {
    var parsed = new URL(value, location.href);
    if (!/^https?:$/.test(parsed.protocol) || parsed.username || parsed.password) return "";
    var query = Array.from(parsed.searchParams.entries()).sort(function(left, right) {
      return left[0] === right[0] ? left[1].localeCompare(right[1]) : left[0].localeCompare(right[0]);
    });
    var search = query.length ? "?" + new URLSearchParams(query).toString() : "";
    return parsed.origin + parsed.pathname + search + parsed.hash;
  } catch (_error) {
    return "";
  }
}

function liveblogEntityPageUrls(entity) {
  var urls = [entity.url, entity.mainEntityOfPage, entity["@id"]].map(function(value) {
    if (value && typeof value === "object") value = value.url || value["@id"];
    if (typeof value === "string" && !/^(?:https?:)?\/\//i.test(value) && value.charAt(0) !== "/") return "";
    return liveblogComparableUrl(value);
  }).filter(Boolean);
  return urls.filter(function(url, index) { return urls.indexOf(url) === index; });
}

function liveblogPostingEntities() {
  if (typeof structuredDataNodes !== "function" || typeof nodeTypes !== "function") return [];
  return structuredDataNodes().filter(function(node) {
    return nodeTypes(node).some(function(type) { return /LiveBlogPosting/i.test(type); });
  });
}

function liveblogVisibleText(node) {
  if (!node || elementVisuallyHidden(node)) return "";
  return normalizeText(node.textContent || "");
}

function liveblogRecordDate(record) {
  var nodes = Array.from(record.querySelectorAll("time[datetime], time, [itemprop~='datePublished' i], [class*='update-time' i], [class*='update_time' i], [class*='timestamp' i], [class*='published' i], [class*='date' i], [class*='time' i]"));
  return nodes.find(function(node) {
    if (elementVisuallyHidden(node) || node.closest("nav, aside, [role~='comment' i], [class*='comment' i], [class*='share' i]")) return false;
    var value = normalizeText(node.getAttribute("datetime") || node.getAttribute("content") || node.textContent || "");
    var semanticTime = node.matches("time, [itemprop~='datePublished' i], [class*='date' i], [class*='time' i], [class*='timestamp' i]");
    return value.length >= 4 && (semanticTime || /[0-9\u0660-\u0669\u06f0-\u06f9]/.test(value));
  }) || null;
}

function liveblogRecordHeading(record) {
  var headings = Array.from(record.querySelectorAll("h2, h3, h4, [itemprop~='headline' i]")).filter(function(node) {
    if (elementVisuallyHidden(node) || node.closest("nav, aside, [role~='comment' i], [class*='comment' i], [class*='related' i], [class*='recommend' i]")) return false;
    var nested = node.parentElement;
    while (nested && nested !== record) {
      if (nested.matches("li, article") && nested !== record) return false;
      nested = nested.parentElement;
    }
    return liveblogVisibleText(node).length >= 8;
  });
  return headings.length === 1 ? headings[0] : null;
}

function liveblogRecordHasMaterialBody(record, heading) {
  var prose = Array.from(record.querySelectorAll("p, blockquote, figcaption, [itemprop~='articleBody' i], [class*='description' i], [class*='update-content' i], [class*='entry-content' i]")).filter(function(node) {
    return !elementVisuallyHidden(node) && !node.closest("nav, aside, [role~='comment' i], [class*='comment' i], [class*='share' i], [class*='recommend' i], [class*='related' i] ");
  });
  var text = normalizeText(prose.map(function(node) { return node.textContent || ""; }).join(" "));
  if (!text) {
    var clone = sourceOwnedContentClone(record);
    clone.querySelectorAll("h1, h2, h3, h4, time, [class*='update-time' i], [class*='update_time' i], [class*='date' i], [class*='time' i], [class*='share' i], [class*='author' i]").forEach(function(node) { node.remove(); });
    text = normalizeText(clone.textContent || "");
  }
  return text.length >= 40 && !!heading;
}

function liveblogRecordParts(record) {
  if (!record || elementSubtreeHidden(record) || record.closest("nav, aside, footer, [role~='complementary' i], [role~='comment' i], [class*='comment' i], [class*='sidebar' i], [class*='related' i], [class*='recommend' i]")) return null;
  var heading = liveblogRecordHeading(record);
  var date = liveblogRecordDate(record);
  if (!heading || !date || !liveblogRecordHasMaterialBody(record, heading)) return null;
  return { node: record, heading: heading, date: date };
}

function liveblogRecordCandidates(container, structuredParent) {
  var selector = "[itemprop~='liveBlogUpdate' i], [data-liveblog-update], [class*='live-update' i], [class*='minute-container' i], li, article";
  if (structuredParent) selector += ", [role~='article' i], div";
  var candidates = Array.from(container.querySelectorAll(selector)).map(function(node) {
    return liveblogRecordParts(node);
  }).filter(Boolean);
  return candidates.filter(function(record) {
    return !candidates.some(function(other) { return record.node !== other.node && record.node.contains(other.node); });
  });
}

function liveblogMarkerNodes() {
  return Array.from(document.querySelectorAll("[data-liveblog], [id*='liveblog' i], [class*='liveblog' i], [id*='live-blog' i], [class*='live-blog' i], [class*='live-updates' i], [class*='live-entries' i], [itemtype*='LiveBlogPosting' i]"));
}

function liveblogPageHeading(entities) {
  var headings = Array.from(document.querySelectorAll("h1")).filter(function(node) {
    return !elementVisuallyHidden(node) && !node.closest("nav, aside, footer, [role~='complementary' i], [class*='sidebar' i], [class*='related' i], [class*='recommend' i]");
  });
  if (headings.length !== 1) return null;
  var headingTitle = normalizeText(headings[0].textContent || "");
  var pageTitles = [document.title, metadataValue("og:title", "property")].map(function(value) { return normalizeText(value); }).filter(Boolean);
  var headlineMatches = entities.filter(function(entity) {
    return liveblogComparableHeadline(entity.headline) === liveblogComparableHeadline(headingTitle);
  });
  if (pageTitles.indexOf(headingTitle) !== -1 || headlineMatches.length === 1) return { node: headings[0], title: headingTitle };

  var current = liveblogComparableUrl(location.href);
  var canonical = liveblogComparableUrl((document.querySelector("link[rel~='canonical' i]") || {}).href);
  var parentTitles = entities.filter(function(entity) {
    var urls = liveblogEntityPageUrls(entity);
    var headline = normalizeText(entity.headline || "");
    if (!headline || !urls.some(function(url) { return url === current || url === canonical; })) return false;
    return pageTitles.some(function(pageTitle) {
      return pageTitle === headline || [" | ", " - ", " — ", " – "].some(function(separator) {
        return pageTitle.indexOf(headline + separator) === 0;
      });
    });
  });
  if (parentTitles.length !== 1) return null;
  return { node: headings[0], title: normalizeText(parentTitles[0].headline) };
}

function liveblogComparableHeadline(value) {
  return normalizeText(value || "").toLowerCase().replace(/[“”„\"'’‘]/g, "");
}

function liveblogPageCandidates(entities, markers, heading) {
  var candidates = markers.slice();
  var current = liveblogComparableUrl(location.href);
  var canonical = liveblogComparableUrl((document.querySelector("link[rel~='canonical' i]") || {}).href);
  var entityOwnsPage = entities.some(function(entity) {
    return liveblogEntityPageUrls(entity).some(function(url) { return url === current || url === canonical; });
  });
  var matchingHeadlines = heading ? entities.filter(function(entity) {
    return liveblogComparableHeadline(entity.headline) === liveblogComparableHeadline(heading.title);
  }) : [];
  if (entityOwnsPage || matchingHeadlines.length === 1) {
    candidates = candidates.concat(Array.from(document.querySelectorAll("main, article, section, [role~='main' i]")).filter(function(node) {
      return heading && node.contains(heading.node);
    }));
  }
  return candidates.filter(function(node, index) {
    return candidates.indexOf(node) === index && !elementVisuallyHidden(node) && node !== document.body && node !== document.documentElement;
  });
}

function liveblogContextsHaveSameRecords(left, right) {
  return left.records.length === right.records.length && left.records.every(function(record, index) {
    return record.node === right.records[index].node;
  });
}

function liveblogContextOwners(contexts) {
  var owners = [];
  contexts.forEach(function(context) {
    var shadowed = false;
    for (var index = 0; index < owners.length; index += 1) {
      var owner = owners[index];
      if (!liveblogContextsHaveSameRecords(owner, context)) continue;
      if (owner.parentRoot === context.parentRoot || context.parentRoot.contains(owner.parentRoot)) {
        shadowed = true;
        break;
      }
      if (owner.parentRoot.contains(context.parentRoot)) {
        owners.splice(index, 1);
        index -= 1;
      }
    }
    if (!shadowed) owners.push(context);
  });
  return owners;
}

function liveblogContextIsIndependentLinkedList(context) {
  if (!context || !homepageRootPath() || !context.parentRoot.matches("main, [role~='main' i]") ||
      context.records.length < 3 || typeof genericListStructuredCardLink !== "function") return false;
  if (context.records.some(function(record) { return !record.node.matches("article"); })) return false;
  var parents = context.records.map(function(record) { return record.node.parentElement; });
  if (!parents[0] || parents.some(function(parent) { return parent !== parents[0]; })) return false;
  var markers = liveblogMarkerNodes();
  if (context.records.some(function(record) {
    return record.node.matches("[data-liveblog-update], [class*='live-update' i], [class*='minute-container' i]") ||
      markers.some(function(marker) { return marker === record.node || marker.contains(record.node); });
  })) return false;

  var current = new URL(location.href);
  var currentPath = current.origin + current.pathname.replace(/\/$/, "");
  var destinations = context.records.map(function(record) {
    var link = genericListStructuredCardLink(record.node, true);
    var href = link && materializedHttpUrl(link.getAttribute("href"));
    if (!href) return "";
    var destination = new URL(href);
    var path = destination.origin + destination.pathname.replace(/\/$/, "");
    return path !== currentPath ? path : "";
  });
  return destinations.every(Boolean) && new Set(destinations).size === destinations.length;
}

function fallbackLiveblogPageContext() {
  var entities = liveblogPostingEntities();
  var markers = liveblogMarkerNodes();
  if (!entities.length && !markers.length) return null;
  var heading = liveblogPageHeading(entities);
  if (!heading) return null;
  var contexts = liveblogPageCandidates(entities, markers, heading).map(function(container) {
    var records = liveblogRecordCandidates(container, entities.length > 0);
    if (records.length < 2) return null;
    var parentRoot = sourceOwnershipCommonAncestor(heading.node, container);
    if (!parentRoot || parentRoot === document.body || parentRoot === document.documentElement || sourceOwnershipInChrome(parentRoot)) return null;
    var signature = String(parentRoot.className || "") + " " + String(parentRoot.id || "");
    if (!parentRoot.matches("main, article, section, [role~='main' i]") && !/(?:article|story|live|blog|content|detail|main)/i.test(signature)) return null;
    return { container: container, records: records, heading: heading.node, title: heading.title, parentRoot: parentRoot, entities: entities };
  }).filter(Boolean);
  if (!contexts.length) return null;
  var maxRecords = Math.max.apply(null, contexts.map(function(context) { return context.records.length; }));
  contexts = contexts.filter(function(context) { return context.records.length === maxRecords; });
  var owners = liveblogContextOwners(contexts);
  if (owners.length !== 1 || liveblogContextIsIndependentLinkedList(owners[0])) return null;
  owners[0].singleTopicPage = liveblogContextHasSinglePageIdentity(owners[0]);
  return owners[0];
}

function liveblogContextHasSinglePageIdentity(context) {
  if (!context || context.entities.length !== 1 || !context.heading || !context.title) return false;
  var entity = context.entities[0];
  var current = liveblogComparableUrl(location.href);
  var canonical = liveblogComparableUrl((document.querySelector("link[rel~='canonical' i]") || {}).href);
  var ownsPage = liveblogEntityPageUrls(entity).some(function(url) {
    return url === current || (!!canonical && url === canonical);
  });
  return ownsPage && liveblogComparableHeadline(entity.headline) === liveblogComparableHeadline(context.title);
}
