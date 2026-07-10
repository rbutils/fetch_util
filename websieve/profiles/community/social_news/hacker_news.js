  function hackerNewsContent(metadata) {
    if (hackerNewsItemPage()) return hackerNewsItemContent(metadata);
    if (hackerNewsFeedPage()) return hackerNewsFeedContent(metadata);
    return null;
  }

  function hackerNewsItemPage() {
    if ((location.pathname || "") !== "/item" || !queryParam("id")) return false;
    return !!document.querySelector("tr.athing .titleline, table.comment-tree tr.comtr .commtext");
  }

  function hackerNewsFeedPage() {
    var path = location.pathname || "/";
    if (!/^\/(?:|front|newest|best|ask|show|jobs)$/.test(path)) return false;
    return document.querySelectorAll("table.itemlist tr.athing .titleline").length >= 3 ||
      document.querySelectorAll("table#hnmain tr.athing .titleline").length >= 3;
  }

  function hackerNewsStory(node) {
    if (!node) return null;
    var titleLink = node.querySelector(".titleline > a, a.titlelink");
    var title = normalizeText((titleLink && titleLink.textContent) || "");
    if (!title) return null;
    var details = node.nextElementSibling || document.createElement("tr");
    var subtext = details.querySelector(".subtext") || node.querySelector(".subtext");
    var subtextText = normalizeText((subtext && subtext.textContent) || "");
    var scoreMatch = subtextText.match(/\b(\d+)\s+points?\b/i);
    var repliesMatch = subtextText.match(/\b(\d+)\s+comments?\b/i);
    var author = normalizeText((subtext && subtext.querySelector(".hnuser") || {}).textContent || "");
    var age = normalizeText((subtext && subtext.querySelector(".age") || {}).textContent || "");
    var dead = !!node.querySelector(".deadmark") || /\[dead\]/i.test(subtextText);

    return {
      title: dead ? "[dead] " + title : title,
      url: absoluteUrl((titleLink && titleLink.getAttribute("href")) || ""),
      author: author,
      age: age,
      score: scoreMatch ? Number(scoreMatch[1]) : null,
      replyCount: repliesMatch ? Number(repliesMatch[1]) : null,
      dead: dead,
      html: node.outerHTML + (details.outerHTML || "")
    };
  }

  function hackerNewsCommentEntries() {
    return Array.prototype.slice.call(document.querySelectorAll("table.comment-tree tr.comtr")).map(function(node) {
      var body = node.querySelector(".commtext");
      var text = normalizeText((body && body.textContent) || "");
      var deleted = !!node.querySelector(".deadmark") || /\[(?:deleted|dead)\]/i.test(text);
      var indent = node.querySelector("td.ind img");
      var width = Number((indent && indent.getAttribute("width")) || 0);
      var author = normalizeText((node.querySelector(".hnuser") || {}).textContent || "");
      var age = normalizeText((node.querySelector(".age") || {}).textContent || "");
      var markdown = body ? markdownFor(body.innerHTML).trim() : "";

      if (!markdown && !deleted) return null;
      return {
        author: author,
        age: age,
        depth: Math.max(0, Math.round(width / 40)),
        deleted: deleted,
        markdown: markdown || "[deleted]",
        text: text || "[deleted]",
        html: node.outerHTML
      };
    }).filter(Boolean);
  }

  function hackerNewsCommentMarkdown(comments) {
    return comments.map(function(comment) {
      var level = Math.min(6, 3 + comment.depth);
      var heading = comment.deleted ? "Deleted comment" : (comment.author || "Comment");
      if (comment.age) heading += " (" + comment.age + ")";
      return Array(level + 1).join("#") + " " + heading + "\n\n" + comment.markdown;
    }).join("\n\n");
  }

  function hackerNewsItemContent(metadata) {
    var story = hackerNewsStory(document.querySelector("tr.athing"));
    var comments = hackerNewsCommentEntries();
    if (!story && comments.length === 0) return null;

    var focalComment = comments[0];
    var title = story ? story.title : "Comment by " + (focalComment.author || "deleted user");
    var sections = ["# " + title];
    var details = [];
    var storyText = document.querySelector(".toptext");
    if (story && story.url) details.push("- Story: [" + story.title + "](" + story.url + ")");
    if (story && story.author) details.push("- Author: " + story.author);
    if (story && story.age) details.push("- Published: " + story.age);
    if (story && story.score !== null) details.push("- Score: " + story.score);
    if (story && story.replyCount !== null) details.push("- Replies: " + story.replyCount);
    if (details.length) sections.push(details.join("\n"));
    if (storyText) sections.push(markdownFor(storyText.innerHTML).trim());
    if (comments.length) sections.push("## Comments\n\n" + hackerNewsCommentMarkdown(comments));

    var markdown = sections.filter(Boolean).join("\n\n").trim();
    var replyCount = story && story.replyCount !== null ? story.replyCount : (comments.some(function(comment) { return comment.depth > 0; }) ? comments.filter(function(comment) { return comment.depth > 0; }).length : null);
    return {
      title: title,
      byline: (story && story.author) || (focalComment && focalComment.author) || null,
      excerpt: normalizeText((storyText && storyText.textContent) || (focalComment && focalComment.text) || metadata.excerpt || ""),
      siteName: "Hacker News",
      publishedTime: null,
      html: (story ? story.html : "") + comments.map(function(comment) { return comment.html; }).join("\n"),
      markdown: markdown,
      textContent: normalizeText(markdown),
      readerMode: false,
      hostAware: true,
      contentType: "social",
      socialKind: replyCount ? "thread" : "post",
      platform: "Hacker News",
      handle: (story && story.author) || (focalComment && focalComment.author) || null,
      replyCount: replyCount,
      score: story && story.score
    };
  }

  function hackerNewsFeedContent(metadata) {
    var storyNodes = document.querySelectorAll("table.itemlist tr.athing");
    if (storyNodes.length < 3) storyNodes = document.querySelectorAll("table#hnmain tr.athing");
    var stories = Array.prototype.slice.call(storyNodes).map(hackerNewsStory).filter(Boolean);
    if (stories.length < 3) return null;
    var section = normalizeText((document.querySelector(".pagetop b, .pagetop a.topsel") || {}).textContent || "");
    var markdown = "# " + (section || metadata.title || "Hacker News") + "\n\n" + stories.map(function(story) {
      var details = [];
      if (story.score !== null) details.push(story.score + " points");
      if (story.author) details.push("by " + story.author);
      if (story.age) details.push(story.age);
      return "- [" + story.title + "](" + story.url + ")" + (details.length ? " - " + details.join(" - ") : "");
    }).join("\n");

    return {
      title: section || metadata.title || "Hacker News",
      byline: null,
      excerpt: stories[0].title,
      siteName: "Hacker News",
      publishedTime: null,
      html: stories.map(function(story) { return story.html; }).join("\n"),
      markdown: markdown,
      textContent: normalizeText(markdown),
      readerMode: false,
      hostAware: true,
      contentType: "social",
      socialKind: "feed",
      platform: "Hacker News",
      community: section || null
    };
  }

  function registerHackerNewsProfiles() {
    registerHostAwareProfile(/^news\.ycombinator\.com$/i, hackerNewsContent);
  }
