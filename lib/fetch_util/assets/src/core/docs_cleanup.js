  function removeNodesByText(root, selector, pattern) {
    root.querySelectorAll(selector).forEach(function(el) {
      var text = normalizeText(el.textContent);
      if (text && pattern.test(text)) el.remove();
    });
  }

  function samePageFragmentLink(href) {
    if (!href) return false;

    var current = location.href.split("#")[0] + "#";
    return href === "#" || href.indexOf("#") === 0 || href.indexOf(current) === 0;
  }

  function tocLikeNode(node) {
    var links = Array.prototype.slice.call(node.querySelectorAll("a[href]"));
    if (links.length < 4 || links.length > 30) return false;

    var fragmentLinks = links.filter(function(link) {
      return samePageFragmentLink(link.getAttribute("href"));
    }).length;
    var text = normalizeText(node.textContent);

    return fragmentLinks >= 4 && fragmentLinks >= Math.ceil(links.length * 0.8) && text.length < 900;
  }

  function breadcrumbLikeNode(node) {
    if (node.closest && node.closest(".landing-card, .card--fullwidth")) return false;

    var links = Array.prototype.slice.call(node.querySelectorAll("a[href]"));
    if (links.length < 2 || links.length > 8) return false;

    var text = normalizeText(node.textContent);
    if (!text || text.length > 220) return false;

    // Real breadcrumbs are flat link+separator chains; content cards with
    // paragraphs, bold text, or headings are NOT breadcrumbs (e.g. GitBook cards)
    if (node.querySelector("p, strong, b, h1, h2, h3, h4, h5, h6")) return false;

    return links.every(function(link) {
      return normalizeText(link.textContent).length > 0 && normalizeText(link.textContent).length < 40;
    });
  }

  function cleanDocsHeadingText(text) {
    return normalizeText((text || "")
      .replace(/[\u200B\u200C\u200D\uFEFF]/g, "")
      // Strip LLM action button text concatenated to titles (Redocly, Fern, GitBook, etc.)
      // These appear as a trailing cluster: "...titleCopyCopy for LLMOpen in ChatGPT..."
      .replace(/\s*(?:Copy\s*(?:for\s+LLMs?|page(?:\s+as\s+Markdown)?(?:\s+for\s+LLMs?)?)|View\s+as\s+Markdown|Open\s+(?:this\s+page\s+as\s+Markdown|in\s+(?:ChatGPT|Claude|Cursor))|Get\s+insights\s+from\s+(?:ChatGPT|Claude)|Connect\s+to\s+Cursor|Ask\s+AI|Download\s+OpenAPI\s+spec(?:ification)?)\s*/gi, "")
    ).replace(/\s+copy item path$/i, "").replace(/[¶#\uF0C1\uF0C6\uF08E\uF14C]+$/, "").replace(/\s*Copy$/i, "");
  }

  function cleanupDocsRoot(root, options) {
    options = options || {};

    removeNodesByText(root, "a, button, span, div, p, li", /^(copy page|copy for llm|copy page as markdown|copy page as markdown for llms?|view as markdown|open this page as markdown|open in (?:chatgpt|claude|cursor)|get insights from (?:chatgpt|claude)|connect to cursor|download openapi spec(?:ification)?|ask about this section|ask ai|copy link|copy permalink|send feedback|edit this page|report feedback|pdf|rss|focus mode|skip to main content|skip to content|copy item path|view source|view on github|report a problem with this content|open menu|open sidebar|search|settings|help|search or ask copilot|expand description|show more|show less|expand|collapse|javascripttypescript|typescriptjavascript)$/i);
    removeNodesByText(root, "h2, h3, h4, h5, p, div, span, li", /^(on this page|in this article|table of contents|last updated.*|api preferences|select language:.*|breadcrumbs?)$/i);

    // Strip "Feedback" sections and "Last modified" / "Was this page helpful?" footers (common in Hugo docs)
    root.querySelectorAll("section, div").forEach(function(el) {
      var text = normalizeText(el.textContent);
      if (!text) return;
      if (/^feedback\b/i.test(text) && text.length < 500 && el.querySelectorAll("a, button").length >= 1) {
        el.remove();
        return;
      }
      if (/^(was this page helpful|is this page helpful)\??$/i.test(text.split("\n")[0]) && text.length < 300) {
        el.remove();
        return;
      }
    });
    removeNodesByText(root, "p, div, span", /^last modified\s/i);

    // Strip newsletter / subscribe footer sections (common in docs sites like Bring, etc.)
    root.querySelectorAll("section, div, aside, form").forEach(function(el) {
      var text = normalizeText(el.textContent);
      if (!text) return;
      var heading = el.querySelector("h2, h3, h4");
      if (heading && /^(subscribe|newsletter|stay up[- ]to[- ]date|get (?:the )?latest|sign up for (?:our )?(?:newsletter|updates)|mailing list)$/i.test(normalizeText(heading.textContent)) && text.length < 800) {
        el.remove();
        return;
      }
    });
    removeNodesByText(root, "p, div, span, a", /^(privacy\s*policy|terms\s+(?:of\s+(?:service|use)|and\s+conditions)|powered by [a-z]+)$/i);

    root.querySelectorAll("h1, h2, h3, h4, h5, h6").forEach(function(el) {
      var text = cleanDocsHeadingText(el.textContent);
      if (text) el.textContent = text;
    });

    root.querySelectorAll("nav, [aria-label*='breadcrumb' i], ol[aria-label*='breadcrumb' i]").forEach(function(el) {
      el.remove();
    });

    root.querySelectorAll("a[href]").forEach(function(el) {
      var text = normalizeText(el.textContent);
      var title = normalizeText(el.getAttribute("title"));
      if (el.closest("h1, h2, h3, h4, h5, h6") && text.length >= 8) return;
      if (samePageFragmentLink(el.getAttribute("href")) && (!text || text.length < 40 || /link for this heading/i.test(title) || /^skip to (?:main )?content$/i.test(text))) el.remove();
    });

    root.querySelectorAll("section, div, ul, ol").forEach(function(el) {
      var text = normalizeText(el.textContent);
      if (!text) return;
      if (/^on this page\b/i.test(text) && text.length < 1200) {
        el.remove();
        return;
      }
      if (tocLikeNode(el) || breadcrumbLikeNode(el)) el.remove();
    });

    if (options.removeTryIt) {
      root.querySelectorAll("section, div").forEach(function(el) {
        var text = normalizeText(el.textContent);
        var heading = el.querySelector("h2, h3, h4");
        if ((heading && /^try it$/i.test(normalizeText(heading.textContent))) || (/^try it\b/i.test(text) && text.length < 600)) el.remove();
      });
      removeNodesByText(root, "h2, h3, h4", /^try it$/i);
    }

    if (options.removeCookiePrefs) {
      removeNodesByText(root, "h1, h2, h3, p, div, span", /^(select your cookie preferences|customize cookie preferences|unable to save cookie preferences)$/i);
    }

    if (options.removeMarketingTips) {
      root.querySelectorAll("section, div, aside").forEach(function(el) {
        var text = normalizeText(el.textContent);
        if (/\b(tip|note)\b/i.test(text) && /(workshop|builder center|sign up|training|studio)/i.test(text) && text.length < 600) {
          el.remove();
        }
      });
    }

    return root;
  }

  function firstRootText(root, selectors) {
    for (var i = 0; i < selectors.length; i += 1) {
      var nodes = root.querySelectorAll(selectors[i]);
      for (var j = 0; j < nodes.length; j += 1) {
        var text = normalizeText(nodes[j].textContent);
        if (text) return text;
      }
    }

    return null;
  }

  function docsScopedDescendants(root, selector, boundarySelector) {
    return Array.prototype.slice.call(root.querySelectorAll(selector)).filter(function(node) {
      var current = node.parentElement;

      while (current && current !== root) {
        if (current.matches && current.matches(boundarySelector)) return false;
        current = current.parentElement;
      }

      return true;
    });
  }

  function docsScopedFirstText(root, selectors, boundarySelector) {
    for (var i = 0; i < selectors.length; i += 1) {
      var nodes = docsScopedDescendants(root, selectors[i], boundarySelector);
      for (var j = 0; j < nodes.length; j += 1) {
        var text = normalizeText(nodes[j].textContent);
        if (text) return text;
      }
    }

    return "";
  }

  function firstMatchingNode(selectors) {
    for (var i = 0; i < selectors.length; i += 1) {
      var node = document.querySelector(selectors[i]);
      if (node) return node;
    }

    return null;
  }

  function docsHostSignature(metadata) {
    return normalizeText([location.hostname, metadata && metadata.siteName, metadata && metadata.title, document.title].join(" "));
  }

  function formatDocsTitle(title, formatter, metadata) {
    if (!title) return null;
    if (typeof formatter === "function") title = formatter(title, metadata);
    return cleanDocsHeadingText(title || "") || null;
  }

  function docsTitleText(metadata, selectors, fallbackTitle, formatter) {
    var title = firstText(selectors || []);
    if (!title && typeof fallbackTitle === "function") title = fallbackTitle(metadata);
    if (!title && typeof fallbackTitle === "string") title = fallbackTitle;
    return formatDocsTitle(title, formatter, metadata);
  }

  function cleanDocsHeadings(root, selector, formatter) {
    selector = selector || "h1, h2, h3, h4, h5, h6";
    formatter = formatter || function(text) { return cleanDocsHeadingText(text); };

    root.querySelectorAll(selector).forEach(function(el) {
      var text = formatter(el.textContent, el);
      if (text) el.textContent = text;
    });
  }

  function docsContentBySelectors(metadata, selectors, options) {
    var node = firstMatchingNode(selectors);
    return docsContentForNode(metadata, node, options);
  }

  function docsContentForNode(metadata, node, options) {
    options = options || {};
    if (!node) return null;

    var articleOptions = {};
    Object.keys(options).forEach(function(key) {
      if (key === "titleSelectors" || key === "fallbackTitle" || key === "preferFragmentTitle" || key === "titleFormatter") return;
      articleOptions[key] = options[key];
    });

    if (!articleOptions.title && (options.titleSelectors || options.fallbackTitle)) {
      var title = options.preferFragmentTitle === false ? null : docsFragmentTitle(node);
      title = formatDocsTitle(title, options.titleFormatter, metadata) ||
        docsTitleText(metadata, options.titleSelectors, options.fallbackTitle, options.titleFormatter);
      articleOptions.title = title;
    }

    return docsArticleContent(metadata, node, articleOptions);
  }

  function docsNamedAnchorTarget(name) {
    if (!name) return null;

    var anchors = document.querySelectorAll("a[name]");
    for (var i = 0; i < anchors.length; i += 1) {
      if ((anchors[i].getAttribute("name") || "") === name) return anchors[i];
    }

    return null;
  }

  function docsFragmentTarget(root) {
    var id = safeDecodeURI((location.hash || "").replace(/^#/, "")).trim();
    if (!id) return null;

    var target = document.getElementById(id) || docsNamedAnchorTarget(id);
    if (!target) return null;
    if (root !== target && !root.contains(target)) return null;
    return target;
  }

  function focusedDocsNode(root) {
    var target = docsFragmentTarget(root);
    if (!target) return root;

    var candidate = target;
    while (candidate && candidate !== root) {
      var text = normalizeText(candidate.textContent);
      if (/^(section|article|div|li|dt|dd|main)$/i.test(candidate.tagName || "") && text.length >= 20) return candidate;
      candidate = candidate.parentElement;
    }

    return target;
  }

  function docsFragmentTitle(root) {
    var target = docsFragmentTarget(root);
    if (!target) return null;

    var heading = target.matches && target.matches("h1, h2, h3, h4, h5, h6") ? target : target.querySelector("h1, h2, h3, h4, h5, h6");
    if (!heading && target.matches && target.matches("a[name]")) heading = target.nextElementSibling;
    var text = cleanDocsHeadingText((heading || target).textContent);
    return text || null;
  }

  function markdownStartsWithTitle(markdown, title) {
    title = normalizeText(title).replace(/[`*_]/g, "");
    if (!title) return false;
    var titleLower = normalizeText(title).toLowerCase();
    var candidates = (markdown || "").split("\n").slice(0, 8).map(function(line) {
      return normalizeText(line).replace(/^#+\s*/, "").replace(/^\[([^\]]+)\]\([^)]*\)$/, "$1").replace(/[`*_]/g, "");
    }).filter(Boolean);
    return candidates.some(function(line) {
      var lineLower = normalizeText(line).toLowerCase();
      return lineLower === titleLower || lineLower.indexOf(titleLower) === 0;
    });
  }

  function docsArticleContent(metadata, node, options) {
    if (!node) return null;

    options = options || {};
    var sourceNode = options.focusFragment === false ? node : focusedDocsNode(node);
    var root = cleanClone(sourceNode);

    cleanupAgentRoot(root);

    cleanupDocsRoot(root, options);

    if (typeof options.rewriteRoot === "function") {
      try {
        options.rewriteRoot(root);
      } catch(e) {
      }
    }

    var markdown;
    try {
      markdown = markdownFor(root.innerHTML).trim();
    } catch(e) {
      markdown = "";
    }
    if (typeof options.postProcessMarkdown === "function") markdown = options.postProcessMarkdown(markdown, root);
    var title = cleanDocsHeadingText(options.title || docsFragmentTitle(node) || firstRootText(root, ["h1", "header h1", "h2"]) || "") || null;
    var description = options.description || firstRootText(root, ["p"]);

    if (!markdown) {
      if (!title && !description) return null;

      return articleContentFromParts({
        title: title || metadata.title,
        description: description || metadata.excerpt,
        siteName: metadata.siteName || location.hostname,
        docsLike: true,
        hostAware: options.hostAware !== false
      });
    }

    if (title && !markdownStartsWithTitle(markdown, title)) markdown = "# " + title + "\n\n" + markdown;

    return {
      title: title || metadata.title,
      byline: metadata.byline,
      excerpt: description || metadata.excerpt,
      siteName: metadata.siteName || location.hostname,
      publishedTime: metadata.publishedTime,
      html: root.innerHTML,
      markdown: markdown,
      textContent: normalizeText(markdown),
      docsLike: true,
      hostAware: options.hostAware !== false,
      readerMode: false,
      contentType: options.contentType || "article"
    };
  }

  function compactReferenceText(text) {
    return normalizeText(text || "")
      .replace(/([a-z0-9])((?:Default:|Can be one of:|For more information:|Example:|Required))/g, "$1 $2")
      .replace(/([a-z])([A-Z][a-z])/g, "$1 $2");
  }
