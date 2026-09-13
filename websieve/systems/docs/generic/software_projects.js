  function softwareProjectHomepageContent(metadata) {
    if (!document.body) return null;
    var path = location.pathname.replace(/\/$/, "");
    if (!homepageRootPath() && !/^\/(?:[a-z]{2}(?:-[a-z]{2})?|v?\d+(?:\.\d+)*)$/i.test(path)) return null;
    if (document.querySelector("article h1") && (visibleByline() || visiblePublishedTime())) return null;

    var repositories = new Set();
    var documentation = new Set();
    document.querySelectorAll("a[href]").forEach(function(link) {
      var href = materializedHttpUrl(link.getAttribute("href"));
      if (!href || elementSubtreeHidden(link)) return;
      var url = new URL(href);
      if (/^(?:www\.)?(?:github\.com|gitlab\.com|codeberg\.org)$/.test(url.hostname) &&
          /^\/[^/]+\/[^/]+/.test(url.pathname)) repositories.add(url.origin + url.pathname);
      var label = normalizeText(link.textContent || link.getAttribute("aria-label"));
      if (/^(?:source(?: code)?|git repository)$/i.test(label)) repositories.add(url.href);
      if (/^(?:documentation|docs|api(?: reference)?|get(?:ting)? started|installation|install|download|tutorial|quick ?start)\b/i.test(label)) {
        documentation.add(url.href);
      }
    });
    if (!documentation.size) return null;

    var root = cleanClone(visibilityPrunedClone(document.body, document));
    var heading = root.querySelector("h1, h2");
    var prose = Array.prototype.map.call(root.querySelectorAll("p"), function(paragraph) {
      return paragraph.closest("nav, footer, aside") ? "" : normalizeText(paragraph.textContent);
    }).join(" ");
    var softwareIdentity = /\b(?:programming language|compiler|runtime|framework|librar(?:y|ies)|database|web server|static[- ](?:web)?sites?|javascript|typescript|ruby|python|open.source|developer tool)\b/i;
    var title = normalizeText([metadata && metadata.title, document.title, heading && heading.textContent].join(" "));
    if (!repositories.size && !(documentation.size >= 2 && softwareIdentity.test(title))) return null;
    if (!softwareIdentity.test(title + " " + prose)) return null;
    if (prose.length < 80) return null;

    // A project's overview is itself documentation. Its feature descriptions,
    // examples, release notes and resource lists share one page-level owner.
    // Preserve their DOM order rather than treating every destination as a card.
    root.querySelectorAll("header").forEach(function(header) {
      if (header.querySelector("h1, h2, h3, p, pre")) {
        var section = document.createElement("section");
        while (header.firstChild) section.appendChild(header.firstChild);
        header.replaceWith(section);
      } else header.remove();
    });
    root.querySelectorAll("[role='navigation'], [role='menubar'], [role='menu'], [role='toolbar'], [role='contentinfo']").forEach(function(node) {
      node.remove();
    });
    var article = document.createElement("article");
    article.setAttribute("data-fetchutil-page-overview", "true");
    while (root.firstChild) article.appendChild(root.firstChild);
    cleanupAgentRoot(article);
    if (normalizeText(article.textContent).length < 80) return null;

    return {
      title: metadata && metadata.title || document.title,
      byline: null,
      excerpt: metadata && metadata.excerpt,
      siteName: metadata && metadata.siteName || location.hostname,
      publishedTime: null,
      html: article.outerHTML,
      textContent: normalizeText(article.textContent),
      contentType: "article",
      readerMode: false,
      docsLike: true
    };
  }
