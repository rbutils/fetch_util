function liveblogParentAddressMatches(context, current) {
  var canonical = liveblogComparableUrl((document.querySelector("link[rel~='canonical' i]") || {}).href);
  if (canonical && canonical === current) return true;
  return context.entities.some(function(entity) {
    return liveblogEntityPageUrls(entity).indexOf(current) !== -1;
  });
}

function liveblogShareOrPermalink(anchor) {
  if (!anchor || elementVisuallyHidden(anchor) || anchor.closest("nav, aside, footer, form, [role~='comment' i], [class*='comment' i], [class*='related' i], [class*='recommend' i]")) return false;
  var intent = [anchor.getAttribute("rel"), anchor.getAttribute("class"), anchor.id, anchor.getAttribute("aria-label"), anchor.getAttribute("title")].join(" ");
  return /(?:share|permalink|canonical|bookmark)/i.test(intent);
}

function liveblogLinkIntent(anchor) {
  return [anchor.getAttribute("rel"), anchor.getAttribute("class"), anchor.id,
    anchor.getAttribute("aria-label"), anchor.getAttribute("title")].join(" ");
}

function liveblogStrongPermalinkIntent(anchor) {
  return /(?:permalink|canonical|bookmark)/i.test(liveblogLinkIntent(anchor));
}

function liveblogShareTransport(anchor) {
  return /share/i.test(liveblogLinkIntent(anchor)) && !liveblogStrongPermalinkIntent(anchor);
}

function liveblogLinkAddresses(anchor) {
  if (!liveblogShareOrPermalink(anchor)) return [];
  var raw = anchor.getAttribute("href") || "";
  var addresses = [];
  var parsed;
  try {
    parsed = new URL(raw, location.href);
    if (!/^https?:$/.test(parsed.protocol) || parsed.username || parsed.password) return [];
    var explicitWebUrl = /^(?:https?:\/\/|\/\/)/i.test(raw.trim());
    if (!liveblogShareTransport(anchor) || explicitWebUrl) {
      var direct = liveblogComparableUrl(parsed.href);
      if (direct) addresses.push(direct);
    }
    parsed.searchParams.forEach(function(value) {
      var candidate = liveblogExplicitQueryAddress(value);
      if (candidate) addresses.push(candidate);
      var decoded = value;
      while (decoded.indexOf("%") !== -1) {
        var next;
        try { next = decodeURIComponent(decoded); } catch (_error) { break; }
        if (next === decoded) break;
        decoded = next;
        candidate = liveblogExplicitQueryAddress(decoded);
        if (candidate) addresses.push(candidate);
      }
    });
  } catch (_error) {
    return addresses;
  }
  return addresses.filter(function(url, index) { return addresses.indexOf(url) === index; });
}

function liveblogExplicitQueryAddress(value) {
  var candidate = normalizeText(value || "");
  if (!/^(?:https?:\/\/|\/\/)/i.test(candidate)) return "";
  return liveblogComparableUrl(candidate);
}

function liveblogRecordStructuredUrls(record) {
  var markers = [record.node].concat(Array.from(record.node.querySelectorAll("[itemscope][itemtype], [itemprop~='liveBlogUpdate' i]")));
  var urls = [];
  markers.forEach(function(marker) {
    if (elementVisuallyHidden(marker)) return;
    var itemType = marker.getAttribute("itemtype") || "";
    var liveUpdate = /liveBlogUpdate/i.test(marker.getAttribute("itemprop") || "");
    if (!/(?:Article|BlogPosting)/i.test(itemType) && !liveUpdate) return;
    var recordOwner = marker.closest("li, article");
    if (recordOwner && recordOwner !== record.node) return;

    [marker.getAttribute("itemid")].concat(Array.from(marker.querySelectorAll("[itemprop~='url' i], [itemprop~='mainEntityOfPage' i]")).filter(function(node) {
      return node.closest("[itemscope]") === marker && (!node.closest("li, article") || node.closest("li, article") === record.node) && !elementVisuallyHidden(node);
    }).map(function(node) {
      return node.getAttribute("content") || node.getAttribute("href") || node.textContent;
    })).forEach(function(value) {
      var url = liveblogComparableUrl(value);
      if (url && urls.indexOf(url) === -1) urls.push(url);
    });
  });
  return urls;
}

