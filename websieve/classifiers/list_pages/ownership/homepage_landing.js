  function homepageLandingChrome(node) {
    return node.closest("nav, aside, header, footer, form, [role~='navigation' i], [role~='complementary' i], [role='search']");
  }

  function homepageCollectionPageIdentity() {
    var current = sourceOwnershipPageUrl(location.href);
    var nodes = structuredDataNodes();
    if (!current || nodes.some(structuredDataFocalRecord)) return null;
    var pages = nodes.filter(function(node) {
      return nodeTypes(node).indexOf("WebPage") !== -1 && sourceOwnershipPageUrl(node.url || node["@id"]) === current;
    });
    var sites = nodes.filter(function(node) {
      return nodeTypes(node).indexOf("WebSite") !== -1 && sourceOwnershipPageUrl(node.url || node["@id"]) === current;
    });
    if (pages.length !== 1 || sites.length !== 1) return null;
    var identity = sites[0]["@id"] || sites[0].url;
    var parts = asArray(pages[0].isPartOf).map(function(part) {
      return typeof part === "string" ? part : part && part["@id"];
    });
    try {
      if (!identity || !parts.some(function(part) {
        return part && new URL(part, document.baseURI).href === new URL(identity, document.baseURI).href;
      })) return null;
    } catch (_error) {
      return null;
    }
    var pageName = document.createElement("textarea");
    pageName.innerHTML = entityName(pages[0]) || "";
    if (normalizeText(pageName.value) !== normalizeText(document.title)) return null;
    var titles = Array.from(document.querySelectorAll("meta[property='og:title' i]")).map(function(node) {
      return normalizeText(node.getAttribute("content"));
    });
    var siteName = normalizeText(entityName(sites[0]));
    var publishers = Array.from(document.querySelectorAll("meta[property='og:site_name' i]"));
    var types = Array.from(document.querySelectorAll("meta[property='og:type' i]"));
    var urls = Array.from(document.querySelectorAll("link[rel~='canonical' i], meta[property='og:url' i]"));
    if (!titles.length || !titles[0] || !titles.every(function(title) { return title === titles[0]; }) ||
        !siteName || !publishers.length || !publishers.every(function(node) {
          return normalizeText(node.getAttribute("content")) === siteName;
        }) || !types.length || !types.every(function(node) {
          return normalizeText(node.getAttribute("content")).toLowerCase() === "website";
        }) || !urls.length || !urls.every(function(node) {
          return sourceOwnershipPageUrl(node.getAttribute("href") || node.getAttribute("content")) === current;
        })) return null;
    return { title: titles[0], siteName: siteName };
  }

  function homepageCollectionSubsectionHeading(root, records) {
    var identity = homepageCollectionPageIdentity();
    if (!identity) return false;
    var headings = Array.from(root.querySelectorAll("h1")).filter(function(heading) {
      return !homepageLandingChrome(heading) && !elementSubtreeHidden(heading);
    });
    if (headings.length !== 1 || headings[0].closest("article")) return false;
    var heading = headings[0];
    var title = normalizeText(heading.textContent || "");
    if (!title || title === identity.title || title === identity.siteName) return false;
    var queries = Array.from(root.querySelectorAll(".wp-block-query")).filter(function(query) {
      return !homepageLandingChrome(query) && !elementSubtreeHidden(query) &&
        !!query.querySelector(".wp-block-post-template");
    });
    if (queries.length < 2) return false;
    for (var owner = heading.parentElement; owner && owner !== root; owner = owner.parentElement) {
      if (!owner.matches(".wp-block-group, section")) continue;
      var ownedQueries = queries.filter(function(query) { return owner.contains(query); });
      if (ownedQueries.length !== 1) continue;
      var owned = records.filter(function(record) {
        return ownedQueries[0].contains(record) && !!record.closest(".wp-block-post-template");
      });
      var peers = records.filter(function(record) {
        return !owner.contains(record) && !!record.closest(".wp-block-post-template") &&
          queries.some(function(query) { return query.contains(record); }) &&
          !!(record.compareDocumentPosition(heading) & Node.DOCUMENT_POSITION_FOLLOWING);
      });
      var destinations = new Set(owned.map(function(record) { return materializedHttpUrl(record.getAttribute("href")); }));
      var peerDestinations = new Set(peers.map(function(record) { return materializedHttpUrl(record.getAttribute("href")); }));
      if (destinations.size >= 2 && peerDestinations.size >= 2) return true;
    }
    return false;
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
      if (root.querySelector("h1") && !homepageCollectionSubsectionHeading(root, records)) return null;
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
    removeAll(clone, "nav, footer, form, menu, dialog, script, style, noscript, template, [role~='navigation' i], [role~='menu' i], [role='dialog']");
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

  function homepageSubsectionCollectionContent(metadata) {
    if (!document.body || !homepageRootPath() || !document.body.querySelector("h1") ||
        !document.body.querySelector(".wp-block-query .wp-block-post-template")) return null;
    return withSourceVisibilityRead(function() {
      return homepageFragmentPageContent(metadata, document.body);
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

  function homepageTablePeerCollectionContent(metadata, tables, records) {
    if (!homepageRootPath() || records.length < 2 || !tables.length) return null;
    var mains = document.querySelectorAll("main, [role~='main' i]");
    if (mains.length !== 1) return null;
    var main = mains[0];
    if (!tables.every(function(table) { return main.contains(table); })) return null;
    var destinations = new Set();
    Array.from(main.querySelectorAll("h2, h3, h4")).forEach(function(heading) {
      if (homepageLandingChrome(heading) || tables.some(function(table) { return table.contains(heading); })) return;
      var link = heading.closest("a[href]") || heading.querySelector("a[href]");
      var destination = link && materializedHttpUrl(link.getAttribute("href"));
      if (!destination || sourceOwnershipPageUrl(destination) === sourceOwnershipPageUrl(location.href)) return;
      if (!normalizeText(heading.textContent) || elementSubtreeHidden(heading)) return;
      destinations.add(destination);
    });
    if (destinations.size < 2 || homepageFragmentPageRoot(tables[0]) !== main) return null;
    var content = homepageFragmentPageContent(metadata, tables[0]);
    if (content) {
      content.hostAware = false;
      content.sourceOwnedHomepagePeerTables = true;
    }
    return content;
  }
