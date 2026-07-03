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

  function mastodonProfileHandle() {
    var pathParts = (location.pathname || "").split("/").filter(Boolean);
    if (pathParts[0] && pathParts[0].charAt(0) === "@") return pathParts[0] + "@" + location.hostname;

    var mainText = normalizeText(((document.querySelector("main") || {}).textContent) || "");
    var handleMatch = mainText.match(/@?[A-Za-z0-9_.-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/);
    if (!handleMatch) return "";

    return handleMatch[0].charAt(0) === "@" ? handleMatch[0] : "@" + handleMatch[0];
  }

  function mastodonPostEntries() {
    var nodes = Array.prototype.slice.call(document.querySelectorAll(".status, .status-public, .status__wrapper, article.status-public"));
    Array.prototype.slice.call(document.querySelectorAll(".status__content, .status__content__text")).forEach(function(contentNode) {
      var article = contentNode.closest("article, .status-public, .status__wrapper");
      if (article && nodes.indexOf(article) < 0) nodes.push(article);
    });
    var seen = {};
    var posts = [];

    nodes.forEach(function(node) {
      if (posts.length >= 8) return;
      if (node.closest("footer, nav")) return;

      var contentNode = node.querySelector(".status__content__text, .status__content") || node;
      var text = normalizeText(contentNode.textContent);
      if (!text || text.length < 20) return;
      if (/^(profiles directory|keyboard shortcuts|view source code|about mastodon|get the app)$/i.test(text)) return;

      var author = firstTextFromNode(node, [".status__display-name", ".display-name"]);
      var time = firstTextFromNode(node, ["time"]);
      var key = text.slice(0, 220).toLowerCase();
      if (seen[key]) return;
      seen[key] = true;

      var entry = text;
      if (author && entry.toLowerCase().indexOf(author.toLowerCase()) !== 0) entry = author + ": " + entry;
      if (time) entry += " (" + time + ")";
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

  function mastodonContent(metadata) {
    if (!mastodonPage(metadata)) return null;

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

  function mediaWikiContentPage() {
    return !!document.querySelector("#mw-content-text .mw-parser-output, #mw-content-text .mw-body-content, #bodyContent .mw-parser-output");
  }

  function mediaWikiContent(metadata) {
    if (!mediaWikiContentPage()) return null;

    var isWikipedia = hostMatches(/(^|\.)wikipedia\.org$/);
    var isWiktionary = hostMatches(/(^|\.)wiktionary\.org$/);
    if (isWikipedia || isWiktionary) return null;

    var node = document.querySelector("#mw-content-text .mw-parser-output") ||
      document.querySelector("#mw-content-text .mw-body-content") ||
      document.querySelector("#bodyContent .mw-parser-output") ||
      document.querySelector("#mw-content-text");
    if (!node) return null;

    var root = cleanClone(node);

    root.querySelectorAll(".mw-editsection, .mw-jump-link, .toc, #toc, .catlinks, #catlinks, .navbox, .navbox-styles, .printfooter, .noprint, .mw-indicators, .mw-hidden-catlinks, .mw-empty-elt, .sistersitebox, .mw-authority-control, .mw-headline-anchor").forEach(function(el) {
      el.remove();
    });

    root.querySelectorAll("table.navbox, table.collapsible, .navbox, .footer-nav, .portal-bar, .portal, .succession-box").forEach(function(el) {
      el.remove();
    });

    root.querySelectorAll("#External_links, #References, #Notes, #See_also, #Further_reading").forEach(function(el) {
      var section = el.closest("section, div");
      if (section) section.remove();
    });

    cleanupAgentRoot(root);

    var markdown = markdownFor(root.innerHTML);
    var text = normalizeText(markdown);
    if (!text || text.length < 30) return null;

    var title = firstText(["#firstHeading", ".mw-first-heading", "h1.firstHeading", "h1"]) ||
      normalizeText((metadata.title || document.title).replace(/\s*[-|–]\s*(Wiktionary|Wikipedia|Wiki).*$/i, ""));

    if (title && !markdownStartsWithTitle(markdown, title)) {
      markdown = "# " + title + "\n\n" + markdown;
    }
    markdown = cleanupMarkdownNoise(markdown);

    return {
      title: title || metadata.title,
      byline: metadata.byline,
      excerpt: text.slice(0, 280) || metadata.excerpt,
      siteName: metadata.siteName || location.hostname,
      publishedTime: metadata.publishedTime,
      html: root.innerHTML,
      markdown: markdown,
      textContent: normalizeText(markdown),
      readerMode: false,
      contentType: "article",
      hostAware: true
    };
  }

  function fandomWikiPage() {
    return hostMatches(/(^|\.)fandom\.com$/) && !!document.querySelector(".mw-parser-output, .page-content, #content");
  }

  function fandomContent(metadata) {
    if (!fandomWikiPage()) return null;

    var node = document.querySelector(".mw-parser-output") ||
      document.querySelector(".page-content") ||
      document.querySelector("#content");
    if (!node) return null;

    var root = cleanClone(node);

    root.querySelectorAll(".navbox, table.navbox, .navbox-styles, .portable-infobox, .pi-collapse, .mw-editsection, .toc, #toc, .catlinks, #catlinks, .printfooter, .noprint, .mw-empty-elt, .page-footer, .article-footer, .fandom-community-header, .mcf-card-header, .mcf-card-footer, .mcf-card, .page-header__categories, .article-categories, .wds-button-group, .fandom-sticky-header").forEach(function(el) {
      el.remove();
    });

    // Remove signin/registration links and discussion prompts
    root.querySelectorAll("a[href*='auth.fandom.com'], a[href*='fandom.com/signin'], a[href*='fandom.com/register']").forEach(function(el) {
      var container = el.closest("div, span, li, p");
      if (container && normalizeText(container.textContent || "").length < 120) container.remove();
      else el.remove();
    });

    root.querySelectorAll("table").forEach(function(table) {
      var text = normalizeText(table.textContent || "");
      var links = table.querySelectorAll("a[href]").length;
      // Detect fandom nav index tables by header pattern (e.g. "Characters of Hades")
      var firstCell = table.querySelector("th, td, caption");
      var headerText = firstCell ? normalizeText(firstCell.textContent || "") : "";
      if (links >= 10 && /^(characters|items|locations|enemies|weapons|quests|episodes|levels|bosses|creatures|missions|npcs|monsters|equipment|fishes?|fish of|cast of)\b/i.test(headerText)) {
        table.remove(); return;
      }
      // Skip tables inside the article body that have content elements (paragraphs, headings)
      if (table.querySelector("p, h2, h3, h4, blockquote, pre")) return;
      if (links >= 15) {
        var rows = table.querySelectorAll("tr").length || 1;
        var linksPerRow = links / rows;
        // Remove dense navigation tables: many links, high link-to-row ratio
        if (linksPerRow > 3) { table.remove(); return; }
        // Remove large link-index tables at bottom (character/item navboxes without .navbox class)
        if (links >= 30 && text.length > 300) {
          var words = text.split(/\s+/).length;
          if (links / words > 0.15) { table.remove(); return; }
        }
      }
    });

    cleanupAgentRoot(root);

    var markdown = markdownFor(root.innerHTML);
    var text = normalizeText(markdown);
    if (!text || text.length < 40) return null;

    var title = firstText(["h1.page-header__title", "#firstHeading", "h1"]) ||
      normalizeText((metadata.title || document.title).replace(/\s*\|\s*.*Wiki\s*\|\s*Fandom$/i, ""));

    if (title && !markdownStartsWithTitle(markdown, title)) {
      markdown = "# " + title + "\n\n" + markdown;
    }
    markdown = cleanupMarkdownNoise(markdown);

    return {
      title: title || metadata.title,
      byline: metadata.byline,
      excerpt: text.slice(0, 280) || metadata.excerpt,
      siteName: metadata.siteName || location.hostname,
      publishedTime: metadata.publishedTime,
      html: root.innerHTML,
      markdown: markdown,
      textContent: normalizeText(markdown),
      readerMode: false,
      contentType: "article",
      hostAware: true
    };
  }

  function stackExchangeQuestionPage() {
    return /(^|\.)(stackexchange\.com|stackoverflow\.com|superuser\.com|serverfault\.com|askubuntu\.com|stackapps\.com|mathoverflow\.net)$/.test(location.hostname) &&
      /\/questions\//.test(location.pathname || "");
  }

  function stackExchangeContent(metadata) {
    if (!stackExchangeQuestionPage()) return null;

    var question = document.querySelector(".question, #question, #mainbar, [data-questionid]");
    var title = firstText(["h1 a.question-hyperlink", ".question-header h1", "#question-header h1", "main h1", "h1[itemprop='name']"]) ||
      normalizeText((metadata.title || document.title).replace(/\s*[-|]\s*.+?Stack Exchange$/i, "").replace(/\s*[-|]\s*Stack Overflow$/i, ""));
    var bodyNode = document.querySelector(".question .js-post-body, .question .s-prose, #question .js-post-body, #question .s-prose, .postcell .js-post-body, .postcell .s-prose, [data-questionid] .js-post-body, [data-questionid] .s-prose");
    var body = "";
    if (bodyNode) {
      var bodyClone = cleanClone(bodyNode);
      cleanupAgentRoot(bodyClone);
      body = markdownFor(bodyClone.innerHTML);
    }
    if (!body) body = firstText([".question .js-post-body", ".question .s-prose", "#question .js-post-body", "#question .s-prose", ".postcell .js-post-body", ".postcell .s-prose", "[data-questionid] .js-post-body", "[data-questionid] .s-prose"]);
    var byline = firstText([".question .user-details a", "#question .user-details a", ".postcell .user-details a", "[data-questionid] .user-details a"]);
    var answers = Array.prototype.slice.call(document.querySelectorAll(".answer, .js-answer, [data-answerid]")).map(function(node) {
      var scoreText = normalizeText(((node.querySelector(".js-vote-count, .vote-count-post") || {}).textContent || "0").replace(/[^\d-]+/g, ""));
      var score = parseInt(scoreText || "0", 10);
      var author = normalizeText(((node.querySelector(".user-details a") || {}).textContent || ""));
      var answerBodyNode = node.querySelector(".js-post-body, .s-prose");
      var answerBody = "";
      if (answerBodyNode) {
        var ansClone = cleanClone(answerBodyNode);
        cleanupAgentRoot(ansClone);
        answerBody = markdownFor(ansClone.innerHTML);
      }
      if (!answerBody) answerBody = normalizeText(((node.querySelector(".js-post-body, .s-prose") || {}).innerText || ""));
      var accepted = node.matches(".accepted-answer") || !!node.querySelector(".js-accepted-answer-indicator, .accepted-answer, [data-accepted='true']");

      return {
        score: isNaN(score) ? 0 : score,
        author: author,
        body: answerBody,
        accepted: accepted
      };
    }).filter(function(answer) {
      return answer.body.length >= 40;
    }).sort(function(a, b) {
      if (a.accepted !== b.accepted) return a.accepted ? -1 : 1;
      return b.score - a.score;
    }).slice(0, 4);

    if (!title || (!body && answers.length === 0)) return null;

    var sections = ["# " + title];
    if (byline) sections.push("- Asked by: " + byline);
    if (body) sections.push(body);
    if (answers.length) sections.push("## Top Answers");

    answers.forEach(function(answer, index) {
      var heading = answer.author || ("Answer " + (index + 1));
      if (answer.accepted) heading += " (accepted)";
      if (answer.score) heading += " - score " + answer.score;
      sections.push("### " + heading);
      sections.push(answer.body);
    });

    var markdown = sections.filter(Boolean).join("\n\n");

    return {
      title: title,
      byline: byline || metadata.byline,
      excerpt: body || metadata.excerpt,
      siteName: metadata.siteName || location.hostname,
      publishedTime: metadata.publishedTime,
      html: question ? question.outerHTML : "",
      markdown: markdown,
      textContent: normalizeText(markdown),
      readerMode: false,
      contentType: "article"
    };
  }
