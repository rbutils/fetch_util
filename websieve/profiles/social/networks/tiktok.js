  function tikTokContent(metadata, pageText) {
    var signature = docsHostSignature(metadata);
    if (!hostMatches(/(^|\.)tiktok\.com$/) && !/tiktok/i.test(signature)) return null;

    var page = normalizeText(pageText || "");
    var heading = firstText(["main h1", "h1"]);
    var subheading = firstText(["main h2", "h2"]);
    var pathTag = safeDecodeURI((location.pathname || "").replace(/^\/tag\//, "").split("/")[0] || "").replace(/[-_]+/g, " ");
    pathTag = normalizeText(pathTag);

    if (/^\/tag\//.test(location.pathname) || heading || subheading) {
      var title = heading || (pathTag ? "#" + pathTag : normalizeText(metadata.title || document.title));
      var description = metadata.excerpt;
      if (!description || /make your day/i.test(description)) description = "This TikTok page is only partially available, but the visible tag or page summary can still be extracted.";

      var details = [];
      if (subheading && subheading !== title) details.push(subheading);
      if (/drag the slider to fit the puzzle|log in/i.test(page)) details.push("Access notice: TikTok login or verification required");

      return articleContentFromParts({
        title: title,
        description: description,
        details: details,
        siteName: metadata.siteName || "TikTok",
        contentType: "article"
      });
    }

    if (!/drag the slider to fit the puzzle|slide to verify/i.test(page)) return null;

    return articleContentFromParts({
      title: normalizeText(metadata.title || document.title) || "TikTok verification required",
      description: metadata.excerpt || "This TikTok page is presenting a slider verification challenge before the original content is available.",
      details: ["Gate: slider verification"],
      siteName: metadata.siteName || "TikTok",
      contentType: "article"
    });
  }

  function registerTikTokProfile() {
    registerHostAwareProfile(true, tikTokContent);
  }
