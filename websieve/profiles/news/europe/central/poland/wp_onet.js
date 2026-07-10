  function polishPortalHomepageContent(metadata) {
    var host = (location.hostname || "").replace(/^www\./i, "");
    var descriptor = polishPortalDescriptor(host);
    if (!descriptor || location.pathname !== "/") return null;

    var sectioned = sectionedListExtraction(document.body, descriptor);
    if (!sectioned) return null;

    return listItemsContentResult(metadata, {
      title: metadata && metadata.title,
      excerpt: metadata && metadata.excerpt,
      markdown: sectioned.markdown,
      textContent: sectioned.markdown,
      items: sectioned.items,
      hostAware: true
    });
  }

  function registerPolishPortalProfiles() {
    registerHostAwareProfile(["wp.pl", "onet.pl"], polishPortalHomepageContent);
  }
