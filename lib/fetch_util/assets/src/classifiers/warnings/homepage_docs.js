  function credibleHomepageListFeed(content, markdown, body, page) {
    if (!content || content.contentType === "search") return false;

    var path = (location.pathname || "/").toLowerCase();
    var rootPage = homepageRootPath();
    var listPath = rootPage || (typeof likelyListPath === "function" && likelyListPath());
    var listLinks = (markdown.match(/\[[^\]]+\]\([^)]+\)/g) || []).length;
    var editorialSections = typeof homepageHasEditorialSections === "function" && homepageHasEditorialSections(document);
    var accessWall = consentWallDominates(body) || consentWallDominates(page);

    if (accessWall || notFoundInterstitialEvidence(content.title || "", body, { maxTextLength: 1100 })) return false;

    if (content.contentType === "list") {
      return listPath && editorialSections;
    }

    if (content.contentType !== "social" || content.socialKind !== "feed" || !content.hostAware) return false;
    if (!rootPage && !/^\/(?:tag|tags|topic|topics|category|categories|feed|feeds|latest|headlines|news)(?:\/|$)/.test(path)) return false;
    return content.itemCount >= 3 && listLinks >= 3;
  }

  function credibleDocsIndexReferenceList(metadata, content, markdown, body) {
    if (!content || (content.contentType !== "article" && content.contentType !== "list")) return false;
    if (content.contentType === "search" || content.contentType === "press_release" ||
        content.contentType === "social" || content.packagePage || content.isolatedLiveblogEntry) return false;
    if (normalizeText(content.byline || metadata.byline || visibleByline() || "") ||
        normalizeText(content.publishedTime || metadata.publishedTime || visiblePublishedTime() || "")) return false;

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
