  function wykopField(card, selector) {
    var node = card.querySelector(selector);
    return node ? normalizeText(node.getAttribute("datetime") || node.textContent || "") : "";
  }

  function wykopEntry(card) {
    var link = card.querySelector("h1 a[href^='/link/'], h2 a[href^='/link/'], h3 a[href^='/link/'], a[href^='/wpis/'], a.permalink[href]");
    if (!link) return null;

    var href = link.getAttribute("href");
    var url = absoluteUrl(href);
    var text = normalizeText(link.textContent || link.getAttribute("title") || "");
    var body = wykopField(card, ".body, .description, .excerpt, p");
    if (!text || !url || !/^https:\/\/wykop\.pl\/(?:link|wpis)\//.test(url)) return null;

    var details = [];
    var author = wykopField(card, ".author, [rel='author'], [data-author]");
    var time = wykopField(card, "time");
    var score = wykopField(card, ".score, [data-score]");
    var replies = wykopField(card, ".reply-count, .comment-counter, [data-replies]");
    var category = wykopField(card, ".tag, .category, [data-category]");
    var source = wykopField(card, ".source, .domain, [data-source]");
    var media = card.querySelector("img[src]");
    var mediaText = media ? normalizeText(media.getAttribute("alt") || "") : "";
    var mediaUrl = media ? absoluteUrl(media.getAttribute("src")) : "";
    var promoted = card.querySelector(".promoted, .recommendation, [data-promoted]");
    var pinned = card.closest && card.closest(".pinned, [data-pinned]");

    if (body && body !== text) details.push("Summary: " + body);
    if (author) details.push("Author: " + author);
    if (source) details.push("Source: " + source);
    if (time) details.push("Time: " + time);
    if (score) details.push("Score: " + score);
    if (replies) details.push("Replies: " + replies);
    if (category) details.push("Category: " + category);
    if (mediaText) details.push("Media: " + mediaText + (mediaUrl ? " (" + mediaUrl + ")" : ""));
    if (promoted) details.push("Promoted");
    if (pinned) details.push("Pinned");

    return { text: text, url: url, key: listCanonicalKey(url), detail: details.join(" - ") };
  }

  function wykopContent(metadata) {
    var path = location.pathname || "/";
    var tagMatch = path.match(/^\/tag\/([^/]+)\/?$/);
    if (path !== "/" && !tagMatch) return null;

    var selector = path === "/"
      ? "section.link-block.stream-home[id^='link-']"
      : "section.entry.stream-tag[id^='comment-'], section.link-block.stream-tag[id^='link-']";
    var seen = {};
    var items = [];
    document.querySelectorAll(selector).forEach(function(card) {
      var item = wykopEntry(card);
      if (!item || seen[item.key]) return;
      seen[item.key] = true;
      items.push(item);
    });
    if (items.length < 3) return null;

    var heading = tagMatch ? wykopField(document, ".tag-page h1, .tag-page h2, main h1") : "";
    var title = heading || metadata.title || document.title;
    var markdown = "# " + title + "\n\n" + items.map(function(item) {
      return "- [" + item.text + "](" + item.url + ")" + (item.detail ? " - " + item.detail : "");
    }).join("\n");
    return {
      title: title,
      byline: null,
      excerpt: items[0].text,
      siteName: metadata.siteName || "Wykop",
      publishedTime: null,
      html: "",
      textContent: normalizeText(markdown),
      markdown: markdown,
      readerMode: false,
      hostAware: true,
      contentType: "social",
      socialKind: "feed",
      platform: "Wykop",
      community: tagMatch ? (tagMatch[1] || null) : null,
      itemCount: items.length
    };
  }

  function registerWykopProfiles() {
    registerHostAwareProfile(/(^|\.)wykop\.pl$/i, wykopContent);
  }