function liveblogRecordOwnsCurrentUrl(record, current) {
  if (liveblogRecordStructuredUrls(record).indexOf(current) !== -1) return true;
  var anchors = Array.from(record.node.querySelectorAll("a[href]")).filter(function(anchor) {
    if (anchor.closest("li, article") && anchor.closest("li, article") !== record.node) return false;
    return liveblogFragmentOwnsRecord(anchor, record, current) && liveblogLinkAddresses(anchor).indexOf(current) !== -1;
  });
  if (anchors.length) return true;

  var id = record.node.id;
  var page = liveblogComparableUrl(location.href).split("#")[0];
  var currentFragment = new URL(location.href).hash;
  if (!id || !currentFragment || currentFragment !== "#" + id || liveblogComparableUrl((document.querySelector("link[rel~='canonical' i]") || {}).href) !== page) return false;
  var ids = Array.from(document.querySelectorAll("[id]")).filter(function(node) { return node.id === id && !elementVisuallyHidden(node); });
  return ids.length === 1 && Array.from(record.node.querySelectorAll("a[rel~='bookmark' i], a[class*='permalink' i], a[class*='canonical' i]")).some(function(anchor) {
    return !elementVisuallyHidden(anchor) && liveblogComparableUrl(anchor.getAttribute("href")) === current;
  });
}

function liveblogAddressedRecords(context, current) {
  return context.records.filter(function(record) { return liveblogRecordOwnsCurrentUrl(record, current); });
}

function liveblogRecordByline(record) {
  var node = Array.from(record.querySelectorAll("[rel~='author' i], [itemprop~='author' i], [class*='byline' i], [class*='author' i]")).find(function(candidate) {
    return !elementVisuallyHidden(candidate) && !candidate.closest("nav, aside, [role~='comment' i], [class*='comment' i], [class*='share' i], [class*='related' i]");
  });
  if (!node) return null;
  return normalizeText(node.getAttribute("content") || node.textContent || "") || null;
}

function liveblogFragmentOwnsRecord(anchor, record, current) {
  var raw = anchor.getAttribute("href") || "";
  if (!raw) return false;
  var target;
  var requested;
  try {
    target = new URL(raw, location.href);
    requested = new URL(current);
  } catch (_error) {
    return false;
  }
  var sameRequestedFragment = !!requested.hash && liveblogComparableUrl(target.href) === current;
  if (!sameRequestedFragment) return true;
  var fragment = "";
  try { fragment = decodeURIComponent(requested.hash.slice(1)); } catch (_error) { return false; }
  if (!fragment || fragment !== record.node.id) return false;
  var ids = Array.from(document.querySelectorAll("[id]")).filter(function(node) { return node.id === fragment && !elementVisuallyHidden(node); });
  return ids.length === 1;
}

function liveblogEntryHasExternalComments(context, record) {
  var threads = sourceOwnedLiveblogDiscussionRoots({ context: context });
  return threads.some(function(thread) {
    return !record.node.contains(thread);
  });
}

