  function mediaWikiContentPage() {
    return !!document.querySelector("#mw-content-text .mw-parser-output, #mw-content-text .mw-body-content, #bodyContent .mw-parser-output");
  }

  function tropeWikiContent(metadata) {
    var node = document.querySelector("#main-article .article-content, #main-content .article-content, .article-content.retro-folders");
    if (!node) return null;

    var links = Array.prototype.filter.call(node.querySelectorAll("a[href]"), function(link) {
      return /\/pmwiki\/pmwiki\.php\/Main\//i.test(link.getAttribute("href") || "");
    }).length;
    var listItems = node.querySelectorAll("li").length;
    if (listItems < 20 || links < 10) return null;

    var title = firstText(["#main-article h1", "#main-content h1", "h1"]) ||
      normalizeText((metadata.title || document.title).replace(/\s*-\s*TV Tropes\s*$/i, ""));
    return profileArticleContent(metadata, node, {
      title: title,
      byline: null,
      publishedTime: null,
      minTextLength: 1200,
      rewriteRoot: function(root) {
        ["#modal_overlay", ".modal_overlay", "script", "style", "iframe", ".ad-unit", "[id*='ad-']", "[class*='ad-']", "[class*='advert']", "[class*='watch']"].forEach(function(selector) {
          root.querySelectorAll(selector).forEach(function(el) { el.remove(); });
        });
      }
    });
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

    var title = firstText(["#firstHeading", ".mw-first-heading", "h1.firstHeading", "h1"]) ||
      normalizeText((metadata.title || document.title).replace(/\s*[-|–]\s*(Wiktionary|Wikipedia|Wiki).*$/i, ""));

    return profileArticleContent(metadata, node, {
      title: title,
      byline: metadata.byline,
      minTextLength: 30,
      rewriteRoot: function(root) {
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
      }
    });
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

    var title = firstText(["h1.page-header__title", "#firstHeading", "h1"]) ||
      normalizeText((metadata.title || document.title).replace(/\s*\|\s*.*Wiki\s*\|\s*Fandom$/i, ""));

    return profileArticleContent(metadata, node, {
      title: title,
      byline: metadata.byline,
      minTextLength: 40,
      rewriteRoot: function(root) {
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
      }
    });
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

  function registerCommunityWikiLeadProfiles() {
    registerHostAwareProfile(true, tropeWikiContent);
  }

  function registerCommunityWikiProfiles() {
    registerHostAwareProfile(true, fandomContent);
    registerHostAwareProfile(true, mediaWikiContent);
    registerHostAwareProfile(true, stackExchangeContent);
  }
