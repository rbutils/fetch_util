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

    var root = visibilityPrunedClone(document.body, document);
    preserveProjectReleaseNotes(root);
    root = cleanClone(root);
    root.querySelectorAll("div, section").forEach(function(node) {
      if (!listNavigationNode(node)) return;
      var labels = node.cloneNode(true);
      labels.querySelectorAll("a, img, svg").forEach(function(link) { link.remove(); });
      if (!normalizeText(labels.textContent)) node.remove();
    });
    var heading = root.querySelector("h1, h2");
    var prose = Array.prototype.map.call(root.querySelectorAll("p, li, dd, dt, div"), function(paragraph) {
      if (paragraph.closest("nav, footer, aside, [role='navigation']")) return "";
      if (paragraph.tagName === "DIV" && !paragraphLikeDiv(paragraph)) return "";
      return normalizeText(paragraph.textContent);
    }).join(" ");
    var softwareIdentity = /\b(?:programming language|compiler|runtime|framework|librar(?:y|ies)|database|web server|static[- ](?:web)?sites?|javascript|typescript|ruby|python|open.source|developer tool)\b/i;
    var title = normalizeText([metadata && metadata.title, document.title, heading && heading.textContent].join(" "));
    if (!repositories.size && documentation.size < 2) return null;
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

  function projectReleaseNotesLink(link) {
    var href = materializedHttpUrl(link.getAttribute("href"));
    if (!href) return false;
    return /\b(?:release notes?|changelog)\b/i.test(normalizeText(link.textContent)) ||
      /\/(?:release[-_]notes|changelog|releases\/tag)(?:[/._-]|$)/i.test(new URL(href).pathname);
  }

  function preserveProjectReleaseNotes(root) {
    root.querySelectorAll("footer, [role='contentinfo']").forEach(function(footer) {
      var records = [];
      footer.querySelectorAll("a[href]").forEach(function(link) {
        if (!projectReleaseNotesLink(link)) return;
        var owner = link.parentElement;
        while (owner && owner !== footer) {
          var text = normalizeText(owner.textContent);
          var version = /\bv?\d+\.\d+(?:\.\d+)?\b/.test(text);
          var release = /\b(?:release[ds]?|version)\b/i.test(text);
          var linksOwned = Array.prototype.every.call(owner.querySelectorAll("a[href]"), function(reference) {
            return projectReleaseNotesLink(reference) ||
              (materializedHttpUrl(reference.getAttribute("href")) && /^v?\d+\.\d+(?:\.\d+)?$/i.test(normalizeText(reference.textContent)));
          });
          if (owner.matches("p, div, section, li") && version && release && linksOwned &&
              !/copyright|©|privacy policy|all rights reserved/i.test(text) && !owner.querySelector("nav, form, button, input")) {
            if (!records.some(function(record) { return record.contains(owner); })) {
              records = records.filter(function(record) { return !owner.contains(record); });
              records.push(owner);
            }
            break;
          }
          owner = owner.parentElement;
        }
      });
      var replacement = document.createDocumentFragment();
      records.forEach(function(record) {
        var section = document.createElement("section");
        while (record.firstChild) section.appendChild(record.firstChild);
        replacement.appendChild(section);
      });
      footer.replaceWith(replacement);
    });
  }
