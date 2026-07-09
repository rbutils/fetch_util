  function packagePathName() {
    var parts = (location.pathname || "").split("/").filter(Boolean);
    if (parts.length < 2) return null;

    if (parts[0] === "project" || parts[0] === "gems" || parts[0] === "package") return parts[1];
    return null;
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
      var headingNode = node.querySelector("h1, h2");
      var heading = normalizeText(headingNode && headingNode.textContent);
      var title = heading && heading.toLowerCase().indexOf(packageName.toLowerCase()) === 0 ? heading : packageRegistryTitle(metadata, packageName);
      var content = profileArticleContent(metadata, node, {
        title: title,
        minTextLength: 80,
        excerpt: metadata.excerpt,
        siteName: metadata.siteName || siteName,
        extra: { packagePage: true },
        rewriteRoot: function(root) {
          Array.prototype.slice.call(root.querySelectorAll("script, style, noscript, svg, .sr-only")).forEach(function(el) { el.remove(); });
        }
      });
      if (content) return content;
    }

    return null;
  }
