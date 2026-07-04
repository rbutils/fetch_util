  function packagePathName() {
    var parts = (location.pathname || "").split("/").filter(Boolean);
    if (parts.length < 2) return null;

    if (parts[0] === "project" || parts[0] === "gems" || parts[0] === "package") return parts[1];
    return null;
  }

  function packageMarkdownFromNode(node) {
    if (!node) return null;

    var root = cleanClone(node);
    cleanupAgentRoot(root);
    Array.prototype.slice.call(root.querySelectorAll("script, style, noscript, svg, .sr-only")).forEach(function(el) { el.remove(); });

    var markdown = cleanupMarkdownNoise(markdownFor(root.innerHTML));
    if (!normalizeText(markdown)) return null;

    return {
      html: root.innerHTML,
      markdown: markdown,
      textContent: normalizeText(markdown)
    };
  }

  function packageRegistryTitle(metadata, packageName) {
    var raw = normalizeText(metadata.title || document.title || packageName || "");
    raw = raw.replace(/\s*[|·-]\s*(PyPI|RubyGems\.org|npm).*$/i, "");
    raw = raw.replace(/\s+\|\s+RubyGems\.org\s+\|.*$/i, "");
    return normalizeText(raw) || packageName;
  }

  function packageRegistryContent(metadata) {
    var host = location.hostname || "";
    var packageName = packagePathName();
    if (!packageName) return null;

    var selectors;
    var siteName;
    if (/(^|\.)pypi\.org$/i.test(host) && /^\/project\/[^/]+\/?$/i.test(location.pathname || "")) {
      selectors = ["#description .project-description", "#description", ".project-description"];
      siteName = "PyPI";
    } else if (/(^|\.)rubygems\.org$/i.test(host) && /^\/gems\/[^/]+\/?$/i.test(location.pathname || "")) {
      selectors = ["main", "#markup.gem__desc", ".gem__desc"];
      siteName = "RubyGems.org";
    } else if (/(^|\.)npmjs\.com$/i.test(host) && /^\/package\/[^/]+\/?$/i.test(location.pathname || "")) {
      selectors = ["#readme", "#tabpanel-readme article", "[aria-labelledby='package-tab-readme'] article"];
      siteName = "npm";
    } else {
      return null;
    }

    for (var i = 0; i < selectors.length; i += 1) {
      var node = document.querySelector(selectors[i]);
      var content = packageMarkdownFromNode(node);
      if (!content || content.textContent.length < 80) continue;

      var headingNode = node.querySelector("h1, h2");
      var heading = normalizeText(headingNode && headingNode.textContent);
      var title = heading && heading.toLowerCase().indexOf(packageName.toLowerCase()) === 0 ? heading : packageRegistryTitle(metadata, packageName);
      var markdown = content.markdown;
      if (title && !markdownStartsWithTitle(markdown, title)) markdown = "# " + title + "\n\n" + markdown;

      return {
        title: title || metadata.title,
        byline: metadata.byline,
        excerpt: metadata.excerpt,
        siteName: metadata.siteName || siteName,
        publishedTime: metadata.publishedTime,
        html: content.html,
        markdown: markdown,
        textContent: normalizeText(markdown),
        hostAware: true,
        packagePage: true,
        readerMode: false,
        contentType: "article"
      };
    }

    return null;
  }
