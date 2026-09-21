  function socialProfileRouteEvidence() {
    var parts = safeDecodeURI(location.pathname || "").split("/").filter(Boolean);
    var first = normalizedSocialText(parts[0]);
    var second = normalizedSocialText(parts[1]);
    if (parts.length === 1 && /^@[a-z0-9._-]{2,64}$/i.test(first || "")) {
      return { identifier: first.slice(1), explicit: true };
    }
    if (parts.length === 2 && /^(?:company|in|members?|people|profiles?|users?)$/i.test(first || "") && /^[a-z0-9._-]{2,64}$/i.test(second || "")) {
      return { identifier: second, explicit: true };
    }
    if (parts.length !== 1 || !/^[a-z0-9._-]{2,64}$/i.test(first || "") || /^(?:about|account|accounts|auth|explore|feed|home|login|search|settings|signup)$/i.test(first)) return null;
    return { identifier: first, explicit: false };
  }

  function socialVisibleProfileEvidence() {
    var route = socialProfileRouteEvidence();
    if (!route) return null;
    var root = Array.prototype.find.call(document.querySelectorAll("main, [role='main']"), function(node) {
      return !elementVisuallyHidden(node);
    });
    if (!root) return null;
    var visiblePassword = Array.prototype.some.call(root.querySelectorAll('input[type="password"], input[autocomplete="current-password"]'), function(input) {
      return !elementSubtreeHidden(input);
    });
    if (visiblePassword) return null;

    var rawText = root.innerText || "";
    var fieldText = Array.prototype.map.call(root.querySelectorAll("span, p"), function(node) {
      return normalizeText(node.innerText || node.textContent || "");
    }).join("\n");
    var text = normalizeText(rawText + "\n" + fieldText);
    if (text.length < 24 || !/[\d,.]+[KMB]?\s+(?:followers?|following|connections?)\b/i.test(text)) return null;

    var handleMatch = fieldText.match(/(?:^|\s)(@[a-z0-9._-]{2,64})\b/i) || rawText.match(/(?:^|\s)(@[a-z0-9._-]{2,64})\b/i);
    var publicationCount = /[\d,.]+[KMB]?\s+(?:posts?|threads?)\b/i.test(text);
    var labeledSections = [
      /(?:^|\n)\s*(?:about|company size|founded|headquarters|industry|intro|specialties|website)\s*(?:\n|$)/i,
      /\b(?:page|profile)\s*·/i
    ].filter(function(pattern) { return pattern.test(rawText + "\n" + fieldText); }).length;
    if (!route.explicit && !handleMatch && !(publicationCount && labeledSections) && labeledSections < 2) return null;
    if (route.explicit && !handleMatch && !publicationCount && !labeledSections) return null;

    return {
      handle: handleMatch ? handleMatch[1] : "@" + route.identifier.replace(/^@/, ""),
      root: root
    };
  }

  function socialProfileContextMarkdown(root, markdown) {
    var represented = {};
    String(markdown || "").split(/\n+/).forEach(function(line) {
      var key = normalizeText(line).toLowerCase();
      if (key) represented[key] = true;
    });
    var seen = {};
    return Array.prototype.map.call(root.querySelectorAll("h1, h2, h3, p, span, div, strong"), function(node) {
      if (elementVisuallyHidden(node) || node.closest("nav, footer, aside, dialog, [role='dialog'], a[href], article, li, [class*='card' i], [class*='item' i], [class*='result' i]")) return "";
      if (node.querySelector("h1, h2, h3, p, span, div, strong")) return "";
      var text = normalizeText(node.innerText || node.textContent || "");
      var key = text.toLowerCase();
      if (!text || text.length > 500 || seen[key] || represented[key]) return "";
      seen[key] = true;
      return text;
    }).filter(Boolean).join("\n\n");
  }

  function socialProfileArticleMarkdown(root, markdown) {
    var represented = normalizeText(markdown || "").toLowerCase();
    var seen = {};
    return Array.prototype.map.call(root.querySelectorAll("article"), function(article) {
      if (elementVisuallyHidden(article) || article.closest("nav, footer, aside, dialog, [role='dialog']")) return "";
      if (article.parentElement && article.parentElement.closest("article")) return "";
      var clone = visibilityPrunedClone(article, document);
      if (!clone) return "";
      clone.querySelectorAll("script, style, noscript, template, iframe").forEach(function(node) { node.remove(); });
      materializeHttpAttributes(clone, true);
      var addition = markdownFor(clone.outerHTML).trim();
      var sourceKey = normalizeText(article.innerText || article.textContent || "").toLowerCase();
      var key = normalizeText(addition).toLowerCase();
      if (!key || seen[key] || represented.indexOf(key) >= 0 || (sourceKey && represented.indexOf(sourceKey) >= 0)) return "";
      seen[key] = true;
      return addition;
    }).filter(Boolean).join("\n\n");
  }

  function applyInferredSocialProfile(content, metadata) {
    if (!content || content.contentType === "social" || content.contentType === "interstitial") return content;
    if (["article", "list"].indexOf(content.contentType) === -1) return content;
    var evidence = socialVisibleProfileEvidence();
    if (!evidence) return content;
    var profileList = content.listExtraction ? content : listContent(metadata);
    var profileUrls = ((profileList.listExtraction || {}).items || []).map(function(item) {
      return materializedHttpUrl(item && item.url);
    }).filter(Boolean);
    if (profileUrls.filter(function(url, index) { return profileUrls.indexOf(url) === index; }).length >= 3) {
      var profileContext = socialProfileContextMarkdown(evidence.root, profileList.markdown);
      var profileArticles = socialProfileArticleMarkdown(evidence.root, profileList.markdown);
      profileList.markdown = [profileContext, profileList.markdown, profileArticles].filter(Boolean).join("\n\n");
      profileList.textContent = profileList.markdown;
      content = profileList;
    }

    content.contentType = "social";
    content.socialKind = "profile";
    content.platform = socialPlatformLabel(metadata);
    content.handle = evidence.handle;
    content.readerMode = false;
    return content;
  }
