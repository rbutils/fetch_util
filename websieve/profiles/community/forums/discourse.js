  function discourseTopicContent(metadata) {
    if (discourseTopicPage(metadata)) return discourseTopicArticleContent(metadata);
    if (discourseForumListPage(metadata)) return discourseForumListContent(metadata);
    return null;
  }

  function discourseTopicArticleContent(metadata) {
    var postNodes = Array.prototype.slice.call(document.querySelectorAll(".topic-post, article[data-post-id], [data-post-id].topic-post"));
    var sections = [];
    var bodyTexts = [];
    var seenPosts = {};
    var title = normalizeText(firstText([".fancy-title", "#topic-title h1", ".topic-title h1", "main h1", "article h1", "h1"]) || metadata.title || document.title);

    postNodes.forEach(function(post) {
      var cooked = post.querySelector(".cooked, .post-body");
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
      contentType: "social",
      socialKind: "thread",
      platform: "Discourse",
      community: discourseCategory()
    };
  }

  function discourseTopicPage(metadata) {
    if (!discourseShellSignals()) return false;
    if (!document.querySelector(".post-stream, .topic-post, article[data-post-id]")) return false;
    return !!document.querySelector(".fancy-title, #topic-title h1, .topic-title h1");
  }

  function discourseForumListPage(metadata) {
    if (!discourseShellSignals()) return false;
    if (discourseTopicPage(metadata)) return false;
    return !!document.querySelector(".topic-list, .topic-list-item, .latest-topic-list-item, .category-list");
  }

  function discourseForumListContent(metadata) {
    var listNodes = Array.prototype.slice.call(document.querySelectorAll(".topic-list-item, .latest-topic-list-item, .category-list-item, .topic-list tr"));
    var items = [];
    var seen = {};

    listNodes.forEach(function(node) {
      var link = node.querySelector("a.title, a[href*='/t/'], a[href*='/c/']");
      if (!link) return;

      var href = link.getAttribute("href") || "";
      var url = absoluteUrl(href);
      var text = normalizeText(link.textContent || link.getAttribute("aria-label") || "");
      if (!url || !text) return;

      var key = url + "|" + text;
      if (seen[key]) return;
      seen[key] = true;

      var detail = searchItemDetail(node, text);
      items.push({ text: text, url: url, detail: detail });
    });

    if (items.length < 3) return null;

    var result = listContentResult({
      title: normalizeText(firstText([".fancy-title", "#topic-title h1", ".topic-title h1", ".category-heading h1", ".category-title-box h1", "main h1", "h1"]) || metadata.title || document.title),
      excerpt: metadata.excerpt,
      siteName: metadata.siteName || location.hostname,
      items: items,
      html: listNodes.map(function(node) { return node.outerHTML; }).join("\n")
    });

    result.hostAware = true;
    result.contentType = "social";
    result.socialKind = "feed";
    result.platform = "Discourse";
    result.community = discourseCategory();
    return result;
  }

  function discourseCategory() {
    var category = document.querySelector(".category-breadcrumb a[href*='/c/'], .topic-category a[href*='/c/'], .category-name a[href*='/c/'], a.badge-category[href*='/c/']");
    return normalizeText((category && category.textContent) || "") || null;
  }

  function discourseShellSignals() {
    var body = document.body;
    var bodyClass = (body && body.className) || "";
    var hasShell = !!document.querySelector("#main-outlet, .wrap");
    var hasSetup = !!document.querySelector("#data-discourse-setup");
    var hasGenerator = !!document.querySelector("meta[name='generator'][content^='Discourse']");
    var hasTheme = !!document.querySelector("meta[name='discourse_theme_id']");
    var hasBodyClass = /\bember-application\b/.test(bodyClass) && /\bdiscourse\b/i.test(bodyClass);

    return hasShell && (hasSetup || hasGenerator || hasTheme || hasBodyClass);
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

  function registerDiscourseProfiles() {
    registerHostAwareProfile(true, discourseTopicContent);
  }
