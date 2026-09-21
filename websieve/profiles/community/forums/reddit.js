  function redditThreadMarkdown(metadata) {
    var post = document.querySelector("shreddit-post");
    if (!post) return null;

    var title = normalizeText((post.querySelector('[slot="title"]') || document.querySelector("main h1") || {}).textContent || metadata.title || document.title);
    var credit = normalizeText((post.querySelector('[slot="credit-bar"]') || {}).textContent || "");
    var byline = post.getAttribute("author") || firstText(["[slot='credit-bar'] a[href*='/user/']", "a[href*='/user/']"]);
    byline = normalizeText(byline);
    var body = normalizeText((post.querySelector('[slot="text-body"]') || {}).innerText || "");
    if (!body) {
      Array.prototype.slice.call(document.querySelectorAll("faceplate-screen-reader-content")).some(function(node) {
        var text = normalizeText(node.innerText || node.textContent || "");
        if (!text || /^go to\s+\w+$/i.test(text)) return false;
        body = text;
        return true;
      });
    }
    var commentCount = redditExplicitInteger(post.getAttribute("comment-count"));
    var score = redditExplicitInteger(post.getAttribute("score"));
    var commentNodes = document.querySelectorAll("shreddit-comment");
    var comments = collectCommunityThreadEntries(commentNodes, function(node) {
      var metaNode = node.querySelector(':scope > [slot="commentMeta"]');
      var bodyNode = node.querySelector(':scope > [slot="comment"]');
      var author = normalizeText(node.getAttribute("author") || "");
      var score = normalizeText(node.getAttribute("score") || "");
      var metaText = normalizeText((metaNode || {}).innerText || "");
      var text = normalizeText((bodyNode || {}).innerText || "");
      if (!text) return null;

      var heading = author || "Comment";
      if (score) heading += " (" + score + " points)";
      return {
        id: node.getAttribute("thingid") || node.getAttribute("comment-id") || node.id,
        parentId: node.getAttribute("parent-comment-id"),
        depth: redditCommentDepth(node),
        heading: heading,
        meta: metaText,
        body: text,
        text: text
      };
    });

    if (!title || (!body && comments.length === 0)) return null;

    var sections = ["# " + title];
    if (byline) sections.push("- Author: " + byline);
    if (credit && (!byline || credit.toLowerCase().indexOf(byline.toLowerCase()) === -1)) sections.push("- Context: " + credit);
    if (body) sections.push(body);
    if (commentCount || comments.length) sections.push("## Top Comments");

    comments.forEach(function(comment) {
      sections.push(redditCommentHeadingPrefix(comment.depth) + " " + comment.heading);
      if (comment.meta && comment.meta.toLowerCase().indexOf(comment.heading.toLowerCase()) === -1) sections.push(comment.meta);
      sections.push(comment.body);
    });

    return {
      title: title,
      byline: byline || metadata.byline,
      excerpt: body || metadata.excerpt,
      siteName: metadata.siteName || "Reddit",
      publishedTime: metadata.publishedTime,
      html: [post.outerHTML, communityThreadEntriesHtml(comments)].filter(Boolean).join("\n"),
      markdown: sections.filter(Boolean).join("\n\n"),
      textContent: normalizeText([title, body].concat(comments.map(function(comment) { return comment.text; })).join(" ")),
      readerMode: false,
      contentType: comments.length ? "social" : "article",
      socialKind: comments.length ? "thread" : null,
      platform: comments.length ? "Reddit" : null,
      handle: comments.length ? byline : null,
      replyCount: comments.length ? commentCount : null,
      community: comments.length ? redditCommunity() : null,
      score: comments.length ? score : null
    };
  }

  function redditCommentDepth(node) {
    var depth = Number(node.getAttribute("depth"));
    return Number.isFinite(depth) && depth > 0 ? depth : 0;
  }

  function redditCommentHeadingPrefix(depth) {
    return "######".slice(0, Math.min(3 + depth, 6));
  }

  function redditExplicitInteger(value) {
    var text = normalizeText(value || "");
    return /^-?\d[\d,]*$/.test(text) ? Number(text.replace(/,/g, "")) : null;
  }

  function redditCommunity() {
    var parts = (location.pathname || "").split("/").filter(Boolean);
    return parts[0] === "r" && /^[\w-]+$/.test(parts[1] || "") ? "r/" + parts[1] : null;
  }

  function redditChallengeContent(metadata, pageText) {
    var query = (location.search || "").toLowerCase();
    var page = normalizeText([metadata.title, document.title, pageText].join(" ")).toLowerCase();
    var challengeParameters = /(?:[?&](?:js_challenge|solution)=)/.test(query);
    var challengeShell = /(?:javascript challenge|complete the security check|verify you are human|checking your browser)/.test(page);
    if (!challengeParameters || !challengeShell) return null;

    return articleContentFromParts({
      title: normalizeText(metadata.title || document.title) || "Reddit access verification required",
      description: "Reddit is presenting an access verification challenge before the requested community can be shown.",
      details: ["Challenge: Reddit access verification"],
      siteName: metadata.siteName || "Reddit",
      contentType: "interstitial"
    });
  }

  function redditContent(metadata, pageText) {
    if (!hostMatches(/(^|\.)reddit\.com$/)) return null;
    var challenge = redditChallengeContent(metadata, pageText);
    if (challenge) return challenge;
    var liveThread = redditThreadMarkdown(metadata);
    if (liveThread) return liveThread;
    if (!/(cookie preferences|before you continue to reddit|reddit uses cookies|log in|sign up)/i.test(pageText || "")) return null;

    var parts = (location.pathname || "").split("/").filter(Boolean);
    var subreddit = parts[0] === "r" ? parts[1] : null;
    var title = normalizeText((metadata.title || document.title).replace(/\s*:\s*r\/[^|]+$/i, "")) || metadata.title || "Reddit page";
    var description = metadata.excerpt || "Original content on this Reddit page is not available without cookie acceptance or login.";
    var details = ["Access notice: Reddit cookie acceptance or login required"];
    if (subreddit) details.push("Requested community: r/" + subreddit);

    return articleContentFromParts({
      title: title,
      description: description,
      details: details,
      siteName: metadata.siteName || "Reddit"
    });
  }

  function registerRedditProfiles() {
    registerHostAwareProfile(true, redditContent);
  }
