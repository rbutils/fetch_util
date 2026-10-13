  function physicalNumberedInstrumentContext(metadata) {
    var family = /\b(?:convention|treaty|charter|covenant|statute)\b/i;
    if (!family.test(document.title || "")) return null;
    var pageUrl = focalCanonicalUrl(location.href);
    var canonical = document.querySelector("link[rel~='canonical' i]");
    var ogUrl = document.querySelector("meta[property='og:url' i]");
    if ((canonical && focalCanonicalUrl(canonical.getAttribute("href")) !== pageUrl) ||
        (ogUrl && focalCanonicalUrl(ogUrl.getAttribute("content")) !== pageUrl)) return null;
    var ogType = document.querySelector("meta[property='og:type' i]");
    if (ogType && /article|blogposting/i.test(ogType.getAttribute("content") || "")) return null;
    if (structuredDataNodes().some(function(node) {
      return nodeTypes(node).some(function(type) { return /^(?:NewsArticle|ReportageNewsArticle|BlogPosting|Article)$/.test(type); });
    })) return null;

    var roots = document.querySelectorAll("main, [role='main']");
    if (roots.length !== 1) return null;
    var root = roots[0];
    var headings = root.querySelectorAll("h1");
    if (headings.length !== 1) return null;
    var heading = headings[0];
    var title = cleanDocsHeadingText(heading.textContent);
    if (!family.test(title)) return null;
    var titles = [document.title, metadata && metadata.title].concat(Array.from(
      document.querySelectorAll("meta[property='og:title' i]"), function(node) { return node.getAttribute("content"); }
    )).map(function(value) { return normalizeText(value || ""); }).filter(Boolean);
    if (!titles.length || !titles.every(function(value) {
      return value === title || (value.indexOf(title) === 0 && /^(?:-|\||\u2013|\u2014)\s+\S/.test(normalizeText(value.slice(title.length))));
    })) return null;
    var article = heading.closest("article");
    if (!article || !root.contains(article)) return null;
    var articles = Array.from(root.querySelectorAll("article")).filter(function(node) {
      return !commentRecordMarker(node) && !node.closest(VISIBLE_COMMENT_THREAD_SELECTOR);
    });
    if (articles.length !== 1 || articles[0] !== article) return null;
    if (article.querySelector("[itemprop~='author' i], [rel~='author' i], [itemprop~='datePublished' i]")) return null;
    if (elementSubtreeHidden(root) || elementSubtreeHidden(heading) || elementSubtreeHidden(article) ||
        physicalTechnicalOwnerChrome(root, root) || physicalTechnicalOwnerChrome(heading, root)) return null;

    var labels = Array.from(article.querySelectorAll("h2, h3, h4, h5, h6")).filter(function(node) {
      return /^Article\s+[1-9]\d*$/i.test(normalizeText(node.textContent || "")) &&
        node.closest("article") === article && !physicalTechnicalOwnerChrome(node, root) && !elementSubtreeHidden(node);
    });
    if (labels.length < 2 || !labels.every(function(node, index) {
      return Number(normalizeText(node.textContent).match(/\d+$/)[0]) === index + 1 &&
        node.parentElement === labels[0].parentElement &&
        !!(heading.compareDocumentPosition(node) & Node.DOCUMENT_POSITION_FOLLOWING);
    })) return null;
    var provisions = Array.from(article.querySelectorAll("p")).filter(function(node) {
      return node.closest("article") === article && !physicalTechnicalOwnerChrome(node, root) && !elementSubtreeHidden(node) &&
        normalizeText(node.textContent || "");
    });
    if (!provisions.length || !labels.every(function(label, index) {
      return provisions.some(function(provision) {
        return !!(label.compareDocumentPosition(provision) & Node.DOCUMENT_POSITION_FOLLOWING) &&
          (!labels[index + 1] || !!(provision.compareDocumentPosition(labels[index + 1]) & Node.DOCUMENT_POSITION_FOLLOWING));
      });
    })) return null;
    return { root: root, title: title };
  }

  function physicalNumberedInstrumentContent(metadata) {
    var context = physicalNumberedInstrumentContext(metadata);
    if (!context) return null;
    var content = docsContentForNode(metadata, context.root, {
      title: context.title, hostAware: false, focusFragment: false,
      pruneSourceVisibility: true, preserveAuthoredSections: true, preserveCleanedRoot: true
    });
    if (content) {
      content.sourceOwnedNumberedInstrument = true;
      content.sourceOwnedGeneratedDocs = true;
      content.byline = null;
      content.publishedTime = null;
    }
    return content;
  }

  function physicalReferenceContent(metadata) {
    return physicalDataRecordContent(metadata) || physicalNumberedInstrumentContent(metadata);
  }
