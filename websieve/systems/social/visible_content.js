  function socialPostRouteEvidence() {
    var parts = safeDecodeURI(location.pathname || "").split("/").filter(Boolean);
    var postIndex = parts.findIndex(function(part) {
      return /^(?:p|reels?|status(?:es)?|tv)$/i.test(part);
    });
    if (postIndex < 0 || !/^[a-z0-9._-]{2,128}$/i.test(parts[postIndex + 1] || "")) return null;

    var identifier = parts[postIndex - 1] || "";
    if (!/^[a-z0-9._-]{2,64}$/i.test(identifier)) identifier = "";
    return { handle: identifier ? "@" + identifier : null };
  }

  function socialVisiblePostEvidence() {
    var route = socialPostRouteEvidence();
    if (!route) return null;

    var articles = Array.prototype.filter.call(document.querySelectorAll("main article, [role='main'] article"), function(article) {
      if (elementVisuallyHidden(article) || article.closest("nav, footer, aside, dialog, [role='dialog']")) return false;
      if (article.querySelector('input[type="password"], input[autocomplete="current-password"]')) return false;
      return normalizeText(article.innerText || "").length >= 8 || !!article.querySelector("img[src], video, audio");
    });
    if (articles.length !== 1) return null;

    var article = articles[0];
    var hasMedia = !!article.querySelector("img[src], video, audio");
    var text = normalizeText(article.innerText || "");
    var socialActions = Array.prototype.filter.call(article.querySelectorAll("button, a, [role='button']"), function(node) {
      return /^(?:like|reply|repost|share|comment)$/i.test(normalizeText(node.innerText || node.getAttribute("aria-label") || ""));
    }).length;
    if (!hasMedia && socialActions < 2 && !/[\d,.]+[KMB]?\s+(?:likes?|comments?|replies?|reposts?|views?)\b/i.test(text)) return null;
    return route;
  }

  function socialPostRecordSignature(node) {
    if (!node || elementVisuallyHidden(node) || node.closest("nav, footer, aside, dialog, [role='dialog']")) return null;
    var text = normalizeText(node.innerText || "");
    if (text.length < 4 && !node.querySelector("img[src], video, audio")) return null;

    var tokens = [node.id || "", node.getAttribute("data-testid") || "", node.getAttribute("role") || ""].concat(Array.from(node.classList || []));
    if (!tokens.some(function(token) { return /(?:^|[-_])(card|comment|feed|message|post|reply|status|thread)(?:[-_]|$)/i.test(token); })) return null;

    var classes = Array.from(node.classList || []).filter(function(name) {
      return !/^(?:active|current|expanded|loaded|open|selected)$/i.test(name);
    }).sort();
    return node.tagName.toLowerCase() + "|" + classes.join(".") + "|" + (node.getAttribute("role") || "");
  }

  function socialRepeatedPostEvidence() {
    var route = socialPostRouteEvidence();
    if (!route) return null;

    var candidates = Array.prototype.map.call(document.querySelectorAll("main, [role='main']"), function(owner) {
      if (elementVisuallyHidden(owner) || owner.querySelector('input[type="password"], input[autocomplete="current-password"]')) return null;
      if (normalizeText(owner.innerText || "").length < 80) return null;

      var authorLink = Array.prototype.find.call(owner.querySelectorAll("a[href]"), function(link) {
        if (elementVisuallyHidden(link)) return false;
        return /\/(?:members?|people|profiles?|users?)\/[^/?#]+/i.test(link.getAttribute("href") || "");
      });
      if (!authorLink) return null;

      var signatures = {};
      var materialSignatures = {};
      Array.prototype.forEach.call(owner.children || [], function(child) {
        var signature = socialPostRecordSignature(child);
        if (!signature) return;
        signatures[signature] = (signatures[signature] || 0) + 1;
        if (normalizeText(child.innerText || "").length >= 24 || child.querySelector("img[src], video, audio")) {
          materialSignatures[signature] = (materialSignatures[signature] || 0) + 1;
        }
      });
      var repeatedSignature = Object.keys(signatures).some(function(signature) {
        return signatures[signature] >= 3 && (materialSignatures[signature] || 0) >= 2;
      });
      if (!repeatedSignature) return null;

      var author = normalizeText(authorLink.innerText || "");
      var handleMatch = (authorLink.getAttribute("href") || "").match(/\/(?:members?|people|profiles?|users?)\/([^/?#]+)/i);
      return {
        author: author || null,
        handle: handleMatch ? safeDecodeURI(handleMatch[1]) : route.handle,
        owner: owner
      };
    }).filter(Boolean);
    return candidates.length === 1 ? candidates[0] : null;
  }

  function socialRepeatedPostContent(metadata) {
    var evidence = socialRepeatedPostEvidence();
    if (!evidence) return null;

    var clone = visibilityPrunedClone(evidence.owner, document);
    clone.querySelectorAll("script, style, noscript, template, iframe").forEach(function(node) { node.remove(); });
    clone.querySelectorAll("img[src]").forEach(function(image) {
      if (!normalizeText(image.getAttribute("alt") || "")) {
        image.setAttribute("alt", normalizeText(image.getAttribute("aria-label") || image.getAttribute("title") || "Image"));
      }
    });
    materializeHttpAttributes(clone, true);
    var markdown = markdownFor(clone.outerHTML).trim();
    var text = normalizeText(clone.innerText || "");
    if (text.length < 80 || normalizeText(markdown).length < 80) return null;

    return {
      title: evidence.author || metadata.title,
      byline: evidence.author || metadata.byline,
      excerpt: metadata.excerpt || text.slice(0, 280),
      siteName: metadata.siteName,
      publishedTime: metadata.publishedTime || firstTextFromNode(evidence.owner, ["time", ".time"]),
      canonicalUrl: metadata.canonicalUrl,
      html: clone.outerHTML,
      markdown: markdown,
      textContent: text,
      readerMode: false,
      contentType: "social",
      socialKind: "post",
      platform: socialPlatformLabel(metadata),
      handle: evidence.handle,
      hostAware: false
    };
  }

  function applyInferredSocialPost(content, metadata) {
    if (!content || content.contentType === "social" || content.contentType === "interstitial") return content;
    if (content.contentType !== "article") return content;
    var evidence = socialVisiblePostEvidence();
    if (!evidence) return content;

    content.contentType = "social";
    content.socialKind = "post";
    content.platform = socialPlatformLabel(metadata);
    content.handle = evidence.handle;
    content.readerMode = false;
    return content;
  }

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
    if (!root || root.querySelector('input[type="password"], input[autocomplete="current-password"]')) return null;

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
      handle: handleMatch ? handleMatch[1] : "@" + route.identifier.replace(/^@/, "")
    };
  }

  function socialProfileContextMarkdown(markdown) {
    var root = Array.prototype.find.call(document.querySelectorAll("main, [role='main']"), function(node) {
      return !elementVisuallyHidden(node);
    });
    if (!root) return "";

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
      var profileContext = socialProfileContextMarkdown(profileList.markdown);
      profileList.markdown = [profileContext, profileList.markdown].filter(Boolean).join("\n\n");
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
