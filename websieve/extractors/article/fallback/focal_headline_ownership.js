  var fallbackFocalOwnershipCache = new WeakMap();

  function focalOwnershipDocumentState() {
    var state = fallbackFocalOwnershipCache.get(document);
    var href = location.href;
    if (!state || state.href !== href) {
      if (state && state.observer) state.observer.disconnect();
      state = { dirty: true, href: href, ownership: null, observer: null };
      if (typeof MutationObserver !== "undefined" && document.documentElement) {
        state.observer = new MutationObserver(function() { state.dirty = true; });
        state.observer.observe(document.documentElement, {
          subtree: true,
          childList: true,
          characterData: true,
          attributes: true
        });
      }
      fallbackFocalOwnershipCache.set(document, state);
    }
    if (state.observer && state.observer.takeRecords().length) state.dirty = true;
    return state;
  }

  function focalCanonicalUrl(url) {
    if (!url) return "";
    try {
      var parsed = new URL(url, location.href);
      parsed.hash = "";
      return parsed.origin + parsed.pathname.replace(/\/$/, "") + parsed.search;
    } catch (_error) {
      return "";
    }
  }

  function focalSourceArticleMetadata() {
    var canonical = document.querySelector("link[rel~='canonical' i]");
    var pageUrl = focalCanonicalUrl((canonical && canonical.getAttribute("href")) || location.href);
    if (!pageUrl || pageUrl !== focalCanonicalUrl(location.href)) return null;

    var headlines = [];
    var typedArticles = [];
    if (typeof structuredDataNodes === "function" && typeof nodeTypes === "function") {
      structuredDataNodes().forEach(function(node) {
        var types = nodeTypes(node).filter(function(type) {
          return /(?:NewsArticle|ReportageNewsArticle|LiveBlogPosting|BlogPosting|Article)/i.test(type);
        });
        if (!types.length) return;
        var mainEntity = node.mainEntityOfPage;
        if (mainEntity && typeof mainEntity === "object") mainEntity = mainEntity["@id"] || mainEntity.url;
        if (focalCanonicalUrl(node.url || mainEntity) !== pageUrl) return;
        var headline = normalizeText(node.headline || "");
        var identity = normalizeText(node["@id"] || node.url || pageUrl);
        var datePublished = normalizeText(node.datePublished || node.dateCreated || "");
        if (!typedArticles.some(function(article) { return article.id === identity && article.headline === headline; })) {
          typedArticles.push({ id: identity, headline: headline, types: types, url: pageUrl, datePublished: datePublished });
        }
        if (!headline) return;
        if (headlines.indexOf(headline) === -1) headlines.push(headline);
      });
    }

    var ogTypeNode = document.querySelector("meta[property='og:type' i]");
    var ogType = normalizeText((ogTypeNode && ogTypeNode.getAttribute("content")) || "");
    var articleType = /(?:article|newsarticle|blogposting|liveblogposting)/i.test(ogType) || headlines.length > 0;
    if (!articleType) return null;

    var ogTitleNode = document.querySelector("meta[property='og:title' i]");
    var ogTitle = normalizeText((ogTitleNode && ogTitleNode.getAttribute("content")) || "");
    var siteNameNode = document.querySelector("meta[property='og:site_name' i]");
    var siteName = normalizeText((siteNameNode && siteNameNode.getAttribute("content")) || "");
    var canonicalHost = "";
    try {
      canonicalHost = new URL(pageUrl).hostname.replace(/^www\./i, "");
    } catch (_error) {
      canonicalHost = "";
    }
    [siteName, canonicalHost].filter(Boolean).some(function(suffixName) {
      return [" | ", " - ", " — ", " – "].some(function(separator) {
        var suffix = separator + suffixName;
        if (ogTitle.slice(-suffix.length) !== suffix) return false;
        ogTitle = normalizeText(ogTitle.slice(0, -suffix.length));
        return true;
      });
    });
    if (ogTitle && headlines.indexOf(ogTitle) === -1) headlines.push(ogTitle);
    return { headlines: headlines, pageUrl: pageUrl, ogTitle: ogTitle, typedArticles: typedArticles };
  }

  function focalOwnershipArticleRoot(node) {
    if (node.matches("article")) return node;
    return node.closest("article") || node;
  }

  function focalOwnershipExactHeadline(root, headlines) {
    var matches = Array.prototype.filter.call(root.querySelectorAll("h1, [itemprop~='headline' i]"), function(heading) {
      if (elementVisuallyHidden(heading)) return false;
      var headingOwner = heading.closest("article");
      if (headingOwner && headingOwner !== root) return false;
      var text = normalizeText(heading.textContent || "");
      return text.length >= 12 && headlines.indexOf(text) !== -1;
    });
    return matches.length === 1 ? matches[0] : null;
  }

  function focalOwnershipPublicPreviewNodes(root) {
    var selector = "[class*='paywall-short-content' i], [class*='public-preview' i], [data-public-preview]";
    return Array.prototype.filter.call(root.querySelectorAll(selector), function(preview) {
      if (preview.closest("nav, aside, footer, [role~='navigation' i], [role~='complementary' i], [role~='comment' i], [class*='comment' i], [id*='comment' i]")) return false;
      var owner = preview.closest("article");
      if (owner && owner !== root) return false;
      if (preview.parentElement && preview.parentElement.closest(selector)) return false;
      return true;
    });
  }

  function focalOwnershipVisibleBody(root) {
    if (elementSubtreeHidden(root) || root.closest("nav, aside, footer, [role~='navigation' i], [role~='complementary' i], [class*='comment' i], [id*='comment' i]")) return null;
    var visible = visibilityPrunedClone(root, document);
    var previews = focalOwnershipPublicPreviewNodes(visible);
    var paragraphs = previews.length ? previews.reduce(function(found, preview) {
      if (preview.matches("p, div[data-key^='paragraph-'], div[class*='paragraph-' i]")) found.push(preview);
      return found.concat(Array.prototype.slice.call(preview.querySelectorAll("p, div[data-key^='paragraph-'], div[class*='paragraph-' i]")));
    }, []) : Array.prototype.slice.call(visible.querySelectorAll("p, div[data-key^='paragraph-'], div[class*='paragraph-' i]"));
    paragraphs = paragraphs.filter(function(paragraph) {
      if (paragraph.closest("nav, aside, footer, [role~='navigation' i], [role~='complementary' i], [role~='comment' i], [class*='comment' i], [id*='comment' i]")) return false;
      var article = paragraph.closest("article");
      if (!article || article === visible) return true;
      return article.matches("[class*='minute-container' i], [class*='live-update' i]");
    });
    var text = normalizeText(paragraphs.map(function(paragraph) { return paragraph.textContent || ""; }).join(" "));
    var liveItems = visible.querySelectorAll("[data-liveblog], [class*='live-update' i], [class*='minute-container' i]").length;
    if (text.length < 120 && !(liveItems >= 2 && text.length >= 80)) return null;
    var links = Array.prototype.reduce.call(visible.querySelectorAll("a[href]"), function(total, link) {
      return total + normalizeText(link.textContent || "").length;
    }, 0);
    if (text.length < 400 && links / text.length >= 0.45) return null;
    return { visible: visible, text: text, paragraphs: paragraphs.length, publicPreview: previews.length > 0 };
  }

  function focalOwnershipRetainPublicPreview(root) {
    var previews = focalOwnershipPublicPreviewNodes(root);
    if (!previews.length) return false;
    root.querySelectorAll("[data-fetchutil-public-preview-owned]").forEach(function(node) { node.removeAttribute("data-fetchutil-public-preview-owned"); });
    previews.forEach(markVerifiedFocalPublicPreview);
    root.querySelectorAll("[class*='paywall-content' i], [class*='premium-content' i], [class*='paywall-container' i], [class*='tollbit-locked' i], [data-paywall-locked], [data-locked-content], [data-access='premium'], [aria-hidden='true']").forEach(function(locked) {
      if (previews.some(function(preview) { return locked === preview || locked.contains(preview); })) return;
      locked.remove();
    });
    return true;
  }

  function resolveFallbackFocalOwnership() {
    var metadata = focalSourceArticleMetadata();
    if (!metadata) return null;
    var selector = [
      "article", "[itemprop~='articleBody' i]", "[data-article-body]",
      "[class*='article-content' i]", "[class*='article-body' i]",
      "[class*='article-detail' i]", "[class*='story-content' i]"
    ].join(", ");
    var owners = new Map();
    document.querySelectorAll(selector).forEach(function(candidate) {
      if (elementVisuallyHidden(candidate)) return;
      var root = focalOwnershipArticleRoot(candidate);
      if (!root || root.closest("nav, aside, footer, [role~='navigation' i], [role~='complementary' i], [class*='comment' i], [id*='comment' i]")) return;
      var heading = focalOwnershipExactHeadline(root, metadata.headlines);
      if (heading) {
        owners.set(root, { node: root, heading: heading, title: normalizeText(heading.textContent || ""), proof: "same-owner-source-headline" });
        return;
      }
      if (!candidate.matches("article")) return;
      var repeatedLead = Array.prototype.find.call(candidate.querySelectorAll("p"), function(paragraph) {
        if (elementSubtreeHidden(paragraph)) return false;
        if (paragraph.closest("article") !== candidate) return false;
        var text = normalizeText(paragraph.textContent || "");
        return text.length >= 12 && metadata.headlines.indexOf(text) !== -1;
      });
      if (repeatedLead) {
        owners.set(root, { node: root, heading: null, title: normalizeText(repeatedLead.textContent || ""), proof: "same-owner-repeated-headline" });
        return;
      }
      if (candidate.querySelector("h1, h2, h3, h4, [itemprop~='headline' i]")) return;
      if (!metadata.ogTitle || candidate.querySelector("article")) return;
      var ownedParagraphs = Array.prototype.filter.call(candidate.querySelectorAll("p"), function(paragraph) {
        return paragraph.closest("article") === candidate && !elementSubtreeHidden(paragraph) &&
          normalizeText(paragraph.textContent || "").length >= 180;
      });
      if (ownedParagraphs.length !== 1 || !candidate.querySelector("figure, img, picture")) return;
      if (!owners.has(candidate)) owners.set(candidate, { node: candidate, heading: null, title: metadata.ogTitle, proof: "canonical-article-metadata" });
    });

    var mediaArticle = focalOwnershipMediaArticle(metadata);
    if (mediaArticle) owners.set(mediaArticle.node, mediaArticle);

    var verified = [];
    if (owners.size !== 1) return null;
    owners.forEach(function(owner) {
      if (independentLinkedArticleCollection(owner.node)) return;
      var body = focalOwnershipVisibleBody(owner.node);
      if (!body && owner.proof === "same-owner-source-headline-and-media" && owner.mediaUrl) {
        body = { visible: visibilityPrunedClone(owner.node, document), text: "", paragraphs: 0, publicPreview: false, sourceMediaOnly: true };
      }
      if (!body) return;
      if (owner.proof === "canonical-article-metadata" &&
          (body.paragraphs !== 1 || !owner.node.querySelector("figure, img, picture"))) return;
      owner.body = body;
      verified.push(owner);
    });
    if (verified.length !== 1) return null;
    return verified[0];
  }

  function fallbackFocalHeadlineOwnership() {
    var state = focalOwnershipDocumentState();
    if (state.dirty) {
      state.ownership = resolveFallbackFocalOwnership();
      state.dirty = false;
    }
    return state.ownership;
  }

  function genericFocalArticleContent(metadata) {
    if (!fallbackLiveblogPageContext() && !resolveCanonicalArticleBodyOwnership() && !fallbackFocalHeadlineOwnership()) return null;
    return fallbackContent(metadata);
  }