function liveblogParentEntity(context) {
  var current = liveblogComparableUrl(location.href);
  var canonical = liveblogComparableUrl((document.querySelector("link[rel~='canonical' i]") || {}).href);
  var matches = context.entities.filter(function(entity) {
    var types = Array.isArray(entity["@type"]) ? entity["@type"] : [entity["@type"]];
    if (!types.some(function(type) { return /(?:^|[\/#])LiveBlogPosting$/i.test(String(type || "")); })) return false;
    return liveblogEntityPageUrls(entity).some(function(url) { return url === current || url === canonical; });
  });
  return matches.length === 1 ? matches[0] : null;
}

function liveblogParentPublishedTime(context) {
  var entity = liveblogParentEntity(context);
  if (entity && typeof entity.datePublished === "string" && entity.datePublished.trim()) return entity.datePublished.trim();
  return liveblogParentHeadMetadataValue(
    "meta[property='article:published_time'], meta[property='og:article:published_time'], meta[name='datePublished'], meta[itemprop~='datePublished' i]"
  ) || liveblogParentHeaderPublishedTime(context);
}

function liveblogParentByline(context) {
  var entity = liveblogParentEntity(context);
  var authors = entity && entity.author ? (Array.isArray(entity.author) ? entity.author : [entity.author]) : [];
  var names = authors.map(function(author) {
    return normalizeText(typeof author === "string" ? author : (author && author.name) || "");
  }).filter(Boolean);
  if (names.length) return names.filter(function(name, index) { return names.indexOf(name) === index; }).join(", ");
  return liveblogParentHeadMetadataValue("meta[name='author'], meta[property='article:author'], meta[itemprop~='author' i]") ||
    liveblogParentHeaderByline(context);
}

function resolveFallbackLiveblogOwnership() {
  var context = fallbackLiveblogPageContext();
  if (!context) return null;
  var current = liveblogComparableUrl(location.href);
  if (!current || liveblogParentAddressMatches(context, current)) {
    return { mode: "parent", node: context.parentRoot, heading: context.heading, context: context, proof: "liveblog-parent" };
  }
  var addressed = liveblogAddressedRecords(context, current);
  if (addressed.length !== 1 || liveblogEntryHasExternalComments(context, addressed[0])) {
    return { mode: "parent", node: context.parentRoot, heading: context.heading, context: context, proof: "liveblog-parent" };
  }
  var entry = addressed[0];
  return { mode: "entry", node: entry.node, heading: entry.heading, date: entry.date, context: context, proof: "liveblog-url-addressed-entry" };
}

function sourceOwnedLiveblogContent(metadata, ownership) {
  var source = ownership.node;
  var article = document.createElement("article");
  if (!source.contains(ownership.heading)) article.appendChild(sourceOwnedContentClone(ownership.heading));
  var discussions = sourceOwnedLiveblogDiscussionRoots(ownership);
  var footers = sourceOwnedLiveblogAttributionFooters(ownership).concat(sourceOwnedLiveblogCommentFooters(ownership, discussions));
  var content = sourceOwnedContentClone(source, footers);
  sourceOwnedLiveblogRemoveHeaderChrome(content, ownership);
  content.querySelectorAll("a").forEach(function(anchor) {
    if (liveblogStandaloneShareControl(anchor)) anchor.remove();
    else liveblogSanitizeCredentialPermalink(anchor);
  });
  article.appendChild(content);
  appendSourceOwnedLiveblogDiscussions(article, ownership, discussions);
  var text = normalizeText(article.textContent || "");
  var title = ownership.mode === "parent" ? liveblogParentTitle(ownership.context) : liveblogVisibleText(ownership.heading);
  var date = ownership.mode === "entry" ? normalizeText(ownership.date.getAttribute("datetime") || ownership.date.getAttribute("content") || ownership.date.textContent || "") : liveblogParentPublishedTime(ownership.context);
  var byline = ownership.mode === "entry" ? liveblogRecordByline(source) : liveblogParentByline(ownership.context);
  return {
    title: title,
    byline: byline,
    excerpt: fallbackArticleExcerpt(content, text, metadata, true),
    siteName: (metadata && metadata.siteName) || location.hostname,
    publishedTime: date,
    html: article.innerHTML,
    textContent: text,
    readerMode: false,
    contentType: "article",
    sourceOwnedFocalArticle: true,
    sourceOwnedLiveblog: true,
    isolatedLiveblogEntry: ownership.mode === "entry",
    singleTopicPage: ownership.mode === "parent" && ownership.context.singleTopicPage === true,
    focalPermalinkContent: true
  };
}

function sourceOwnedLiveblogRemoveHeaderChrome(root, ownership) {
  if (!root || !ownership || ownership.mode !== "parent") return;
  var selector = "[class*='sticky' i], [id*='sticky' i]";
  root.querySelectorAll(selector).forEach(function(node) {
    if (node.children.length || /[.!?。！？]/.test(normalizeText(node.textContent || ""))) return;
    var sources = Array.from(ownership.node.querySelectorAll(selector)).filter(function(source) {
      return source.className === node.className && source.id === node.id &&
        normalizeText(source.textContent || "") === normalizeText(node.textContent || "");
    });
    if (sources.length !== 1 || !sourceRecordBefore(sources[0], ownership.context.heading)) return;
    if (ownership.context.records.some(function(record) { return record.node.contains(sources[0]); })) return;
    node.remove();
  });
}

function sourceOwnedLiveblogAttributionFooters(ownership) {
  var records = ownership.mode === "entry" ? [ownership.node] : ownership.context.records.map(function(record) {
    return record.node;
  });
  return records.reduce(function(footers, record) {
    Array.from(record.querySelectorAll("footer")).forEach(function(footer) {
      if (!sourceOwnedLiveblogFooterHasMaterial(footer, record)) return;
      footers.push(footer);
    });
    return footers;
  }, []);
}

function sourceOwnedLiveblogFooterHasMaterial(footer, record) {
  if (!footer || !record || !record.contains(footer) || elementVisuallyHidden(footer) ||
      footer.closest(VISIBLE_COMMENT_THREAD_SELECTOR) ||
      footer.parentElement.closest("nav, aside, form, [role~='navigation' i], [role~='complementary' i]")) return false;
  if (sourceOwnedLiveblogFooterCrossesNestedRecord(footer, record) ||
      footer.querySelector("article, li, [data-liveblog-update], [itemprop~='liveBlogUpdate' i], [class*='live-update' i], [class*='minute-container' i]")) return false;

  var visible = visibilityPrunedClone(footer, document);
  if (!visible) return false;
  visible.querySelectorAll("script, style, noscript, template, form, input, textarea, select, button").forEach(function(node) {
    node.remove();
  });
  return !!(normalizeText(visible.textContent || "") ||
    visible.querySelector("a[href], img, picture, video, audio, iframe, object, embed, figure"));
}

function sourceOwnedLiveblogFooterCrossesNestedRecord(footer, record) {
  for (var node = footer.parentElement; node && node !== record; node = node.parentElement) {
    if (node.matches("article, li, [data-liveblog-update], [itemprop~='liveBlogUpdate' i], [class*='live-update' i], [class*='minute-container' i]")) return true;
  }
  return false;
}
