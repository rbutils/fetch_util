  function completePrimaryHeadlineCollection(content, markdown) {
    var extraction = content.listExtraction;
    var items = extraction && extraction.items;
    var main = document.querySelector("main");
    if (!main || document.querySelectorAll("main").length !== 1 || !items || items.length < 3) return false;

    var links = Array.prototype.filter.call(main.querySelectorAll("h2 a[href], h3 a[href]"), function(link) {
      return !elementSubtreeHidden(link) && !link.closest("nav, aside, footer, article, [role='navigation']") &&
        !!materializedHttpUrl(link.getAttribute("href"));
    });
    var cards = links.map(function(link) { return link.closest("section, li"); });
    if (cards.length !== items.length || cards.some(function(card) { return !card; })) return false;
    var owner = cards[0].parentElement;
    if (!owner || !main.contains(owner) || owner.closest("nav, aside, footer, article, [role='navigation']") ||
        cards.some(function(card) { return card.parentElement !== owner; })) return false;

    var sourceUrls = links.map(function(link) { return materializedHttpUrl(link.getAttribute("href")); });
    if (new Set(sourceUrls).size !== sourceUrls.length) return false;
    return items.every(function(item, index) {
      return item.url === sourceUrls[index] && normalizeText(links[index].textContent) === item.text &&
        markdown.indexOf(item.url) !== -1 && markdown.indexOf(item.text) !== -1;
    });
  }

  function sourceOwnedHomepageRecordEvidence(content, markdown) {
    if (!content || content.contentType !== "list" || !homepageRootPath() || content.portalRootEvidence) return null;
    var extraction = content.listExtraction;
    var sourceRoot = extraction && (extraction.sourceNode || extraction.root);
    var root = document.body;
    var items = extraction && extraction.items;
    if (!root || !sourceRoot || !items || !root.contains(sourceRoot) || root.querySelector("article h1")) return null;
    var chrome = "nav, aside, header, footer, form, dialog, [role='navigation'], [role='complementary'], [aria-modal='true']";
    var links = Array.from(root.querySelectorAll("a[href]")).filter(function(link) {
      return !elementSubtreeHidden(link) && !link.closest(chrome) &&
        normalizeText(visibilityPrunedClone(link, document).textContent) && materializedHttpUrl(link.getAttribute("href"));
    });
    // Bare linked list items alone do not establish independent editorial records.
    var cards = new Set(links.map(homepageCardRoot).filter(function(card) {
      return card && (card.tagName !== "LI" || card.querySelector("h1, h2, h3, h4, p, blockquote, time, figure"));
    }));
    if (cards.size < 4) return null;
    var selectedUrls = new Set(items.map(function(item) { return item.url && homepageCanonicalUrl(item.url); }).filter(Boolean));
    var sourceUrls = new Set(links.map(function(link) { return homepageCanonicalUrl(materializedHttpUrl(link.getAttribute("href"))); }));
    if (selectedUrls.size !== sourceUrls.size || Array.from(sourceUrls).some(function(url) { return !selectedUrls.has(url); })) return null;
    var rendered = normalizeText(markdown);
    if (links.some(function(link) {
      var linkMarkdown = normalizeText(markdownFor(visibilityPrunedClone(link, document).outerHTML));
      return !linkMarkdown || rendered.indexOf(linkMarkdown) === -1;
    })) return null;
    var missingMaterial = Array.from(root.querySelectorAll("p, blockquote, pre, table, div")).some(function(node) {
      if (elementSubtreeHidden(node) || node.closest(chrome)) return false;
      if (node.tagName === "DIV" && !listInlineDescriptionNode(node)) return false;
      var material = normalizeText(markdownFor(visibilityPrunedClone(node, document).outerHTML));
      return material && rendered.indexOf(material) === -1;
    });
    if (missingMaterial) return null;
    var missingMedia = Array.from(root.querySelectorAll("img[src], video[src], audio[src], iframe[src], source[src]")).some(function(node) {
      if (elementSubtreeHidden(node) || node.closest(chrome)) return false;
      var url = materializedHttpUrl(node.getAttribute("src"));
      return url && markdown.indexOf(url) === -1;
    });
    if (missingMedia) return null;
    return { namedSectionCount: 0, canonicalCardCount: cards.size, completeRecordCoverage: true };
  }

  function credibleHomepageListFeed(content, markdown, body, page) {
    if (!content || content.contentType === "search") return false;

    var path = (location.pathname || "/").toLowerCase();
    var rootPage = homepageRootPath();
    var listPath = rootPage || (typeof likelyListPath === "function" && likelyListPath());
    var listLinks = (markdown.match(/\[[^\]]+\]\([^)]+\)/g) || []).length;
    var editorialSections = typeof homepageHasEditorialSections === "function" && homepageHasEditorialSections(document);
    var portalRoot = !!content.portalRootEvidence;
    var accessWall = consentWallDominates(body) || consentWallDominates(page);

    if (accessWall || notFoundInterstitialEvidence(content.title || "", body, { maxTextLength: 1100 })) return false;

    if (content.contentType === "list") {
      return (listPath && editorialSections) || portalRoot ||
        (rootPage && completePrimaryHeadlineCollection(content, markdown));
    }

    if (content.contentType !== "social" || content.socialKind !== "feed" ||
        (!content.hostAware && !content.structuralSocialFeed)) return false;
    if (!rootPage && !/^\/(?:tag|tags|topic|topics|category|categories|feed|feeds|latest|headlines|news)(?:\/|$)/.test(path)) return false;
    return content.itemCount >= 3 && listLinks >= 3;
  }

  function credibleDocsIndexReferenceList(metadata, content, markdown, body) {
    if (!content || (content.contentType !== "article" && content.contentType !== "list")) return false;
    if (content.contentType === "search" || content.contentType === "press_release" ||
        content.contentType === "social" || content.packagePage || content.isolatedLiveblogEntry) return false;
    if (normalizeText(content.byline || metadata.byline || visibleByline() || "") ||
        normalizeText(content.publishedTime || metadata.publishedTime || visiblePublishedTime(content) || "")) return false;

    var text = normalizeText(markdown || body || "");
    var title = normalizeText((content.title || metadata.title || "")).toLowerCase();
    var site = normalizeText((content.siteName || metadata.siteName || location.hostname || "")).toLowerCase();
    var path = ((location.hostname || "") + " " + (location.pathname || "") + " " + (metadata.canonicalUrl || "")).toLowerCase();
    if (!text || text.length < 250 || consentWallDominates(text) ||
        notFoundInterstitialEvidence(title, text, { maxTextLength: 1400 })) return false;

    var indexShape = /(^\/$|\/(?:index(?:\.html?)?|docs?|documentation|reference|api|manual|guides?|tutorials?|standard[_-]?library|stdlib|language|methods)(?:\/|$))/i.test(path);
    if (!indexShape) return false;

    var signals = 0;
    if (/(?:^|[\s/.-])(?:docs?|documentation|reference|api|manual|guide|tutorial|standard[_-]?library|stdlib)(?:[\s/.-]|$)/i.test(path)) {
      signals += 1;
    }
    if (/(?:documentation|docs|reference|api|manual|guide|tutorial|standard library)/i.test(title + " " + site)) {
      signals += 1;
    }
    var generator = normalizeText(firstText(["meta[name='generator']"], "content") || "");
    if (/(?:docusaurus|sphinx|jekyll|hugo|mkdocs|docs|documentation|reference)/i.test(generator)) {
      signals += 1;
    }
    if (/(?:classes and modules|standard library documentation|language|reference|api|tutorial|guides?)/i.test(text)) {
      signals += 1;
    }
    if (signals < 2) return false;

    var resourceLinks = {};
    var resourceLinkCount = 0;
    var linkPattern = /\[([^\]]+)\]\(([^)]+)\)/g;
    var match;
    while ((match = linkPattern.exec(text))) {
      var resourceText = match[1] + " " + match[2];
      if (/(?:docs?|documentation|reference|api|manual|guide|tutorial|standard[_-]?library|stdlib|language|method|class|module|contribut|getting started)/i.test(resourceText) &&
          !resourceLinks[match[2]]) {
        resourceLinks[match[2]] = true;
        resourceLinkCount += 1;
      }
    }
    return resourceLinkCount >= 4;
  }
