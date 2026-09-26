  function legalTableOfContentsContent(metadata) {
    var root = document.querySelector(".LegContents, #viewLegContents, .viewLegContents, [class*='table-of-contents' i], [aria-label*='table of contents' i]");
    if (!root || !legalTableOfContentsPage(root, root.textContent || "")) return null;

    var clone = cleanClone(root);
    var title = normalizeText(((document.querySelector("#pageTitle, h1") || {}).textContent) || metadata.title || document.title);
    var heading = document.createElement("h1");
    heading.textContent = title;
    clone.insertBefore(heading, clone.firstChild);
    cleanupAgentRoot(clone);

    var markdown = cleanupMarkdownNoise(markdownFor(clone.innerHTML));
    var text = normalizeText(markdown || clone.textContent || "");
    if (text.length < 200) return null;

    return {
      title: title || metadata.title || document.title,
      byline: null,
      excerpt: metadata.excerpt || text.slice(0, 280),
      siteName: metadata.siteName || location.hostname,
      publishedTime: metadata.publishedTime || null,
      html: clone.innerHTML,
      markdown: markdown,
      textContent: text,
      readerMode: false,
      contentType: "list",
      hostAware: true
    };
  }
