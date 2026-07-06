  function discourseTopicContent(metadata) {
    if (!discourseTopicPage(metadata)) return null;

    var postNodes = Array.prototype.slice.call(document.querySelectorAll(".topic-post, article[data-post-id], [data-post-id].topic-post"));
    var sections = [];
    var bodyTexts = [];
    var seenPosts = {};
    var title = normalizeText(firstText(["#topic-title h1", ".topic-title h1", "main h1", "article h1", "h1"]) || metadata.title || document.title);

    postNodes.forEach(function(post) {
      var cooked = post.querySelector(".cooked");
      if (!cooked) return;

      var bodyText = normalizeText(cooked.innerText || cooked.textContent || "");
      if (!bodyText) return;

      var key = bodyText.slice(0, 240);
      if (seenPosts[key]) return;
      seenPosts[key] = true;

      var heading = discoursePostHeading(post);
      var markdown = markdownFor(cooked.outerHTML);
      if (!markdown) return;

      sections.push("## " + heading);
      sections.push(markdown);
      bodyTexts.push(bodyText);
    });

    if (!title || bodyTexts.length === 0) return null;

    return {
      title: title,
      byline: metadata.byline,
      excerpt: bodyTexts[0],
      siteName: metadata.siteName || location.hostname,
      publishedTime: metadata.publishedTime,
      html: postNodes.map(function(post) { return post.outerHTML; }).join("\n"),
      markdown: ["# " + title].concat(sections).join("\n\n"),
      textContent: normalizeText([title].concat(bodyTexts).join(" ")),
      hostAware: true,
      readerMode: false,
      contentType: "list"
    };
  }

  function discourseTopicPage(metadata) {
    if (!/(?:^|\/)t\//.test(location.pathname || "")) return false;
    if (!document.querySelector("#post-stream, .topic-post, article[data-post-id]")) return false;
    if (!document.querySelector(".topic-post .cooked, article[data-post-id] .cooked, [data-post-id] .cooked")) return false;

    var signature = platformSignature(metadata, [function() {
      return [
        location.hostname,
        metadata && metadata.siteName,
        metadata && metadata.title,
        metadataValue("generator", "name"),
        document.body && document.body.className
      ].join(" ");
    }]).signature;

    return /\bdiscourse\b/i.test(signature) || !!document.querySelector("#discourse-modal, #reply-control, .discourse-tags, meta[name='generator'][content*='Discourse' i]");
  }

  function discoursePostHeading(post) {
    var authorNode = post.querySelector(".topic-meta-data [data-user-card], .main-avatar[data-user-card], [data-user-card], .topic-meta-data .names .username, .topic-meta-data .username, .names .username, .creator a, .poster a");
    var author = normalizeText((authorNode && (authorNode.getAttribute("data-user-card") || authorNode.textContent)) || "");
    author = author.replace(/^@/, "");

    var time = post.querySelector(".topic-meta-data time, .topic-meta-data .relative-date, .post-meta time, time");
    var date = normalizeText((time && (time.getAttribute("datetime") || time.getAttribute("title") || time.textContent)) || "");
    if (date) date = date.replace(/T.*$/u, "");

    if (author && date) return "post by " + author + " on " + date;
    if (author) return "post by " + author;
    if (date) return "post on " + date;
    return "post";
  }
