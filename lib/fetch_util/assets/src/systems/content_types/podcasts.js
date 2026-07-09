  function podcastEpisodeNode() {
    return structuredDataNodes().find(function(node) {
      return nodeTypes(node).some(function(type) {
        return /(?:^|\/)PodcastEpisode$/i.test(type);
      });
    }) || null;
  }

  function podcastEpisodeTitle(podcast, metadata) {
    var structuredTitle = entityText(podcast && (podcast.name || podcast.headline || podcast.title));
    var visibleTitle = firstText(["main h1", "article h1", "h1"]);
    var metadataTitle = normalizeText(metadata && metadata.title);
    var siteName = normalizeText(metadata && metadata.siteName);

    if (visibleTitle && visibleTitle.toLowerCase() !== siteName.toLowerCase()) return visibleTitle;
    if (structuredTitle && structuredTitle.toLowerCase() !== siteName.toLowerCase()) return structuredTitle;
    if (metadataTitle && metadataTitle.toLowerCase() !== siteName.toLowerCase()) return metadataTitle;
    return visibleTitle || structuredTitle || metadataTitle || document.title;
  }

  function podcastRoot() {
    var selectors = [
      "article",
      "main",
      "[role='main']",
      ".episode-content",
      ".episode__content",
      ".podcast-episode",
      ".entry-content",
      ".post-content",
      "#content"
    ];

    var best = null;
    var bestLength = 0;
    selectors.forEach(function(selector) {
      document.querySelectorAll(selector).forEach(function(node) {
        var length = textLength(node);
        if (length > bestLength) {
          best = node;
          bestLength = length;
        }
      });
    });

    return best || document.body;
  }

  function podcastCleanupClone(root) {
    var clone = cleanClone(root || document.body);
    cleanupAgentRoot(clone);
    removeAll(clone, [
      "header",
      "nav",
      "footer",
      "aside",
      "form",
      "script",
      "style",
      "noscript",
      "[role='navigation']",
      "[role='banner']",
      "[role='contentinfo']",
      "[class*='menu' i]",
      "[class*='navbar' i]",
      "[class*='share' i]",
      "[class*='social' i]",
      "[class*='newsletter' i]",
      "[class*='subscribe' i]",
      "[id*='newsletter' i]",
      "[id*='subscribe' i]"
    ].join(", "));
    return clone;
  }

  function podcastTranscriptMarkdown(root) {
    var parts = [];
    var seen = {};

    function addMarkdown(label, markdown) {
      markdown = cleanupMarkdownNoise(markdown || "");
      var text = normalizeText(markdown);
      if (!text || seen[text]) return;
      seen[text] = true;
      parts.push("## " + label + "\n\n" + markdown);
    }

    root.querySelectorAll("details").forEach(function(details) {
      var summaryText = normalizeText(((details.querySelector("summary") || {}).textContent) || "");
      var text = normalizeText(details.textContent || "");
      if (!/\b(transcript|transcription)\b/i.test(summaryText + " " + text.slice(0, 240))) return;
      var clone = podcastCleanupClone(details);
      addMarkdown("Transcript", markdownFor(clone.innerHTML));
    });

    root.querySelectorAll("[id*='transcript' i], [class*='transcript' i], [aria-label*='transcript' i]").forEach(function(node) {
      if (node.closest("nav, header, footer, aside")) return;
      if (textLength(node) < 80) return;
      var clone = podcastCleanupClone(node);
      addMarkdown("Transcript", markdownFor(clone.innerHTML));
    });

    root.querySelectorAll("a[href]").forEach(function(link) {
      var text = normalizeText(link.textContent || link.getAttribute("aria-label") || "");
      var href = link.getAttribute("href") || "";
      if (!/\b(transcript|transcription)\b/i.test(text + " " + href)) return;
      var url = absoluteUrl(href);
      if (!url) return;
      addMarkdown("Transcript", "[" + (text || "Transcript") + "](" + url + ")");
    });

    return parts.join("\n\n");
  }

  function podcastEpisodeContent(metadata) {
    var podcast = podcastEpisodeNode();
    if (!podcast) return null;

    var root = podcastRoot();
    var clone = podcastCleanupClone(root);
    var domMarkdown = cleanupMarkdownNoise(markdownFor(clone.innerHTML));
    var structuredDescription = structuredDescriptionMarkdown(podcast.description || (metadata && metadata.excerpt));
    var bodyMarkdown = domMarkdown;

    if (structuredDescription && normalizeText(structuredDescription).length > normalizeText(domMarkdown).length) {
      bodyMarkdown = structuredDescription;
    }

    var transcriptMarkdown = podcastTranscriptMarkdown(root);
    if (transcriptMarkdown && normalizeText(bodyMarkdown).indexOf(normalizeText(transcriptMarkdown).slice(0, 80)) === -1) {
      bodyMarkdown = [bodyMarkdown, transcriptMarkdown].filter(function(part) { return normalizeText(part); }).join("\n\n");
    }

    var title = podcastEpisodeTitle(podcast, metadata);
    var markdown = ["# " + title, bodyMarkdown].filter(function(part) { return normalizeText(part); }).join("\n\n");
    markdown = cleanupMarkdownNoise(markdown);

    if (normalizeText(markdown).length < 120) return null;

    return {
      title: title,
      byline: entityName(podcast.partOfSeries) || null,
      excerpt: entityText(podcast.description) || (metadata && metadata.excerpt),
      siteName: (metadata && metadata.siteName) || entityName(podcast.partOfSeries) || location.hostname,
      publishedTime: entityText(podcast.datePublished || podcast.uploadDate) || (metadata && metadata.publishedTime),
      html: clone.innerHTML,
      markdown: markdown,
      textContent: normalizeText(markdown),
      readerMode: false,
      contentType: "podcast"
    };
  }
