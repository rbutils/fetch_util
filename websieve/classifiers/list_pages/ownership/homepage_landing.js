  function homepageLandingChrome(node) {
    return node.closest("nav, aside, header, footer, form, [role~='navigation' i], [role~='complementary' i], [role='search']");
  }

  function homepageFragmentPageRoot(root) {
    if (!root || !document.body || !homepageRootPath()) return null;
    var declared = focalSourceArticleMetadata();
    var chrome = "nav, aside, footer, form, menu, dialog, [role~='navigation' i], [role~='menu' i], [role~='complementary' i], [role='dialog']";
    if (declared && declared.typedArticles.some(function(article) {
      var headings = Array.from(document.querySelectorAll("h1, [itemprop~='headline' i]")).filter(function(node) {
        if (node.closest(chrome) || elementSubtreeHidden(node)) return false;
        if (normalizeText(node.textContent || "") !== article.headline) return false;
        var link = node.closest("a[href]");
        return !link || sourceOwnershipPageUrl(link.getAttribute("href")) === declared.pageUrl;
      });
      return headings.length === 1;
    })) return null;
    var records = Array.from(document.querySelectorAll("a[href]")).filter(function(link) {
      var heading = link.closest("h2, h3, h4") || link.querySelector("h2, h3, h4");
      if (!heading && link.querySelector("img[src], picture")) heading = link.querySelector("p");
      if (!heading) return false;
      if (heading.closest(chrome) || elementSubtreeHidden(heading)) return false;
      var header = heading.closest("header");
      if (header && !header.closest("article, section")) return false;
      var destination = materializedHttpUrl(link.getAttribute("href"));
      return !!destination && sourceOwnershipPageUrl(destination) !== sourceOwnershipPageUrl(location.href) &&
        !!normalizeText(heading.textContent || "");
    });
    var peers = records.filter(function(link) { return !root.contains(link); });
    if (!peers.length) {
      if (root.querySelector("h1")) return null;
      var destinations = new Set(records.filter(function(link) { return root.contains(link); }).map(function(link) {
        return materializedHttpUrl(link.getAttribute("href"));
      }));
      if (destinations.size < 2) return null;
    }
    var mains = Array.from(document.querySelectorAll("main, [role~='main' i]")).filter(function(node) {
      return !elementSubtreeHidden(node);
    });
    if (mains.length === 1 && mains[0].contains(root) && peers.every(function(node) { return mains[0].contains(node); })) {
      return mains[0];
    }
    return document.body;
  }

  function homepageFragmentPageContent(metadata, root) {
    var owner = homepageFragmentPageRoot(root);
    if (!owner) return null;
    var clone = visibilityPrunedClone(owner, document);
    removeAll(clone, "nav, footer, form, menu, dialog, script, style, [role~='navigation' i], [role~='menu' i], [role='dialog']");
    Array.from(clone.querySelectorAll("aside, [role='complementary']")).forEach(function(node) {
      if (!node.querySelector("article, section, h2 a[href], h3 a[href], h4 a[href], pre, code, blockquote, table, figure")) {
        node.remove();
      }
    });
    Array.from(clone.querySelectorAll("*")).forEach(function(node) {
      if (cookieConsentInterfaceNode(node)) node.remove();
    });
    return profileHtmlContent(metadata, clone, {
      cloneRoot: false,
      cleanupRoot: false,
      cleanupMarkdown: false,
      preserveCleanedRoot: true,
      title: metadata.title,
      excerpt: metadata.excerpt,
      byline: null,
      publishedTime: null,
      contentType: "list",
      extra: { sourceOwnedHomepageCollection: true }
    });
  }

  function homepageLandingOwnership() {
    if (!document.body || !homepageRootPath()) return null;
    if (typeof fallbackFocalHeadlineOwnership === "function" && fallbackFocalHeadlineOwnership()) return null;

    var main = document.querySelector("main, [role~='main' i]");
    if (!main || elementSubtreeHidden(main)) return null;

    var sourceClones = new WeakMap();
    var visibleMain = visibilityPrunedClone(main, document, sourceClones);
    var visibleHeadings = Array.prototype.filter.call(visibleMain.querySelectorAll("h1"), function(heading) {
      return !homepageLandingChrome(heading);
    });
    if (visibleHeadings.length !== 1) return null;
    if (visibleHeadings[0].closest("article")) return null;

    var visibleArticles = Array.prototype.filter.call(visibleMain.querySelectorAll("article"), function(article) {
      return !article.parentElement.closest("article") && !homepageLandingChrome(article);
    });
    var proseOwners = visibleArticles.filter(function(article) {
      if (article.querySelector("[itemprop~='headline' i], h2 a[href], h3 a[href]")) return false;
      var paragraphs = Array.prototype.filter.call(article.querySelectorAll("p"), function(paragraph) {
        return paragraph.closest("article") === article && !homepageLandingChrome(paragraph) &&
          normalizeText(paragraph.textContent || "").length >= 80;
      });
      return paragraphs.length >= 2 && normalizeText(paragraphs.map(function(paragraph) {
        return paragraph.textContent || "";
      }).join(" ")).length >= 280;
    });
    if (proseOwners.length !== 1) return null;

    var visibleBody = proseOwners[0];
    var substantialForeignProse = Array.prototype.some.call(visibleMain.querySelectorAll("p"), function(paragraph) {
      return !homepageLandingChrome(paragraph) && paragraph.closest("article") !== visibleBody &&
        normalizeText(paragraph.textContent || "").length >= 80;
    });
    if (substantialForeignProse) return null;

    var foreignHeadedRecord = visibleArticles.some(function(article) {
      return article !== visibleBody && article.querySelector("h1, h2, h3, [itemprop~='headline' i]");
    });
    if (foreignHeadedRecord) return null;

    var ownedMedia = Array.prototype.find.call(visibleBody.querySelectorAll("img[src]"), function(image) {
      return image.closest("article") === visibleBody && !homepageLandingChrome(image);
    });
    if (!ownedMedia) return null;

    var serviceLink = Array.prototype.find.call(visibleMain.querySelectorAll("a[href]"), function(link) {
      if (homepageLandingChrome(link) || link.closest("article") ||
          normalizeText(link.textContent || "").length < 5) return false;
      var url = materializedHttpUrl(link.getAttribute("href"));
      if (!url) return false;
      try {
        var parsed = new URL(url);
        return parsed.origin === location.origin && parsed.pathname !== "/";
      } catch (_error) {
        return false;
      }
    });
    if (!serviceLink) return null;

    var pageHeading = Array.prototype.find.call(main.querySelectorAll("h1"), function(heading) {
      return sourceClones.get(heading) === visibleHeadings[0];
    });
    var body = Array.prototype.find.call(main.querySelectorAll("article"), function(article) {
      return sourceClones.get(article) === visibleBody;
    });
    if (!pageHeading || !body) return null;

    return { main: main, heading: pageHeading, body: body };
  }
