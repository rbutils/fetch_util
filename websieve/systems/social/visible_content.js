  function socialPostRouteEvidence() {
    var parts = safeDecodeURI(location.pathname || "").split("/").filter(Boolean);
    var postIndex = parts.findIndex(function(part) {
      return /^(?:p|reels?|status(?:es)?|story|tv)$/i.test(part);
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

    var tokens = [node.localName || "", node.id || "", node.getAttribute("data-testid") || "", node.getAttribute("role") || ""].concat(Array.from(node.classList || []));
    if (!tokens.some(function(token) { return /(?:^|[-_])(card|comment|feed|message|post|reply|status|thread)(?:[-_]|$)/i.test(token); })) return null;

    var classes = Array.from(node.classList || []).filter(function(name) {
      return !/^(?:active|current|expanded|loaded|open|selected)$/i.test(name);
    }).sort();
    return node.tagName.toLowerCase() + "|" + classes.join(".") + "|" + (node.getAttribute("role") || "");
  }

  function socialPostAuthorLink(owner) {
    return Array.prototype.find.call(owner.querySelectorAll("a[href]"), function(link) {
      if (elementVisuallyHidden(link)) return false;
      var href = link.getAttribute("href") || "";
      return /\/(?:members?|people|profiles?|users?)\/[^/?#]+/i.test(href) || /\/@[^/?#]+(?:[/?#]|$)/.test(href);
    }) || null;
  }

  function socialPostHandle(authorLink, fallback) {
    var match = (authorLink && authorLink.getAttribute("href") || "").match(/\/(?:members?|people|profiles?|users?)\/([^/?#]+)|\/@([^/?#]+)/i);
    return match ? safeDecodeURI(match[1] || match[2]) : fallback;
  }

  function socialRepeatedPostEvidence() {
    var route = socialPostRouteEvidence();
    var community = socialRouteCommunity();
    if (!route && !community) return null;

    var candidates = Array.prototype.map.call(document.querySelectorAll("main, [role='main']"), function(owner) {
      if (elementVisuallyHidden(owner) || owner.querySelector('input[type="password"], input[autocomplete="current-password"]')) return null;
      if (normalizeText(owner.innerText || "").length < 80) return null;

      var authorLink = socialPostAuthorLink(owner);
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
      var repeatedSignatures = Object.keys(signatures).filter(function(signature) {
        return signatures[signature] >= 3 && (materialSignatures[signature] || 0) >= 2;
      });
      if (!route) {
        repeatedSignatures = repeatedSignatures.filter(function(signature) {
          return /(?:^|[-_.|])post(?:[-_.|]|$)/i.test(signature);
        });
      }
      if (!repeatedSignatures.length) return null;

      var author = normalizeText(authorLink.innerText || "");
      return {
        author: author || null,
        community: route ? null : community,
        handle: route ? socialPostHandle(authorLink, route.handle) : null,
        itemCount: Math.max.apply(null, repeatedSignatures.map(function(signature) { return signatures[signature]; })),
        kind: route ? "post" : "feed",
        owner: owner,
        title: route ? null : firstTextFromNode(owner, ["h1", "h2"])
      };
    }).filter(Boolean);
    return candidates.length === 1 ? candidates[0] : null;
  }

  function socialDiscussionCommentRoots(owner) {
    var comments = visibleCommentCandidates(owner).filter(function(node) {
      return node.querySelector("p, li, [class*='body' i], [slot='comment']") && normalizeText(node.innerText || node.textContent || "").length >= 8;
    });
    return comments.filter(function(node) {
      return !comments.some(function(parent) { return parent !== node && parent.contains(node); });
    });
  }

  function socialDiscussionPostEvidence() {
    var route = socialPostRouteEvidence();
    if (!route) return null;
    var candidates = Array.prototype.map.call(document.querySelectorAll("main, [role='main']"), function(owner) {
      if (elementVisuallyHidden(owner) || owner.querySelector('input[type="password"], input[autocomplete="current-password"]')) return null;
      if (normalizeText(owner.innerText || owner.textContent || "").length < 80) return null;
      var comments = socialDiscussionCommentRoots(owner);
      var authorLink = socialPostAuthorLink(owner);
      var title = firstTextFromNode(owner, ["h1", "h2"]);
      var focal = owner.querySelector("article, [data-story-id], [data-post-id], [class*='story' i], [class*='post' i]");
      if (!comments.length || !authorLink || !title || !focal || normalizeText(focal.innerText || focal.textContent || "").length < 40) return null;
      return { author: normalizeText(authorLink.innerText || "") || null, comments: comments, handle: socialPostHandle(authorLink, route.handle), owner: owner, title: title };
    }).filter(Boolean);
    return candidates.length === 1 ? candidates[0] : null;
  }

  function markSocialDiscussionComments(root) {
    socialDiscussionCommentRoots(root).forEach(function(comment) {
      for (var node = comment; node && root.contains(node); node = node.parentElement) {
        var identity = [node.id, node.className, node.getAttribute("role"), node.getAttribute("itemprop"), node.localName].join(" ");
        if (node === comment || /comment/i.test(identity)) {
          node.setAttribute("data-fetchutil-social-comment", "");
          if (/(?:^|[-_])comments?(?:[-_]|$)/i.test(node.id || "")) node.removeAttribute("id");
          Array.prototype.slice.call(node.classList || []).forEach(function(name) {
            if (/(?:^|[-_])comments?(?:[-_]|$)/i.test(name)) node.classList.remove(name);
          });
        }
        if (node === root) break;
      }
    });
  }

  function socialPostOwnedContent(metadata) {
    var evidence = socialRepeatedPostEvidence() || socialDiscussionPostEvidence();
    if (!evidence) return null;

    var clone = visibilityPrunedClone(evidence.owner, document);
    clone.querySelectorAll("script, style, noscript, template, iframe").forEach(function(node) { node.remove(); });
    if (evidence.comments) markSocialDiscussionComments(clone);
    clone.querySelectorAll("aside, [role='complementary']").forEach(function(node) {
      if (!node.querySelector("[data-fetchutil-social-comment], article, [data-story-id], [data-post-id], [class*='story' i], [class*='post' i]")) node.remove();
    });
    clone.querySelectorAll("[poster]").forEach(function(media) {
      var poster = materializedHttpUrl(media.getAttribute("poster"));
      var duplicate = Array.prototype.some.call(clone.querySelectorAll("img[src]"), function(image) {
        return materializedHttpUrl(image.getAttribute("src")) === poster;
      });
      if (!poster || duplicate || !media.parentNode) return;
      var image = document.createElement("img");
      image.setAttribute("src", poster);
      image.setAttribute("alt", "Video poster");
      media.parentNode.insertBefore(image, media);
    });
    clone.querySelectorAll("img[src]").forEach(function(image) {
      if (!normalizeText(image.getAttribute("alt") || "")) {
        image.setAttribute("alt", normalizeText(image.getAttribute("aria-label") || image.getAttribute("title") || "Image"));
      }
    });
    materializeHttpAttributes(clone, true);
    var markdown = markdownFor(clone.outerHTML).trim();
    clone.querySelectorAll("[data-fetchutil-social-comment]").forEach(function(node) { node.removeAttribute("data-fetchutil-social-comment"); });
    var text = normalizeText(clone.innerText || "");
    if (text.length < 80 || normalizeText(markdown).length < 80) return null;

    return {
      title: evidence.title || (evidence.kind === "feed" ? metadata.title : evidence.author || metadata.title),
      byline: evidence.kind === "feed" ? metadata.byline : evidence.author || metadata.byline,
      excerpt: metadata.excerpt || text.slice(0, 280),
      siteName: metadata.siteName,
      publishedTime: metadata.publishedTime || firstTextFromNode(evidence.owner, ["time", ".time"]),
      canonicalUrl: metadata.canonicalUrl,
      html: clone.outerHTML,
      markdown: markdown,
      textContent: text,
      readerMode: false,
      contentType: "social",
      socialKind: evidence.kind || "post",
      platform: socialPlatformLabel(metadata),
      handle: evidence.handle,
      community: evidence.community,
      itemCount: evidence.itemCount,
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
