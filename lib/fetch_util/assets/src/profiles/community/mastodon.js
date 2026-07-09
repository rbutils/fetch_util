  function mastodonPage(metadata) {
    var signature = normalizeText([
      metadata && metadata.title,
      metadata && metadata.siteName,
      firstText(["meta[name='application-name']", "meta[property='og:site_name']"], "content"),
      document.title
    ].join(" "));
    var mastodonLike = /mastodon/i.test(signature) || !!document.querySelector(".status__content, .status.status-public, .display-name, .columns-area__panels__main");
    var mastodonPath = /^\/(?:@[^/]+|tags\/[^/?#]+)/i.test(location.pathname || "");

    return mastodonLike && mastodonPath;
  }

  function mastodonSingleStatusPath() {
    return /^\/@[^/]+\/\d+\/?$/i.test(location.pathname || "");
  }

  function mastodonProfileHandle() {
    var pathParts = (location.pathname || "").split("/").filter(Boolean);
    if (pathParts[0] && pathParts[0].charAt(0) === "@") return pathParts[0] + "@" + location.hostname;

    var mainText = normalizeText(((document.querySelector("main") || {}).textContent) || "");
    var handleMatch = mainText.match(/@?[A-Za-z0-9_.-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/);
    if (!handleMatch) return "";

    return handleMatch[0].charAt(0) === "@" ? handleMatch[0] : "@" + handleMatch[0];
  }

  function mastodonStatusNodes() {
    var nodes = Array.prototype.slice.call(document.querySelectorAll(".status, .status-public, .status__wrapper, article.status-public"));
    Array.prototype.slice.call(document.querySelectorAll(".status__content, .status__content__text")).forEach(function(contentNode) {
      var article = contentNode.closest("article, .status-public, .status__wrapper");
      if (article && nodes.indexOf(article) < 0) nodes.push(article);
    });

    return nodes.filter(function(node, index) {
      if (node.closest("footer, nav")) return false;
      return nodes.indexOf(node) === index;
    });
  }

  function mastodonStatusBody(node) {
    var contentNode = node.querySelector(".status__content__text, .status__content") || node;
    var clone = cleanClone(contentNode);
    if (clone) {
      cleanupAgentRoot(clone);
      clone.querySelectorAll(".status__action-bar, .status__prepend, .status__prepend-icon, button, time").forEach(function(el) { el.remove(); });
      var markdown = markdownFor(clone.innerHTML);
      if (normalizeText(markdown).length >= 20) return markdown.trim();
    }

    return normalizeText(contentNode.textContent);
  }

  function mastodonStatusEntry(node) {
    var body = mastodonStatusBody(node);
    if (!body || normalizeText(body).length < 20) return null;
    if (/^(profiles directory|keyboard shortcuts|view source code|about mastodon|get the app)$/i.test(normalizeText(body))) return null;

    return {
      author: firstTextFromNode(node, [".status__display-name", ".display-name"]),
      time: firstTextFromNode(node, ["time"]),
      body: body,
      html: node.outerHTML
    };
  }

  function mastodonPostEntries() {
    var seen = {};
    var posts = [];

    mastodonStatusNodes().forEach(function(node) {
      if (posts.length >= 8) return;
      var status = mastodonStatusEntry(node);
      if (!status) return;

      var key = normalizeText(status.body).slice(0, 220).toLowerCase();
      if (seen[key]) return;
      seen[key] = true;

      var entry = normalizeText(status.body);
      if (status.author && entry.toLowerCase().indexOf(status.author.toLowerCase()) !== 0) entry = status.author + ": " + entry;
      if (status.time) entry += " (" + status.time + ")";
      posts.push(entry);
    });

    return posts;
  }

  function firstTextFromNode(root, selectors) {
    for (var i = 0; i < selectors.length; i += 1) {
      var node = root.querySelector(selectors[i]);
      var text = normalizeText(node && node.textContent);
      if (text) return text;
    }

    return "";
  }

  function mastodonProfileDetails() {
    return Array.prototype.slice.call(document.querySelectorAll("[class*='number_fields__item']")).map(function(node) {
      var text = normalizeText(node.textContent);
      var match = text.match(/^(Followers|Following|Posts|Joined)(.+)$/i);
      return match ? (match[1] + ": " + match[2]) : text;
    }).filter(Boolean).slice(0, 6);
  }

  function mastodonSingleStatusContent(metadata) {
    if (!mastodonSingleStatusPath()) return null;

    var statuses = mastodonStatusNodes().map(mastodonStatusEntry).filter(Boolean);
    if (!statuses.length) return null;

    var mainStatus = statuses[0];
    var replies = statuses.slice(1, 9);
    var title = firstText(["meta[property='og:title']"], "content") || metadata.title || document.title || "Mastodon post";
    title = normalizeText(title.replace(/\s*-\s*Mastodon\s*$/i, ""));
    var sections = ["# " + title];
    if (mainStatus.author) sections.push("- Author: " + mainStatus.author);
    if (mainStatus.time) sections.push("- Published: " + mainStatus.time);
    sections.push(mainStatus.body);
    if (replies.length) sections.push("## Replies");

    replies.forEach(function(reply) {
      var heading = reply.author || "Reply";
      if (reply.time) heading += " (" + reply.time + ")";
      sections.push("### " + heading);
      sections.push(reply.body);
    });

    var markdown = sections.filter(Boolean).join("\n\n").trim();
    if (normalizeText(markdown).length < 40) return null;

    return {
      title: title,
      byline: mainStatus.author || metadata.byline,
      excerpt: normalizeText(mainStatus.body).slice(0, 280) || metadata.excerpt,
      siteName: metadata.siteName || "Mastodon",
      publishedTime: metadata.publishedTime,
      html: [mainStatus].concat(replies).map(function(status) { return status.html; }).join("\n"),
      markdown: markdown,
      textContent: normalizeText(markdown),
      readerMode: false,
      contentType: "article",
      hostAware: true
    };
  }

  function mastodonContent(metadata) {
    if (!mastodonPage(metadata)) return null;

    var singleStatus = mastodonSingleStatusContent(metadata);
    if (singleStatus) return singleStatus;

    var pathParts = (location.pathname || "").split("/").filter(Boolean);
    var tag = pathParts[0] === "tags" ? pathParts[1] : "";
    var handle = tag ? "" : mastodonProfileHandle();
    var displayName = firstText(["[class*='account_header__name'] h1", ".display-name strong", ".display-name b", ".display-name"]) || "";
    if (displayName && handle && displayName.toLowerCase().indexOf(handle.toLowerCase()) >= 0) displayName = normalizeText(displayName.replace(handle, ""));
    var bio = firstText(["[class*='account_bio__bio']", ".account__header__content", ".account__header__bio", ".public-account-bio", ".profile__bio", "[data-testid='profile-note']"]);
    var posts = mastodonPostEntries();

    if (!tag && !handle && !displayName && !bio && posts.length === 0) return null;
    if (tag && posts.length === 0) return null;

    if (/^mastodon$/i.test(displayName) && handle) displayName = "";

    var title = tag ? ("#" + safeDecodeURI(tag) + " on Mastodon") : (displayName || handle || metadata.title || "Mastodon Profile");
    var sections = ["# " + title];
    var details = [];
    if (handle) details.push("- Handle: " + handle);
    mastodonProfileDetails().forEach(function(detail) { details.push("- " + detail); });
    if (details.length) sections.push(details.join("\n"));
    if (bio) sections.push(bio);
    if (posts.length) sections.push("## Recent Posts\n\n" + posts.map(function(post) { return "- " + post; }).join("\n"));

    var markdown = sections.filter(Boolean).join("\n\n").trim();
    if (normalizeText(markdown).length < 40) return null;

    return {
      title: title,
      byline: null,
      excerpt: bio || posts[0] || metadata.excerpt,
      siteName: metadata.siteName || "Mastodon",
      publishedTime: null,
      html: ((document.querySelector("main") || {}).innerHTML) || "",
      markdown: markdown,
      textContent: normalizeText(markdown),
      readerMode: false,
      contentType: "list",
      hostAware: true
    };
  }

  function registerMastodonProfiles() {
    registerHostAwareProfile(true, mastodonContent);
  }
