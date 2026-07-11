  function rustdocContent(metadata, info) {
    info = info || docsSystemInfo(metadata);
    if (!info || info.system !== "rustdoc") return null;

    var node = firstMatchingNode(["main", ".rustdoc", "body"]);
    return docsContentForNode(metadata, node, {
      titleSelectors: ["main h1", ".rustdoc h1", "h1"],
      fallbackTitle: function() { return metadata.title || document.title; },
      titleFormatter: function(title) {
        return title.replace(/\s+copy item path$/i, "");
      },
      postProcessMarkdown: function(markdown) {
        var examples = Array.prototype.slice.call(node.querySelectorAll("pre")).map(function(pre) {
          return cleanCodeText(pre.textContent);
        }).filter(Boolean);
        examples.forEach(function(example) {
          var lines = example.split("\n").filter(Boolean);
          var lastLine = lines[lines.length - 1];
          if (!lastLine || markdown.indexOf(example) !== -1) return;
          var block = new RegExp("\\n*```[^\\n]*\\n[\\s\\S]*?" + escapeRegex(lastLine) + "\\n```", "g");
          markdown = markdown.replace(block, "");
          markdown = [markdown.trim(), fencedCodeBlock("", example).trim()].filter(Boolean).join("\n\n");
        });
        return markdown;
      },
      rewriteRoot: function(root) {
        root.querySelectorAll("nav, #sidebar, .sidebar, .sub-sidebar-menu, #settings, #help-button, #crate-search, .mobile-topbar, .sidebar-elems, .out-of-band").forEach(function(el) {
          el.remove();
        });
        removeNodesByText(root, "a, button, div, span, p", /^(search|settings|help|copy item path|expand description|show sidebar|hide sidebar|toggle sidebar|source|collapse all|expand all)$/i);
        root.querySelectorAll("a[href]").forEach(function(el) {
          var title = normalizeText(el.getAttribute("title"));
          var text = normalizeText(el.textContent);
          if (/show sidebar|hide sidebar|toggle sidebar/i.test(title) || /^(search|settings|help|source|§)$/i.test(text)) el.remove();
        });
        // Strip srclink/source anchors
        root.querySelectorAll("a.srclink, a.src, a[class*='srclink']").forEach(function(el) {
          el.remove();
        });
        root.querySelectorAll(".example-wrap, .example, [class*='example']").forEach(function(example) {
          example.querySelectorAll("a[href], button").forEach(function(control) {
            var href = control.getAttribute("href") || "";
            var text = normalizeText(control.textContent);
            if (/play\.rust-lang\.org|rustdoc\.test/i.test(href) || /^(run|play)$/i.test(text)) control.remove();
          });
          removeNodesByText(example, "p, span", /^see\s*\.?$/i);
        });
        root.querySelectorAll("h1, h2, h3, h4").forEach(function(el) {
          el.textContent = normalizeText(el.textContent).replace(/\s+copy item path$/i, "").replace(/^§\s*/, "");
        });
      }
    });
  }

  function javadocContent(metadata, info) {
    info = info || docsSystemInfo(metadata);
    if (!info || info.system !== "javadoc") return null;

    return docsContentBySelectors(metadata, ["main", ".contentContainer", "body"], {
      titleSelectors: ["main h1", ".header h1", "h1"],
      fallbackTitle: function() { return metadata.title || document.title; },
      rewriteRoot: function(root) {
        root.querySelectorAll("nav, header, footer, .top-nav, .sub-nav, .skip-nav, .search-spec, .nav-list, .header, .footer").forEach(function(el) {
          el.remove();
        });
        removeNodesByText(root, "a, button, span", /^(skip navigation|search|module|package|class|use|tree|deprecated|index|help)$/i);
        cleanDocsHeadings(root);
      }
    });
  }

  function dartdocContent(metadata, info) {
    info = info || docsSystemInfo(metadata);
    if (!info || info.system !== "dartdoc") return null;

    var title = cleanDocsHeadingText(firstText(["#dartdoc-main-content h1", "main h1", "h1"]) || metadata.title || document.title);
    var intro = firstText(["#dartdoc-main-content .desc p", "main .desc p", "main p"]);
    var items = [];

    document.querySelectorAll("section.summary dl dt").forEach(function(term) {
      var link = term.querySelector(".name a[href], a[href]");
      if (!link) return;
      var name = normalizeText(link.textContent);
      var href = absoluteUrl(link.getAttribute("href"));
      var descriptionNode = term.nextElementSibling && term.nextElementSibling.tagName && term.nextElementSibling.tagName.toLowerCase() === "dd" ? term.nextElementSibling : null;
      var description = normalizeText(descriptionNode && descriptionNode.textContent);
      if (!name || !href) return;
      items.push({ title: name, href: href, description: description });
    });

    if (items.length < 4) return null;

    var sections = ["# " + (title || "API Reference")];
    if (intro) sections.push(intro);
    sections.push("## Libraries\n\n" + items.map(function(item) {
      return "- [" + item.title + "](" + item.href + ")" + (item.description ? " - " + item.description : "");
    }).join("\n"));

    var markdown = cleanupMarkdownNoise(sections.join("\n\n"));
    return {
      title: title || metadata.title || document.title,
      byline: null,
      excerpt: intro || items[0].description || null,
      siteName: metadata.siteName || location.hostname,
      publishedTime: null,
      html: (document.querySelector("#dartdoc-main-content") || document.querySelector("main") || document.body).innerHTML,
      markdown: markdown,
      textContent: normalizeText(markdown),
      docsLike: true,
      readerMode: false,
      contentType: "article"
    };
  }

  function goPkgDocsSystemContent(metadata, info) {
    info = info || docsSystemInfo(metadata);
    if (!info || info.system !== "go_pkg") return null;

    var node = firstMatchingNode(["#main-content", "main", "body"]);
    return docsContentForNode(metadata, node, {
      titleSelectors: ["#main-content h1", "main h1", "h1"],
      fallbackTitle: function() { return metadata.title || document.title; },
      titleFormatter: function(title) {
        return title.replace(/\s*-\s*Go Packages$/i, "");
      },
      rewriteRoot: function(root) {
        root.querySelectorAll("header, nav, aside, footer, .go-Header, .go-MainHeader, .go-LeftNav, .go-DetailsHeader, .go-Main-aside").forEach(function(el) {
          el.remove();
        });
        removeNodesByText(root, "div, p, span, a, button", /^(jump to \.\.\.|documentation|details|repository|links|versions|licenses|imports|imported by)$/i);
      }
    });
  }
