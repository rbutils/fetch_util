  function genericPortalHomepageContent(metadata) {
    var leadRoot = genericHomepageLeadRoot(metadata, { minItems: 4 });
    if (!leadRoot) return null;

    var title = leadRoot.hero || (metadata && metadata.title) || document.title || location.hostname;
    var markdownParts = [];
    if (leadRoot.hero) markdownParts.push("# " + leadRoot.hero);
    if (metadata && metadata.excerpt) markdownParts.push(metadata.excerpt);
    if (leadRoot.headings.length >= 2) {
      markdownParts.push(leadRoot.headings.slice(0, 6).map(function(text) { return "- " + text; }).join("\n"));
    }
    markdownParts.push(listMarkdown(leadRoot.items.slice(0, 12)));

    var markdown = markdownParts.filter(Boolean).join("\n\n").trim();
    if (normalizeText(markdown).length < 180) return null;

    return listContentResult({
      title: title,
      excerpt: metadata && metadata.excerpt,
      siteName: (metadata && metadata.siteName) || location.hostname,
      markdown: markdown,
      textContent: normalizeText(markdown)
    });
  }

  function registerGenericPortalHomepageProfiles() {
    registerHostAwareProfile(true, genericPortalHomepageContent);
  }
