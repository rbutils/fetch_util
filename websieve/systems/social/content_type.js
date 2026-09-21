  function normalizedSocialText(value) {
    var text = normalizeText(value || "");
    return text || null;
  }

  function socialInteger(value, allowNegative) {
    if (typeof value === "number") {
      if (!isFinite(value) || Math.floor(value) !== value) return null;
      if (!allowNegative && value < 0) return null;
      return value;
    }

    var text = normalizedSocialText(value);
    if (!text || !/^-?\d+$/.test(text)) return null;
    var number = Number(text);
    if (!isFinite(number) || (!allowNegative && number < 0)) return null;
    return number;
  }

  function clearSocialFields(content) {
    content.socialKind = null;
    content.platform = null;
    content.handle = null;
    content.replyCount = null;
    content.community = null;
    content.score = null;
  }

  function socialPlatformLabel(metadata) {
    var siteName = normalizedSocialText(metadata && metadata.siteName);
    if (siteName && !/^[\w.-]+\.[a-z]{2,}$/i.test(siteName)) return siteName.replace(/\.(?:com|net|org)$/i, "");

    var titleMatch = normalizedSocialText(document.title || "");
    titleMatch = titleMatch && titleMatch.match(/[|•·]\s*([^|•·]{2,40})$/);
    if (titleMatch) return normalizedSocialText(titleMatch[1]);

    var labels = String(location.hostname || "").toLowerCase().replace(/^www\./, "").split(".").filter(Boolean);
    var index = labels.length - 2;
    if (labels.length > 2 && labels[labels.length - 1].length === 2 && /^(?:ac|co|com|edu|gov|net|org)$/.test(labels[index])) {
      index -= 1;
    }
    var label = labels[Math.max(0, index)] || "";
    return normalizedSocialText(label.replace(/[-_]+/g, " ").replace(/\b\w/g, function(letter) {
      return letter.toUpperCase();
    }));
  }

  function socialRouteCommunity() {
    var match = safeDecodeURI(location.pathname || "").match(/\/(r|c|communit(?:y|ies)|groups?|tags?)\/([^/?#]+)/i);
    if (!match) return null;
    var prefix = match[1].toLowerCase();
    var value = normalizedSocialText(match[2].replace(/[-_]+/g, " "));
    if (!value) return null;
    return /^(?:r|c)$/.test(prefix) ? prefix + "/" + value : value;
  }

  function socialCustomThreadEvidence() {
    var nodes = Array.prototype.slice.call(document.body.getElementsByTagName("*")).filter(function(node) {
      return !elementSubtreeHidden(node) &&
        !node.closest("nav, footer, aside, form, dialog, [role='dialog']") &&
        /-(?:post|comment)$/.test(String(node.localName || ""));
    });
    var posts = nodes.filter(function(node) { return /-post$/.test(node.localName); });
    var candidates = posts.map(function(post) {
      var stem = post.localName.slice(0, -"-post".length);
      var owner = post.closest("main, article, [role='main']") || document.body;
      var comments = nodes.filter(function(node) {
        return node.localName === stem + "-comment" &&
          (node.closest("main, article, [role='main']") || document.body) === owner &&
          normalizeText(node.textContent).length >= 8 &&
          !!(post.compareDocumentPosition(node) & Node.DOCUMENT_POSITION_FOLLOWING);
      });
      if (!comments.length || normalizeText(post.textContent).length < 20) return null;
      return { post: post, comments: comments };
    }).filter(Boolean);
    return candidates.length === 1 ? candidates[0] : null;
  }

  function applyInferredSocialThread(content, metadata) {
    if (!content || content.contentType === "social" || content.contentType === "interstitial") return content;
    var evidence = socialCustomThreadEvidence();
    if (!evidence) return content;

    var post = evidence.post;
    var author = normalizedSocialText(post.getAttribute("author") || post.getAttribute("data-author"));
    content.contentType = "social";
    content.socialKind = "thread";
    content.platform = socialPlatformLabel(metadata);
    content.handle = author;
    content.byline = content.byline || author;
    content.replyCount = socialInteger(post.getAttribute("comment-count") || post.getAttribute("data-comment-count"), false);
    if (content.replyCount === null) content.replyCount = evidence.comments.length;
    content.community = socialRouteCommunity();
    content.score = socialInteger(post.getAttribute("score") || post.getAttribute("data-score"), true);
    content.readerMode = false;
    return content;
  }

  function socialFeedItemsEvidence(items) {
    if (items.length < 3) return null;

    var evidencedUrls = {};
    var evidencedItems = items.filter(function(item) {
      var url = materializedHttpUrl(item && item.url);
      var fields = listItemSocialFields(item).owned;
      var evidenced = !!(url && fields.author && fields.time && fields.score && fields.replyCount);
      if (evidenced) evidencedUrls[listCanonicalKey(url)] = true;
      return evidenced;
    });
    var requiredCount = Math.max(3, Math.ceil(items.length * 0.75));
    if (Object.keys(evidencedUrls).length < requiredCount || evidencedItems.length < requiredCount) return null;
    return { itemCount: items.length };
  }

  function socialSourceFeedEvidence() {
    var root = document.querySelector("main, [role='main']") || document.body;
    var selector = genericListCardSelector(false) + ", section, .feed-item, [class*='thread' i]";
    var items = Array.prototype.map.call(root.querySelectorAll(selector), function(card) {
      if (elementSubtreeHidden(card) || card.closest("nav, header, footer, aside, dialog, [role='dialog']")) return null;
      var link = genericListStructuredCardLink(card, false) || Array.prototype.find.call(card.querySelectorAll("a[href]"), function(anchor) {
        return materializedHttpUrl(anchor.getAttribute("href")) && normalizeText(anchor.textContent).length >= 6;
      });
      var url = link && materializedHttpUrl(link.getAttribute("href"));
      return url ? { card: card, url: url } : null;
    }).filter(Boolean);
    var evidenced = items.filter(function(item) {
      var fields = listItemSocialFields(item).owned;
      return fields.author && fields.time && fields.score && fields.replyCount;
    });
    return new Set(evidenced.map(function(item) { return listCanonicalKey(item.url); })).size >= 3;
  }

  function socialFeedEvidence(content, metadata) {
    if (!content || ["list", "article"].indexOf(content.contentType) === -1) return null;
    if (content.contentType === "article" && !socialSourceFeedEvidence()) return null;
    var evidenceContent = content.listExtraction ? content : listContent(metadata);
    var items = evidenceContent.listExtraction && evidenceContent.listExtraction.items || [];
    var evidence = socialFeedItemsEvidence(items);
    if (evidence) evidence.content = evidenceContent;
    return evidence;
  }

  function applyInferredSocialFeed(content, metadata) {
    if (!content || content.contentType === "social" || content.contentType === "interstitial") return content;
    var evidence = socialFeedEvidence(content, metadata);
    if (!evidence) return content;

    if (content.contentType === "article") content = evidence.content;
    content.contentType = "social";
    content.socialKind = "feed";
    content.platform = socialPlatformLabel(metadata);
    content.community = socialRouteCommunity();
    content.itemCount = evidence.itemCount;
    content.structuralSocialFeed = true;
    content.readerMode = false;
    return content;
  }

  function applySocialContentType(content, metadata) {
    if (content && !content.hostAware && content.contentType !== "interstitial") {
      var repeatedPost = socialRepeatedPostContent(metadata);
      if (repeatedPost) content = repeatedPost;
    }
    content = applyInferredSocialThread(content, metadata);
    content = applyInferredSocialFeed(content, metadata);
    content = applyInferredSocialPost(content, metadata);
    content = applyInferredSocialProfile(content, metadata);
    if (!content || content.contentType !== "social") return content;

    var kind = normalizedSocialText(content.socialKind);
    if (["post", "thread", "feed", "profile"].indexOf(kind) === -1) {
      content.contentType = "article";
      clearSocialFields(content);
      return content;
    }

    content.socialKind = kind;
    content.platform = normalizedSocialText(content.platform);
    content.handle = normalizedSocialText(content.handle);
    content.replyCount = socialInteger(content.replyCount, false);
    content.community = normalizedSocialText(content.community);
    content.score = socialInteger(content.score, true);
    return content;
  }
