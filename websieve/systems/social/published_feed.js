  function publishedFeedAuthor(article) {
    var selector = "[rel~='author'], [itemprop~='author'], [data-author], .author, .username, [class$='-author'], [class$='__author'], [class$='-username'], [class$='__username']";
    var fields = Array.from(article.querySelectorAll(selector)).filter(function(node) {
      return !elementSubtreeHidden(node) && node.closest("article") === article &&
        !node.closest("blockquote, pre, code, [role='button']") && normalizeText(node.textContent || node.getAttribute("data-author"));
    });
    var authors = Array.from(new Set(fields.map(function(node) {
      return normalizeText(node.textContent || node.getAttribute("data-author"));
    })));
    return authors.length === 1 ? authors[0] : null;
  }

  function publishedFeedScore(owner, article) {
    var selector = "[data-score], [itemprop='upvoteCount'], [class*='vote' i], [class*='score' i]";
    var scores = [];
    owner.querySelectorAll(selector).forEach(function(field) {
      if (elementSubtreeHidden(field) || field.closest("blockquote, pre, code") ||
          (field.closest("article") && field.closest("article") !== article)) return;
      var explicit = field.getAttribute("data-score");
      var value = socialInteger(explicit === null ? normalizeText(field.textContent) : explicit, true);
      if (value !== null) scores.push(value);
      field.querySelectorAll("p, span, [data-score]").forEach(function(node) {
        if (elementSubtreeHidden(node) || node.closest("button, [role='button']")) return;
        var number = socialInteger(normalizeText(node.textContent), true);
        if (number !== null) scores.push(number);
      });
    });
    var unique = Array.from(new Set(scores));
    return unique.length === 1 ? unique[0] : null;
  }

  function publishedFeedRecord(article, main) {
    if (elementSubtreeHidden(article) || article.querySelector("article, h1") ||
        article.closest("nav, aside, form, dialog, [role='dialog'], [role='navigation']")) return null;
    var author = publishedFeedAuthor(article);
    if (!author) return null;
    var owner = article;
    while (owner.parentElement && owner.parentElement !== main &&
           owner.parentElement.querySelectorAll("article").length === 1) owner = owner.parentElement;
    var time = Array.from(article.querySelectorAll("time[datetime]")).find(function(node) {
      return !elementSubtreeHidden(node) && node.closest("article") === article &&
        normalizeText(node.getAttribute("datetime")) && !node.closest("blockquote, pre, code");
    });
    var titleLink = Array.from(article.querySelectorAll("h2 a[href], h3 a[href], a[href] h2, a[href] h3")).map(function(node) {
      return node.matches("a") ? node : node.closest("a[href]");
    }).find(function(link) {
      return !elementSubtreeHidden(link) && materializedHttpUrl(link.getAttribute("href")) && normalizeText(link.textContent);
    });
    var score = publishedFeedScore(owner, article);
    var material = Array.from(article.querySelectorAll("p, blockquote, pre, img[src], video, audio, iframe[src]")).some(function(node) {
      return !elementSubtreeHidden(node) && node.closest("article") === article &&
        (normalizeText(node.textContent) || node.matches("img, video, audio, iframe"));
    });
    if (!(time && material) && !(titleLink && score !== null)) return null;
    return { article: article, owner: owner, author: author, time: time, titleLink: titleLink, score: score,
      strong: !!(titleLink && time && score !== null) };
  }

  function publishedFeedRevealControl(node) {
    if (!node || !node.matches("p") || node.closest("blockquote, pre, code")) return false;
    var figure = node.closest("figure");
    var tokens = figure && [figure.id, figure.className].join(" ");
    return !!(figure && /(?:^|[-_\s])(?:adult|age)(?:[-_\s]|$)/i.test(tokens) &&
      /(?:^|[-_\s])(?:filter|gate|overlay)(?:[-_\s]|$)/i.test(tokens) &&
      /^(?:show|view|reveal|display|anzeigen|afficher|mostrar|poka[zż])\s+(?:13|16|18|21)\+$/i.test(normalizeText(node.textContent)));
  }

  function publishedFeedEvidence() {
    if (structuredDataNode(["LiveBlogPosting"])) return null;
    var mains = Array.from(document.querySelectorAll("main, [role='main']")).filter(function(main) {
      return !elementSubtreeHidden(main) && !(main.parentElement && main.parentElement.closest("main, [role='main']"));
    });
    if (mains.length !== 1) return null;
    var main = mains[0];
    if (Array.from(main.querySelectorAll("article h1, [itemprop='articleBody'] h1")).some(function(node) {
      return !elementSubtreeHidden(node);
    }) || main.querySelector('input[type="password"]')) return null;
    var records = Array.from(main.querySelectorAll("article")).map(function(article) {
      return publishedFeedRecord(article, main);
    }).filter(Boolean);
    var strong = records.filter(function(record) { return record.strong; });
    if (strong.length < 3) return null;
    var containers = Array.from(new Set(strong.map(function(record) { return record.owner.parentElement; })));
    if (containers.length !== 1) return null;
    var collection = containers[0];
    var competingMaterial = Array.from(main.querySelectorAll("p, blockquote, pre, table")).some(function(node) {
      var collectionHeader = node.matches("p") && node.closest("header") && !node.closest("article");
      return !collection.contains(node) && !elementSubtreeHidden(node) && normalizeText(node.textContent) &&
        !collectionHeader && !publishedFeedRevealControl(node) && !node.closest("nav, aside, form, dialog, [role='dialog'], footer");
    });
    if (competingMaterial) return null;
    records = records.filter(function(record) { return record.owner.parentElement === collection; });
    if (records.some(function(record) {
      return records.some(function(other) { return other !== record && record.owner.contains(other.owner); });
    })) return null;
    return { main: main, collection: collection, records: records };
  }

  function sourceOwnedPublishedFeedContent(metadata) {
    var evidence = publishedFeedEvidence();
    if (!evidence) return null;
    var root = document.createElement("section");
    evidence.records.forEach(function(record) {
      var clone = cleanClone(visibilityPrunedClone(record.owner, document), "aside, footer, iframe[src]");
      clone.querySelectorAll("p").forEach(function(node) { if (publishedFeedRevealControl(node)) node.remove(); });
      clone.querySelectorAll("[data-fetchutil-preserve]").forEach(function(node) { node.removeAttribute("data-fetchutil-preserve"); });
      root.appendChild(clone);
    });
    var text = normalizeText(root.textContent);
    if (!text) return null;
    return {
      title: metadata.title,
      byline: metadata.byline,
      excerpt: normalizeText(evidence.records[0].titleLink && evidence.records[0].titleLink.textContent) || metadata.excerpt,
      siteName: metadata.siteName,
      publishedTime: null,
      canonicalUrl: metadata.canonicalUrl,
      html: root.outerHTML,
      markdown: markdownFor(root.outerHTML),
      textContent: text,
      readerMode: false,
      contentType: "social",
      socialKind: "feed",
      platform: socialPlatformLabel(metadata),
      community: socialRouteCommunity(),
      sourceOwnedPublishedFeed: true,
      itemCount: evidence.records.length,
      hostAware: false
    };
  }
