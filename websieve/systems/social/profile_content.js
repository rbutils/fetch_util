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

    var titleNode = Array.prototype.find.call(root.querySelectorAll("h1, h2, [data-testid*='UserName' i], [data-testid*='DisplayName' i]"), function(node) {
      return !elementSubtreeHidden(node) && normalizeText(node.innerText || node.textContent || "").length >= 2;
    });
    var title = normalizeText(titleNode && (titleNode.innerText || titleNode.textContent) || "")
      .replace(/@[a-z0-9._-]{2,64}\b/ig, "")
      .trim();
    var description = Array.prototype.map.call(root.querySelectorAll("p, [class*='bio' i], [class*='description' i], [data-testid*='description' i]"), function(node) {
      if (elementSubtreeHidden(node) || node.closest("nav, footer, aside, dialog, [role='dialog'], form, article")) return "";
      return normalizeText(node.innerText || node.textContent || "");
    }).find(function(value) {
      return value.length >= 40 && value.length <= 500 && !/^[\d,.]+[KMB]?\s+(?:followers?|following|connections?|posts?|threads?)\b/i.test(value);
    }) || null;

    return {
      description: description,
      handle: handleMatch ? handleMatch[1] : "@" + route.identifier.replace(/^@/, ""),
      root: root,
      title: title || null
    };
  }

  function socialProfileContextMarkdown(root, markdown) {
    var clone = visibilityPrunedClone(root, document);
    if (!clone) return "";
    clone.querySelectorAll("nav, footer, aside, dialog, [role='dialog'], form, article, script, style, noscript, template, iframe, li, [class*='card' i], [class*='item' i], [class*='result' i]").forEach(function(node) {
      node.remove();
    });
    materializeHttpAttributes(clone, true);
    var context = markdownFor(clone.innerHTML).trim();
    var represented = normalizeText(markdown || "").toLowerCase();
    var key = normalizeText(context).toLowerCase();
    return key && represented.indexOf(key) < 0 ? context : "";
  }

  function socialProfileExcerpt(markdown) {
    return String(markdown || "").split(/\n\s*\n/).map(function(block) {
      return normalizeText(block
        .replace(/!\[[^\]]*\]\([^)]*\)/g, "")
        .replace(/\[([^\]]+)\]\([^)]*\)/g, "$1")
        .replace(/^#{1,6}\s+/g, ""));
    }).find(function(text) {
      return text.length >= 40 && text.length <= 500 && !/^[\d,.]+[KMB]?\s+(?:followers?|following|connections?|posts?|threads?)\b/i.test(text);
    }) || null;
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
      var sourceSegments = Array.prototype.map.call(article.querySelectorAll("h1, h2, h3, h4, p, [data-testid*='text' i]"), function(node) {
        return normalizeText(node.innerText || node.textContent || "").toLowerCase();
      }).filter(function(value) { return value.length >= 8; });
      var fullyRepresented = sourceSegments.length && sourceSegments.every(function(value) {
        return represented.indexOf(value) >= 0;
      });
      var key = normalizeText(addition).toLowerCase();
      if (!key || seen[key] || fullyRepresented || represented.indexOf(key) >= 0 || (sourceKey && represented.indexOf(sourceKey) >= 0)) return "";
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
      evidence.description = evidence.description || socialProfileExcerpt(profileContext);
      content = profileList;
    }

    content.contentType = "social";
    content.socialKind = "profile";
    content.platform = socialPlatformLabel(metadata);
    content.siteName = content.platform;
    content.handle = evidence.handle;
    content.title = evidence.title || content.title;
    content.excerpt = evidence.description || content.excerpt;
    content.readerMode = false;
    return content;
  }
