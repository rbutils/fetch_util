  function githubThreadRoute() {
    if (!hostMatches(/(^|\.)github\.com$/)) return null;

    var parts = (location.pathname || "").split("/").filter(Boolean);
    if (parts.length !== 4 || !/^[\w.-]+$/.test(parts[0]) || !/^[\w.-]+$/.test(parts[1]) || !/^\d+$/.test(parts[3])) return null;
    if (["issues", "pull", "discussions"].indexOf(parts[2]) === -1) return null;

    return { community: parts[0] + "/" + parts[1], kind: parts[2] };
  }

  function githubThreadRoot() {
    return document.querySelector("[data-testid='issue-viewer-issue-container'], #discussion_bucket, .js-discussion, .discussion-timeline");
  }

  function githubThreadBody(node) {
    return node && node.querySelector("[data-testid='comment-body'], .comment-body, .js-comment-body, .markdown-body[itemprop='text'], [itemprop='text']");
  }

  function githubThreadAuthor(node) {
    var author = node && node.querySelector("a.author, [data-testid='comment-author'], a[data-hovercard-type='user']");
    return normalizeText((author && author.textContent) || "").replace(/^@/, "");
  }

  function githubThreadOpening(root) {
    var candidates = Array.prototype.slice.call(root.querySelectorAll(".js-comment-container, .timeline-comment, [data-testid='issue-comment'], .discussion-comment"));
    for (var i = 0; i < candidates.length; i += 1) {
      if (githubThreadBody(candidates[i]) && githubThreadAuthor(candidates[i])) return candidates[i];
    }
    return null;
  }

  function githubThreadCount(root) {
    var count = root.querySelector("[data-testid='issue-comment-count'], [data-testid='discussion-comment-count'], .js-discussion .comment-count");
    var text = normalizeText((count && count.textContent) || "");
    var match = text.match(/^(\d[\d,]*)\s+(?:comments?|replies)$/i);
    return match ? Number(match[1].replace(/,/g, "")) : null;
  }

  function githubThreadScore(opening) {
    var score = opening.querySelector("[data-testid='reaction-count'], [data-testid='vote-count']");
    var text = normalizeText((score && score.textContent) || "");
    return /^-?\d[\d,]*$/.test(text) ? Number(text.replace(/,/g, "")) : null;
  }

  function githubThreadCommentMarkdown(node) {
    var body = githubThreadBody(node);
    if (!body || !normalizeText(body.textContent)) return "";

    var clone = cleanClone(body);
    removeAll(clone, ".js-comment-actions, .timeline-comment-actions, .reaction-summary-item, [aria-label='Add reaction']");
    return cleanupMarkdownNoise(markdownFor(clone.innerHTML));
  }

  function githubThreadComments(root, opening) {
    var comments = [];
    var nodes = Array.prototype.slice.call(root.querySelectorAll(".js-comment-container, .timeline-comment, [data-testid='issue-comment'], .discussion-comment"));
    nodes.forEach(function(node) {
      if (node === opening || comments.length >= 12) return;

      var markdown = githubThreadCommentMarkdown(node);
      if (!markdown) return;

      var author = githubThreadAuthor(node);
      var accepted = /\b(?:accepted answer|answer marked as accepted)\b/i.test(normalizeText(node.textContent || "")) || !!node.querySelector("[data-testid='accepted-answer'], [aria-label*='accepted']");
      comments.push({ node: node, author: author, markdown: markdown, accepted: accepted });
    });
    return comments;
  }

  function githubThreadContent(metadata) {
    var route = githubThreadRoute();
    if (!route) return null;

    var root = githubThreadRoot();
    if (!root) return null;

    var opening = githubThreadOpening(root);
    var openingMarkdown = githubThreadCommentMarkdown(opening);
    if (!openingMarkdown) return null;

    var title = normalizeText(firstText(["[data-testid='issue-title']", "#issue_title", ".js-issue-title", "main h1", "h1"]) || metadata.title || document.title);
    var author = githubThreadAuthor(opening);
    if (!title || !author) return null;

    var comments = githubThreadComments(root, opening);
    var label = route.kind === "pull" ? "Pull Request" : route.kind === "discussions" ? "Discussion" : "Issue";
    var sections = ["# " + title, "- Author: " + author, "- " + label + ": " + route.community, "## Opening", openingMarkdown];
    if (comments.length) sections.push("## Comments");
    comments.forEach(function(comment) {
      var heading = comment.accepted ? "Accepted answer" : "Comment";
      if (comment.author) heading += " by " + comment.author;
      sections.push("### " + heading, comment.markdown);
    });

    var nodes = [opening].concat(comments.map(function(comment) { return comment.node; }));
    return {
      title: title,
      byline: author,
      excerpt: normalizeText(githubThreadBody(opening).textContent),
      siteName: "GitHub",
      publishedTime: metadata.publishedTime,
      html: nodes.filter(Boolean).map(function(node) { return node.outerHTML; }).join("\n"),
      markdown: sections.join("\n\n"),
      textContent: normalizeText([title, openingMarkdown].concat(comments.map(function(comment) { return comment.markdown; })).join(" ")),
      hostAware: true,
      readerMode: false,
      contentType: "social",
      socialKind: "thread",
      platform: "GitHub",
      handle: author,
      replyCount: githubThreadCount(root),
      community: route.community,
      score: githubThreadScore(opening)
    };
  }

  function registerGitHubThreadProfiles() {
    registerHostAwareProfile(/(^|\.)github\.com$/, githubThreadContent);
  }
