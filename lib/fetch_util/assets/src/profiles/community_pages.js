  function mediaWikiContentPage() {
    return !!document.querySelector("#mw-content-text .mw-parser-output, #mw-content-text .mw-body-content, #bodyContent .mw-parser-output");
  }

  function mediaWikiContent(metadata) {
    if (!mediaWikiContentPage()) return null;

    var isWikipedia = hostMatches(/(^|\.)wikipedia\.org$/);
    if (isWikipedia) return null;

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

  function instagramContent(metadata, pageText) {
    if (!hostMatches(/(^|\.)instagram\.com$/)) return null;
    // Instagram shows a dismissible login modal over profile content.
    // If the modal was dismissed and real content is available, let normal
    // Readability extraction handle it. Only return a login wall fallback
    // when content is truly gated.
    var pt = pageText || "";

    // Try the current pathname first; fall back to ?next= only for real
    // login/checkpoint redirect shells so we can still salvage the target
    // profile or post path without rewriting the actual final URL.
    var pathParts = (location.pathname || "").split("/").filter(Boolean);
    if (/^(accounts|checkpoint|challenge|challenge_required|suspended|restricted)$/i.test(pathParts[0] || "")) {
      var nextParam = (location.search || "").match(/[?&]next=([^&]+)/);
      if (nextParam) {
        var decoded = safeDecodeURI(nextParam[1]);
        decoded = (decoded || "").replace(/^https?:\/\/[^\/]+/, "");
        pathParts = decoded.split("/").filter(Boolean);
      } else {
        pathParts = [];
      }
    }

    var pathSrc = pathParts[0] || "";
    var pathArg = pathParts[1] || "";
    var isPostPath = /^(p|reel|reels|tv)$/i.test(pathSrc) && !!pathArg;
    var postPath = isPostPath ? "/" + pathParts.slice(0, 2).join("/") + "/" : "";
    var username = safeDecodeURI(pathSrc).replace(/[-_]+/g, " ");
    username = normalizeText(username);
    // Skip generic path segments that aren't usernames
    if (isPostPath || /^(accounts|checkpoint|challenge|challenge_required|explore|stories|direct)$/i.test(username)) username = "";

    if (isPostPath) {
      var rawTitle = normalizeText((metadata.title || "").replace(/\s*[\u2022•|]\s*Instagram.*$/i, "").replace(/\s*\|\s*Instagram\s*$/i, ""));
      var titleMatch = rawTitle.match(/^(.*?)\s+on Instagram:\s*"([\s\S]*)"$/i);
      var authorName = titleMatch ? normalizeText(titleMatch[1]) : "";
      var titleCaption = titleMatch ? normalizeText(titleMatch[2]) : "";
      var rawExcerpt = metadata.excerpt || "";
      if (/create an account|log in to instagram|sign up/i.test(rawExcerpt)) rawExcerpt = "";

      var likesMatch = rawExcerpt.match(/([\d,.]+[MKB]?)\s*likes?\b/i);
      var commentsMatch = rawExcerpt.match(/([\d,.]+[MKB]?)\s*comments?\b/i);
      var handleMatch = rawExcerpt.match(/-\s*([a-z0-9._]+)\s+on\s+/i);
      var publishedMatch = rawExcerpt.match(/\bon\s+([^:]+):\s*"/i);
      var excerptCaptionMatch = rawExcerpt.match(/:\s*"([\s\S]*?)"\.?\s*$/);
      var handle = handleMatch ? normalizeText(handleMatch[1]) : "";
      var caption = normalizeText(titleCaption || (excerptCaptionMatch && excerptCaptionMatch[1]) || "");
      var hasVisiblePost = (function() {
        var article = document.querySelector("article");
        var articleText = normalizeText(article && article.innerText);
        return articleText.length > 120 && !/something went wrong|log in to instagram|sign up to see/i.test(articleText);
      })();

      if (hasVisiblePost) return null;

      var details = [];
      var pathLabel = /^(reel|reels|tv)$/i.test(pathSrc) ? "Reel" : "Post";
      if (handle) details.push("Profile: @" + handle);
      if (postPath) details.push(pathLabel + ": " + postPath);
      if (likesMatch) details.push(normalizeText(likesMatch[1]) + " likes");
      if (commentsMatch) details.push(normalizeText(commentsMatch[1]) + " comments");
      if (metadata.image) details.push("Image: " + metadata.image);
      if (metadata.video) details.push("Video: " + metadata.video);

      return articleContentFromParts({
        title: authorName ? authorName + " on Instagram" : (rawTitle || "Instagram post"),
        byline: handle ? "@" + handle : (authorName || null),
        publishedTime: publishedMatch ? normalizeText(publishedMatch[1]) : (metadata.publishedTime || null),
        description: caption || "This Instagram post requires login before the original content is available.",
        details: details,
        siteName: metadata.siteName || "Instagram",
        hostAware: true
      });
    }

    // Check if real profile content is visible (modal was dismissed).
    // Indicators: follower/post count links, post grid images, profile header section.
    var hasProfileContent = (function() {
      // Instagram profile pages have header sections with stats
      var headerSection = document.querySelector('header section');
      if (!headerSection) return false;
      // Check for meaningful stats text (followers, following, posts with numbers)
      var headerText = headerSection.innerText || "";
      if (/([\d,.]+[MKB]?)\s*(followers?|following|posts?)/i.test(headerText)) return true;
      // Also check for profile image grid (at least a few post thumbnails)
      var imgs = document.querySelectorAll('article img, main img[srcset]');
      if (imgs.length >= 3) return true;
      return false;
    })();

    if (hasProfileContent) {
      // Real content available — let normal Readability extraction handle it.
      // But Readability often struggles with Instagram's complex React DOM,
      // so build a structured extraction instead.
      var title = normalizeText((metadata.title || "").replace(/\s*[\u2022•|]\s*Instagram.*$/i, "")) || metadata.title;

      // Extract bio from header
      var headerSection = document.querySelector('header section');
      var bioDiv = headerSection ? headerSection.querySelector('div > span') : null;
      // Look for the bio text — usually in a span within header, after the stats row
      var bioText = "";
      if (headerSection) {
        // Walk through header spans looking for the bio (longer text, not stats)
        var spans = headerSection.querySelectorAll('span');
        for (var i = 0; i < spans.length; i++) {
          var spanText = normalizeText(spans[i].innerText || "");
          if (spanText.length > 30 && !/^\d/.test(spanText) && !/follow/i.test(spanText)) {
            bioText = spanText;
            break;
          }
        }
      }

      // Collect stats
      var stats = [];
      var followerMatch = pt.match(/([\d,.]+[MKB]?)\s*(?:Followers|follower)/i);
      var followingMatch = pt.match(/([\d,.]+[MKB]?)\s*(?:Following|following)/i);
      var postMatch = pt.match(/([\d,.]+[MKB]?)\s*(?:Posts?|post)/i);
      if (postMatch) stats.push(postMatch[1] + " posts");
      if (followerMatch) stats.push(followerMatch[1] + " followers");
      if (followingMatch) stats.push(followingMatch[1] + " following");

      var description = bioText || metadata.excerpt || "";
      // Discard generic login/signup CTA descriptions
      if (/create an account|log in to instagram|sign up/i.test(description)) description = "";
      if (stats.length) {
        description = (description ? description + "\n\n" : "") + stats.join(", ") + ".";
      }

      var details = [];
      if (username) details.push("Profile: @" + pathSrc);

      return articleContentFromParts({
        title: title || ("Instagram" + (username ? " - " + username : "")),
        description: description,
        details: details,
        siteName: metadata.siteName || "Instagram",
        hostAware: true
      });
    }

    // Fallback: login wall is still blocking content — salvage OG metadata
    var title = normalizeText((metadata.title || "").replace(/\s*[\u2022•|]\s*Instagram.*$/i, "")) || metadata.title;

    // Parse stats and bio from OG description / meta description.
    // Typical formats:
    //   meta[description]: "673M Followers, 643 Following, 4,026 Posts - Cristiano Ronaldo (@cristiano) on Instagram: \"bio text\""
    //   og:description:    "673M Followers, 643 Following, 4,026 Posts - See Instagram photos and videos from Cristiano Ronaldo (@cristiano)"
    var rawExcerpt = metadata.excerpt || "";
    // Discard generic login/signup CTA descriptions that add no value
    if (/create an account|log in to instagram|sign up/i.test(rawExcerpt)) rawExcerpt = "";

    var statsLine = "";
    var bioText = "";

    // Extract structured stats from meta description (e.g. "673M Followers, 643 Following, 4,026 Posts")
    var statsMatch = rawExcerpt.match(/^([\d,.]+[MKB]?\s+Followers?,\s*[\d,.]+[MKB]?\s+Following,\s*[\d,.]+[MKB]?\s+Posts?)\s*[-–—]/i);
    if (statsMatch) {
      statsLine = statsMatch[1];
      // Extract bio from the " on Instagram: \"bio\"" suffix
      var bioMatch = rawExcerpt.match(/on Instagram:\s*"(.+)"$/);
      if (bioMatch && bioMatch[1].trim()) bioText = bioMatch[1].trim();
    }

    var description = "";
    if (bioText) description = bioText;
    if (statsLine) description = (description ? description + "\n\n" : "") + statsLine + ".";

    // If we couldn't parse structured stats, try page text as fallback
    if (!statsLine) {
      var stats = [];
      var followerMatch = pt.match(/([\d,.]+[MKB]?)\s*(?:Followers|follower|Takipçi|подписчик|متابع)/i);
      var postMatch = pt.match(/([\d,.]+[MKB]?)\s*(?:Posts?|post|Gönderi|публикац|منشور)/i);
      if (followerMatch) stats.push(followerMatch[1] + " followers");
      if (postMatch) stats.push(postMatch[1] + " posts");
      if (stats.length) description = (description ? description + " " : "") + stats.join(", ") + ".";
    }

    // Final fallback if we have no description at all
    if (!description && username) {
      description = "This Instagram page for " + username + " requires login before the original content is available.";
    } else if (!description) {
      description = "This Instagram page requires login before the original content is available.";
    }

    var fallbackDetails = ["Access: Instagram login wall"];
    if (metadata.image) fallbackDetails.push("Image: " + metadata.image);

    return articleContentFromParts({
      title: title || ("Instagram" + (username ? " - " + username : "")),
      description: description,
      details: fallbackDetails,
      siteName: metadata.siteName || "Instagram",
      hostAware: true
    });
  }

  function facebookContent(metadata, pageText) {
    if (!hostMatches(/(^|\.)facebook\.com$/)) return null;
    // Facebook gates most content behind login, but when the login/cookie
    // dialogs are dismissed (via stabilize_facebook in browser.rb), real page
    // content becomes visible: bio/intro, posts, engagement stats.
    // Use innerText (layout-aware) rather than pageText (textContent-based)
    // because Facebook's DOM produces concatenated tokens with textContent
    // (e.g. "ZuckerbergIntro") while innerText preserves visual whitespace.
    var pt = (document.body && document.body.innerText) || pageText || "";

    // Extract page/profile path from URL, handling /login/?next= redirects
    var pathSrc = (location.pathname || "").split("/").filter(Boolean)[0] || "";
    if (/^(login|checkpoint|recover|dialog|ajax|connect|sharer)$/i.test(pathSrc)) {
      var nextParam = (location.search || "").match(/[?&]next=([^&]+)/);
      if (nextParam) {
        var decoded = safeDecodeURI(nextParam[1]);
        decoded = (decoded || "").replace(/^https?:\/\/[^\/]+/, "");
        pathSrc = decoded.split("/").filter(Boolean)[0] || "";
      } else {
        pathSrc = "";
      }
    }
    // Skip generic/system path segments that aren't page names
    if (/^(login|watch|marketplace|groups|gaming|events|pages|profile\.php|photo|story|reel|permalink|hashtag)$/i.test(pathSrc)) pathSrc = "";
    var pageName = safeDecodeURI(pathSrc).replace(/[-_.]+/g, " ");
    pageName = normalizeText(pageName);

    var title = normalizeText((metadata.title || "").replace(/\s*[-–—|]\s*(Facebook|Log in or sign up).*$/i, "").replace(/\s*\|\s*Facebook\s*$/i, "")) || metadata.title;
    // Discard generic login-page titles
    if (/^(facebook\s*[-–—]?\s*log in|log in to facebook|log in or sign up)/i.test(title || "")) {
      title = pageName || "Facebook";
    }

    // ── Real content path: check if dialogs were dismissed and page rendered ──
    // When Facebook serves real page content, the body text includes followers/
    // following counts, an "Intro" section, and post content.
    var hasRealContent = (function() {
      if (pt.length < 200) return false;
      // Must have followers/following counts AND intro/about content
      var hasFollowers = /([\d,.]+[MKB]?)\s*followers?/i.test(pt);
      var hasIntro = /\bIntro\b/.test(pt);
      return hasFollowers && hasIntro;
    })();

    if (hasRealContent) {
      // Extract structured info from page text
      var sections = [];

      // Page type / category (e.g., "Page · Government organization")
      var categoryMatch = pt.match(/(?:Page|Profile)\s*·\s*([^\n]+)/);
      if (categoryMatch) sections.push("Category: " + normalizeText(categoryMatch[1]));

      // Followers / following
      var followersMatch = pt.match(/([\d,.]+[MKB]?)\s*followers?/i);
      var followingMatch = pt.match(/([\d,.]+[MKB]?)\s*following/i);
      if (followersMatch) sections.push(followersMatch[1] + " followers");
      if (followingMatch) sections.push(followingMatch[1] + " following");

      // Intro/bio text: extract text between "Intro" and the next section heading
      var introStart = pt.indexOf("Intro\n");
      var introText = "";
      if (introStart >= 0) {
        var afterIntro = pt.substring(introStart + 6);
        // Stop at next known section: Photos, Videos, About, Posts, etc.
        var sectionEnd = afterIntro.search(/\n(?:Photos|Videos|About|Posts|Reels|Events|See all|Page ·|Information about)\b/);
        introText = normalizeText(sectionEnd > 0 ? afterIntro.substring(0, sectionEnd) : afterIntro.substring(0, 500));
      }

      // Contact info — restrict to the Intro/About area to avoid matching
      // reaction counts or post content that look like URLs/emails
      var contactArea = introText || pt.substring(0, Math.min(pt.length, 1500));
      var emailMatch = contactArea.match(/([\w.+-]+@[\w.-]+\.\w{2,})/);
      var websiteMatch = contactArea.match(/\b(https?:\/\/[\w.-]+[\w.]{2,}(?:\/[\w.-]*)*)\s/i);

      // Extract posts: look for post patterns (author + timestamp + content)
      var posts = [];
      // Facebook page posts show as: "Page Name\n\nTimestamp\n·\nPost text"
      var postPattern = new RegExp(
        normalizeText(title || "").replace(/[.*+?^${}()|[\]\\]/g, "\\$&") +
        "\\s*\\n\\s*(?:\\d+[hd]|\\d+ (?:hour|day|minute|week|month)s? ago|Yesterday|Just now|\\w+ \\d+(?:,? \\d+)?)\\s*\\n\\s*·?\\s*\\n([\\s\\S]*?)(?=\\n(?:All reactions|Like|Comment|Share|\\d+ comment))",
        "gi"
      );
      var postMatch;
      while ((postMatch = postPattern.exec(pt)) !== null) {
        var postText = normalizeText(postMatch[1]);
        if (postText && postText.length > 10) {
          // Clean "… See more" truncation
          postText = postText.replace(/…\s*See more\s*$/i, "…");
          posts.push(postText);
        }
      }

      // If regex didn't match, try extracting text blocks from dir=auto divs
      if (posts.length === 0) {
        var dirAutoDivs = document.querySelectorAll("div[dir=auto]");
        for (var i = 0; i < dirAutoDivs.length; i++) {
          var divText = normalizeText(dirAutoDivs[i].innerText || "");
          if (divText.length > 50 && divText.length < 3000 &&
              !/^(log in|sign up|create|cookie|privacy|terms|information about|see more from)/i.test(divText)) {
            // Clean "… See more" truncation
            divText = divText.replace(/…\s*See more\s*$/i, "…");
            posts.push(divText);
          }
        }
      }

      // Deduplicate posts (Facebook's DOM often has duplicated elements)
      var seenPosts = {};
      posts = posts.filter(function(p) {
        var key = p.substring(0, 80).toLowerCase();
        if (seenPosts[key]) return false;
        seenPosts[key] = true;
        return true;
      });

      // Build description
      var description = "";
      if (introText) description = introText;

      // Contact info line
      var contactParts = [];
      if (emailMatch) contactParts.push(emailMatch[1]);
      if (websiteMatch && !/facebook\.com/i.test(websiteMatch[1])) contactParts.push(websiteMatch[1]);
      if (contactParts.length) {
        description += (description ? "\n\n" : "") + "Contact: " + contactParts.join(" | ");
      }

      // Posts section
      if (posts.length > 0) {
        description += (description ? "\n\n" : "") + "## Recent Posts\n\n";
        for (var j = 0; j < Math.min(posts.length, 5); j++) {
          description += posts[j] + "\n\n";
        }
        description = description.replace(/\n\n$/, "");
      }

      // OG stats as fallback if page text didn't have them
      if (!followersMatch) {
        var rawExcerpt = metadata.excerpt || "";
        var ogLikes = rawExcerpt.match(/([\d][\d,.\s]*\d)\s*likes?\b/i);
        if (ogLikes) sections.push(normalizeText(ogLikes[1]) + " likes");
      }

      var details = sections;
      if (metadata.image) details.push("Image: " + metadata.image);

      return articleContentFromParts({
        title: title || ("Facebook" + (pageName ? " - " + pageName : "")),
        description: description,
        details: details,
        siteName: metadata.siteName || "Facebook",
        hostAware: true
      });
    }

    // ── Fallback: login wall still blocking content — salvage OG metadata ──
    var rawExcerpt = metadata.excerpt || "";
    // Discard generic login/signup CTA descriptions
    if (/create an account or log into facebook|connect with friends|facebook helps you connect/i.test(rawExcerpt)) rawExcerpt = "";

    var likesCount = "";
    var talkingAbout = "";
    var bioText = "";

    // Try structured format: "Name. 121,148,555 likes · 479,943 talking about this. Bio."
    var likesMatch = rawExcerpt.match(/([\d][\d,.\s]*\d)\s*likes?\b/i);
    var talkingMatch = rawExcerpt.match(/([\d][\d,.\s]*\d)\s*talking about this/i);
    if (likesMatch) likesCount = normalizeText(likesMatch[1]) + " likes";
    if (talkingMatch) talkingAbout = normalizeText(talkingMatch[1]) + " talking about this";

    // Extract bio: text after "talking about this." or after "likes." if no talking
    if (talkingMatch) {
      var afterTalking = rawExcerpt.substring(rawExcerpt.indexOf(talkingMatch[0]) + talkingMatch[0].length);
      afterTalking = afterTalking.replace(/^[\s.·]+/, "");
      if (afterTalking && !/^(see |view |log in)/i.test(afterTalking)) bioText = normalizeText(afterTalking);
    } else if (likesMatch) {
      var afterLikes = rawExcerpt.substring(rawExcerpt.indexOf(likesMatch[0]) + likesMatch[0].length);
      afterLikes = afterLikes.replace(/^[\s.·]+/, "");
      if (afterLikes && !/^(see |view |log in)/i.test(afterLikes)) bioText = normalizeText(afterLikes);
    } else if (rawExcerpt) {
      // No structured stats — use the whole excerpt if it's not a CTA
      bioText = rawExcerpt;
    }

    // Build description
    var fallbackDescription = "";
    if (bioText) fallbackDescription = bioText;
    var statsLine = [likesCount, talkingAbout].filter(Boolean).join(" · ");
    if (statsLine) fallbackDescription = (fallbackDescription ? fallbackDescription + "\n\n" : "") + statsLine + ".";

    // Fall back to page text for stats if OG didn't have them
    if (!likesCount) {
      var ptLikesMatch = pt.match(/([\d][\d,.\s]*\d)\s*(?:likes?|people like this)/i);
      if (ptLikesMatch) {
        var ptStats = normalizeText(ptLikesMatch[1]) + " likes";
        fallbackDescription = (fallbackDescription ? fallbackDescription + " " : "") + ptStats + ".";
      }
    }

    if (!fallbackDescription && pageName) {
      fallbackDescription = "This Facebook page for " + pageName + " requires login before the original content is available.";
    } else if (!fallbackDescription) {
      fallbackDescription = "This Facebook page requires login before the original content is available.";
    }

    var fallbackDetails = ["Access: Facebook login wall"];
    if (metadata.image) fallbackDetails.push("Image: " + metadata.image);

    return articleContentFromParts({
      title: title || ("Facebook" + (pageName ? " - " + pageName : "")),
      description: fallbackDescription,
      details: fallbackDetails,
      siteName: metadata.siteName || "Facebook",
      hostAware: true
    });
  }

  function telegramContent(metadata, pageText) {
    // Handle t.me (channel/group links), telegram.org (blog/apps), and telegra.ph (articles)
    if (!hostMatches(/(^|\.)(t\.me|telegram\.(org|me)|telegra\.ph)$/)) return null;

    var pt = pageText || "";

    // telegra.ph (Telegraph) — standalone article platform
    if (hostMatches(/(^|\.)telegra\.ph$/)) {
      var articleBody = document.querySelector("article, .tl_article");
      if (articleBody) {
        var clone = cleanClone(articleBody);
        if (clone) {
          // Strip "Report content on this page" footer chrome
          removeNodesByText(clone, "a, span, div, p", /^(report content on this page|report|edit)$/i);
          var md = markdownFor(clone.innerHTML) || normalizeText(clone.textContent);
          if (md && normalizeText(md).length > 20) {
            return {
              title: metadata.title || firstText(["h1", ".tl_article_header h1"]),
              excerpt: metadata.excerpt,
              siteName: "Telegraph",
              html: clone.innerHTML,
              markdown: md,
              textContent: normalizeText(md),
              readerMode: false,
              contentType: "article",
              hostAware: true
            };
          }
        }
      }
      return null;
    }

    // telegram.org/blog — standard web pages, use generic extraction
    if (hostMatches(/(^|\.)telegram\.org$/)) return null;

    // t.me — channel/group/user pages
    // t.me/s/{channel} routes are public previews with full message history
    var isPublicPreview = /^\/s\//i.test(location.pathname);
    var channelName = (location.pathname || "").split("/").filter(Boolean);
    if (isPublicPreview) channelName = channelName.slice(1); // skip "s"
    channelName = channelName[0] || "";

    if (isPublicPreview) {
      // Public preview pages have rich message content
      var messageContainer = document.querySelector(".tgme_channel_history, .tgme_body, main");
      if (messageContainer) {
        var previewClone = cleanClone(messageContainer);
        if (previewClone) {
          // Clean up Telegram chrome
          removeNodesByText(previewClone, "a, span, div, i", /^(view in telegram|preview channel|join|open|if you have telegram|you can contact|you can view and join|load more)$/i);
          previewClone.querySelectorAll("[class*='widget_message_author'], [class*='tgme_widget_message_date']").forEach(function(el) {
            // Keep author/date — they provide useful context for message attribution
          });
          var previewMd = markdownFor(previewClone.innerHTML) || normalizeText(previewClone.textContent);
          if (previewMd && normalizeText(previewMd).length > 50) {
            var channelTitle = firstText([".tgme_channel_info_header_title", ".tgme_header_title", "h1"]) || metadata.title || channelName;
            // Extract channel description and subscriber count for preview header
            var channelDescEl = document.querySelector(".tgme_channel_info_description");
            var channelDesc = channelDescEl ? normalizeText(channelDescEl.textContent) : "";
            var counterEls = document.querySelectorAll(".counter_value");
            var subscriberCount = counterEls.length > 0 ? normalizeText(counterEls[0].textContent) : "";
            var headerParts = [];
            headerParts.push("# " + channelTitle);
            var headerMeta = ["- Platform: Telegram"];
            if (subscriberCount) headerMeta.push("- " + subscriberCount + " subscribers");
            if (metadata.image) headerMeta.push("- Image: " + metadata.image);
            headerParts.push(headerMeta.join("\n"));
            if (channelDesc) headerParts.push(channelDesc);
            headerParts.push("---\n\n" + previewMd);

            var fullMd = headerParts.join("\n\n");
            return {
              title: channelTitle,
              excerpt: channelDesc || metadata.excerpt,
              siteName: "Telegram",
              html: previewClone.innerHTML,
              markdown: fullMd,
              textContent: normalizeText(fullMd),
              readerMode: false,
              contentType: "article",
              hostAware: true
            };
          }
        }
      }
    }

    // t.me/{channel} — landing page with minimal info and "View in Telegram" CTA
    // DOM selectors: .tgme_page_title (name), .tgme_page_description (about),
    // .tgme_page_extra (e.g. "10 943 subscribers")
    var title = firstText([".tgme_page_title", ".tgme_channel_info_header_title", "h1"]) || metadata.title || channelName;
    // Try DOM description first (more reliable than OG for channel about text)
    var descriptionEl = document.querySelector(".tgme_page_description");
    var description = (descriptionEl ? normalizeText(descriptionEl.textContent) : "") || metadata.excerpt || "";
    // Discard generic CTA descriptions
    if (/you can contact .+ right away|if you have telegram/i.test(description)) description = "";

    // Extract subscriber/member count from DOM (.tgme_page_extra) or page text
    var extraEl = document.querySelector(".tgme_page_extra");
    var extraText = extraEl ? normalizeText(extraEl.textContent) : "";
    var subscriberMatch = extraText.match(/([\d\s,.]+)\s*(?:subscribers?|members?|online)/i) ||
                          pt.match(/([\d\s,.]+)\s*(?:subscribers?|members?|подписчик|участник)/i);

    var details = ["Platform: Telegram"];
    if (subscriberMatch) details.push(normalizeText(subscriberMatch[1]) + " subscribers");
    if (metadata.image) details.push("Image: " + metadata.image);

    // If we have very little to show, produce a minimal card
    if (!description && !title) return null;

    return articleContentFromParts({
      title: title,
      description: description || "Telegram channel. View in Telegram for full content.",
      details: details,
      siteName: "Telegram",
      hostAware: true
    });
  }

  function twitterContent(metadata, pageText) {
    if (!hostMatches(/(^|\.)(twitter\.com|x\.com)$/)) return null;

    var isStatusPage = /^\/[^/]+\/status\/\d+/.test(location.pathname);

    // --- ld+json structured data (profile pages only) ---
    var ldProfile = null;
    try {
      var scripts = document.querySelectorAll('script[type="application/ld+json"]');
      for (var si = 0; si < scripts.length; si++) {
        var parsed = JSON.parse(scripts[si].textContent);
        if (parsed && parsed["@type"] === "ProfilePage" && parsed.mainEntity) {
          ldProfile = parsed.mainEntity;
          break;
        }
      }
    } catch (e) { /* ignore */ }

    // --- Profile page extraction ---
    if (!isStatusPage) {
      var nameEl = document.querySelector('[data-testid="UserName"]');
      var descEl = document.querySelector('[data-testid="UserDescription"]');
      var urlEl = document.querySelector('[data-testid="UserUrl"]');
      var joinEl = document.querySelector('[data-testid="UserJoinDate"]');
      var locEl = document.querySelector('[data-testid="UserLocation"]');
      var birthEl = document.querySelector('[data-testid="UserBirthdate"]');

      // Extract display name and handle from UserName element
      var displayName = "";
      var handle = "";
      if (nameEl) {
        var nameParts = normalizeText(nameEl.textContent).split(/\s*@/);
        displayName = normalizeText(nameParts[0]);
        if (nameParts[1]) handle = "@" + normalizeText(nameParts[1]);
      }
      if (!displayName && ldProfile) displayName = ldProfile.name || "";
      if (!handle && ldProfile && ldProfile.additionalName) handle = ldProfile.additionalName;
      if (!handle) {
        var pathHandle = (location.pathname || "").split("/").filter(Boolean)[0];
        if (pathHandle && !/^(home|explore|search|notifications|messages|settings|i)$/i.test(pathHandle)) {
          handle = "@" + pathHandle;
        }
      }

      var bio = descEl ? normalizeText(descEl.textContent) : "";
      if (!bio && ldProfile && ldProfile.description) bio = normalizeText(ldProfile.description);

      var userLocation = locEl ? normalizeText(locEl.textContent) : "";
      if (!userLocation && ldProfile && ldProfile.homeLocation) userLocation = ldProfile.homeLocation.name || "";

      var userUrl = urlEl ? normalizeText(urlEl.textContent) : "";
      var joinDate = joinEl ? normalizeText(joinEl.textContent) : "";
      var birthDate = birthEl ? normalizeText(birthEl.textContent) : "";

      // Stats from ld+json (most reliable — exact counts)
      var followers = "";
      var following = "";
      var tweetCount = "";
      if (ldProfile && ldProfile.interactionStatistic) {
        ldProfile.interactionStatistic.forEach(function(stat) {
          var action = stat.interactionType || "";
          if (/FollowAction/.test(action)) followers = String(stat.userInteractionCount);
          if (/SubscribeAction/.test(action)) following = String(stat.userInteractionCount);
          if (/WriteAction/.test(action)) tweetCount = String(stat.userInteractionCount);
        });
      }

      // Fallback: parse follow links from DOM
      if (!followers) {
        var followerLink = document.querySelector('a[href$="/verified_followers"], a[href$="/followers"]');
        if (followerLink) followers = normalizeText(followerLink.textContent).replace(/\s*followers?$/i, "");
      }
      if (!following) {
        var followingLink = document.querySelector('a[href$="/following"]');
        if (followingLink) following = normalizeText(followingLink.textContent).replace(/\s*following$/i, "");
      }

      // Format follower counts for readability
      function formatCount(n) {
        var num = parseInt(n, 10);
        if (isNaN(num)) return n;
        if (num >= 1000000) return (num / 1000000).toFixed(1).replace(/\.0$/, "") + "M";
        if (num >= 10000) return (num / 1000).toFixed(1).replace(/\.0$/, "") + "K";
        return num.toLocaleString();
      }

      // Profile image
      var profileImage = "";
      if (ldProfile && ldProfile.image && ldProfile.image.contentUrl) {
        profileImage = ldProfile.image.contentUrl;
      }
      if (!profileImage) {
        var avatarImg = document.querySelector('[data-testid^="UserAvatar"] img[src*="profile_images"]');
        if (avatarImg) profileImage = avatarImg.src;
      }

      // Website from ld+json relatedLink (filter out t.co redirects if real URL available)
      if (!userUrl && ldProfile && ldProfile.relatedLink) {
        var links = Array.isArray(ldProfile.relatedLink) ? ldProfile.relatedLink : [ldProfile.relatedLink];
        var realLinks = links.filter(function(l) { return !/t\.co\//.test(l); });
        userUrl = (realLinks[0] || links[0] || "").replace(/^https?:\/\//, "");
      }

      // --- Extract tweets from timeline ---
      var tweets = [];
      var tweetEls = document.querySelectorAll('[data-testid="tweet"]');
      for (var ti = 0; ti < Math.min(tweetEls.length, 5); ti++) {
        var tweetEl = tweetEls[ti];
        var textEl = tweetEl.querySelector('[data-testid="tweetText"]');
        if (!textEl) continue;

        var tweetText = normalizeText(textEl.textContent);
        if (!tweetText || tweetText.length < 5) continue;

        // Tweet metadata: author + timestamp
        var authorEl = tweetEl.querySelector('[data-testid="User-Name"]');
        var timeEl = tweetEl.querySelector("time");
        var pinned = tweetEl.querySelector('[data-testid="socialContext"]');

        var tweetAuthor = "";
        if (authorEl) {
          var authorText = normalizeText(authorEl.textContent);
          // Format: "Display Name @handle · timestamp"
          var authorMatch = authorText.match(/^(.+?)(\s*@\w+)/);
          if (authorMatch) tweetAuthor = authorMatch[1].trim();
        }

        var tweetTime = timeEl ? (timeEl.getAttribute("datetime") || normalizeText(timeEl.textContent)) : "";

        // Engagement stats from aria-labels
        var engagement = [];
        ["reply", "retweet", "like"].forEach(function(action) {
          var btn = tweetEl.querySelector('[data-testid="' + action + '"]');
          if (btn) {
            var ariaLabel = btn.getAttribute("aria-label") || "";
            var countMatch = ariaLabel.match(/^(\d[\d,]*)/);
            if (countMatch && parseInt(countMatch[1].replace(/,/g, ""), 10) > 0) {
              var label = action === "reply" ? "replies" : action === "retweet" ? "reposts" : "likes";
              engagement.push(countMatch[1] + " " + label);
            }
          }
        });

        // Check if it's a retweet (author differs from profile owner)
        var isRetweet = tweetAuthor && displayName && tweetAuthor !== displayName;

        var tweetEntry = "";
        if (pinned) tweetEntry += "[Pinned] ";
        if (isRetweet) tweetEntry += "RT @" + tweetAuthor + ": ";
        tweetEntry += tweetText;
        if (tweetTime) tweetEntry += " (" + tweetTime + ")";
        if (engagement.length) tweetEntry += " [" + engagement.join(", ") + "]";

        tweets.push(tweetEntry);
      }

      // --- Build profile details ---
      var details = [];
      if (handle) details.push("Handle: " + handle);
      if (followers) details.push("Followers: " + formatCount(followers));
      if (following) details.push("Following: " + formatCount(following));
      if (tweetCount) details.push("Posts: " + formatCount(tweetCount));
      if (userLocation) details.push("Location: " + userLocation);
      if (userUrl) details.push("Website: " + userUrl);
      if (birthDate) details.push(birthDate);
      if (joinDate) details.push(joinDate);
      if (profileImage) details.push("Image: " + profileImage);

      // Build description: bio + tweets
      var descParts = [];
      if (bio) descParts.push(bio);
      if (tweets.length) {
        descParts.push("## Recent Posts\n\n" + tweets.join("\n\n"));
      }

      var title = displayName || metadata.title || "X Profile";
      if (!displayName && handle) title = handle;

      return articleContentFromParts({
        title: title,
        description: descParts.join("\n\n"),
        details: details,
        siteName: "X",
        hostAware: true,
        contentType: "article"
      });
    }

    // --- Status/tweet page extraction ---
    var focalTweet = document.querySelector('[data-testid="tweet"]');
    if (!focalTweet) {
      // Fallback to OG metadata for tweet content
      var ogTitle = metadata.title || "";
      var tweetMatch = ogTitle.match(/^(.+?)\s+on X:\s+"(.+?)"\s*\/\s*X$/);
      if (tweetMatch) {
        return articleContentFromParts({
          title: tweetMatch[1],
          description: tweetMatch[2],
          siteName: "X",
          hostAware: true
        });
      }
      return null;
    }

    var focalText = "";
    var focalTextEl = focalTweet.querySelector('[data-testid="tweetText"]');
    if (focalTextEl) focalText = normalizeText(focalTextEl.textContent);

    // Focal tweet author
    var focalAuthorEl = focalTweet.querySelector('[data-testid="User-Name"]');
    var focalAuthor = "";
    var focalHandle = "";
    if (focalAuthorEl) {
      var faParts = normalizeText(focalAuthorEl.textContent);
      var faMatch = faParts.match(/^(.+?)\s*(@\w+)/);
      if (faMatch) {
        focalAuthor = faMatch[1].trim();
        focalHandle = faMatch[2];
      }
    }

    // Focal tweet time
    var focalTimeEl = focalTweet.querySelector("time");
    var focalTime = focalTimeEl ? (focalTimeEl.getAttribute("datetime") || normalizeText(focalTimeEl.textContent)) : "";

    // Focal tweet engagement
    var focalEngagement = [];
    ["reply", "retweet", "like", "bookmark"].forEach(function(action) {
      var btn = focalTweet.querySelector('[data-testid="' + action + '"]');
      if (btn) {
        var ariaLabel = btn.getAttribute("aria-label") || "";
        var countMatch = ariaLabel.match(/^(\d[\d,]*)/);
        if (countMatch && parseInt(countMatch[1].replace(/,/g, ""), 10) > 0) {
          var label = action === "reply" ? "replies" : action === "retweet" ? "reposts" : action === "like" ? "likes" : "bookmarks";
          focalEngagement.push(countMatch[1] + " " + label);
        }
      }
    });

    var statusDetails = [];
    if (focalHandle) statusDetails.push("Author: " + focalAuthor + " (" + focalHandle + ")");
    if (focalTime) statusDetails.push("Posted: " + focalTime);
    if (focalEngagement.length) statusDetails.push("Engagement: " + focalEngagement.join(", "));

    // Collect replies
    var allTweets = document.querySelectorAll('[data-testid="tweet"]');
    var replies = [];
    for (var ri = 1; ri < Math.min(allTweets.length, 8); ri++) {
      var replyEl = allTweets[ri];
      var replyTextEl = replyEl.querySelector('[data-testid="tweetText"]');
      if (!replyTextEl) continue;

      var replyText = normalizeText(replyTextEl.textContent);
      if (!replyText || replyText.length < 3) continue;

      var replyAuthorEl = replyEl.querySelector('[data-testid="User-Name"]');
      var replyAuthor = "";
      if (replyAuthorEl) {
        var raMatch = normalizeText(replyAuthorEl.textContent).match(/^(.+?)\s*(@\w+)/);
        if (raMatch) replyAuthor = raMatch[2];
      }

      replies.push((replyAuthor ? replyAuthor + ": " : "") + replyText);
    }

    var statusDesc = focalText;
    if (replies.length) {
      statusDesc += "\n\n## Replies\n\n" + replies.join("\n\n");
    }

    return articleContentFromParts({
      title: focalAuthor || metadata.title || "Post on X",
      description: statusDesc,
      details: statusDetails,
      siteName: "X",
      hostAware: true,
      contentType: "article"
    });
  }

  function threadsContent(metadata, pageText) {
    if (!hostMatches(/(^|\.)threads\.(net|com)$/)) return null;

    // Threads is an SPA with zero DOM content — all <script> tags.
    // Only OG metadata is available (same server-side gating as Instagram).

    var ogTitle = metadata.title || "";
    var ogDesc = metadata.excerpt || "";
    var ogImage = metadata.image || "";

    // Parse profile: "Mark Zuckerberg (@zuck) • Threads, Say more"
    var profileMatch = ogTitle.match(/^(.+?)\s*\((@\w+)\)\s*[•·]/);
    var displayName = profileMatch ? profileMatch[1].trim() : "";
    var handle = profileMatch ? profileMatch[2] : "";

    // Parse single post: "Mark Zuckerberg (@zuck) on Threads" or "@zuck on Threads"
    if (!profileMatch) {
      var postMatch = ogTitle.match(/^(.+?)\s*\((@\w+)\)\s+on Threads/);
      if (!postMatch) postMatch = ogTitle.match(/^(@\w+)\s+on Threads/);
      if (postMatch) {
        displayName = postMatch[1] ? postMatch[1].trim() : "";
        handle = postMatch[2] || postMatch[1] || "";
      }
    }

    // Parse stats from og:description: "5.5M Followers • 142 Threads • Bio text here"
    var followers = "";
    var threadCount = "";
    var bio = ogDesc;

    var statsMatch = ogDesc.match(/^([\d,.]+[KMB]?)\s+Followers?\s*[•·]\s*([\d,.]+[KMB]?)\s+Threads?\s*[•·]\s*(.*)/i);
    if (statsMatch) {
      followers = statsMatch[1];
      threadCount = statsMatch[2];
      bio = normalizeText(statsMatch[3]);
    } else {
      var followerMatch = ogDesc.match(/([\d,.]+[KMB]?)\s+Followers?/i);
      if (followerMatch) followers = followerMatch[1];
      var threadMatch = ogDesc.match(/([\d,.]+[KMB]?)\s+Threads?/i);
      if (threadMatch) threadCount = threadMatch[1];
    }

    if (!displayName && !handle) {
      // Not a recognizable Threads page
      return null;
    }

    var details = [];
    if (handle) details.push("Handle: " + handle);
    if (followers) details.push("Followers: " + followers);
    if (threadCount) details.push("Threads: " + threadCount);
    if (ogImage) details.push("Image: " + ogImage);

    var title = displayName || handle;

    return articleContentFromParts({
      title: title,
      description: bio || ogDesc,
      details: details,
      siteName: "Threads",
      hostAware: true,
      contentType: "article"
    });
  }

  function linkedinContent(metadata, pageText) {
    if (!hostMatches(/(^|\.)linkedin\.com$/)) return null;

    var pt = (document.body && document.body.innerText) || pageText || "";
    var isCompanyPage = /^\/company\//.test(location.pathname);
    var isPersonalProfile = /^\/in\//.test(location.pathname);

    if (!isCompanyPage && !isPersonalProfile) return null;

    // --- Company page extraction ---
    if (isCompanyPage) {
      var companyName = "";
      var industry = "";
      var companyLocation = "";
      var followerCount = "";
      var aboutText = "";
      var website = "";
      var companySize = "";
      var headquarters = "";
      var companyType = "";
      var specialties = "";
      var founded = "";

      // Extract from page text sections
      // LinkedIn company pages structure: Company Name\nIndustry\nLocation\nFollowers

      // Try OG metadata first for name
      companyName = (metadata.title || "").replace(/\s*[|\-–—]\s*LinkedIn.*$/i, "").trim();

      // Parse follower count from page text
      var followerMatch = pt.match(/([\d,.]+[KMB]?)\s+followers/i);
      if (followerMatch) followerCount = followerMatch[1];

      // Extract About section
      var aboutMatch = pt.match(/\bAbout\s*\n([\s\S]*?)(?=\n(?:Website|Locations|Employees|Affiliated|Updates|Posts|Similar|Home|Products|Jobs|People|Insights)\b)/i);
      if (aboutMatch) aboutText = normalizeText(aboutMatch[1]);

      // Extract structured details
      var websiteMatch = pt.match(/Website\s*\n\s*(https?:\/\/\S+|[\w.-]+\.[\w]{2,}(?:\/\S*)?)/i);
      if (websiteMatch) website = websiteMatch[1].trim();

      var industryMatch = pt.match(/Industry\s*\n\s*(.+)/i);
      if (industryMatch) industry = normalizeText(industryMatch[1]);
      if (!industry) {
        // Industry often appears right after the company name in the header
        var headerMatch = pt.match(new RegExp(companyName.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + "\\s*\\n\\s*(.+?)\\s*\\n", "i"));
        if (headerMatch) industry = normalizeText(headerMatch[1]);
      }

      var sizeMatch = pt.match(/Company size\s*\n\s*(.+)/i);
      if (sizeMatch) companySize = normalizeText(sizeMatch[1]);

      var hqMatch = pt.match(/Headquarters\s*\n\s*(.+)/i);
      if (hqMatch) headquarters = normalizeText(hqMatch[1]);

      var typeMatch = pt.match(/Type\s*\n\s*(.+)/i);
      if (typeMatch) companyType = normalizeText(typeMatch[1]);

      var specialtiesMatch = pt.match(/Specialties\s*\n\s*([\s\S]*?)(?=\n\n|\n(?:Website|Locations|Employees|Home|Products|Jobs|People|Insights)\b)/i);
      if (specialtiesMatch) specialties = normalizeText(specialtiesMatch[1]);

      var foundedMatch = pt.match(/Founded\s*\n\s*(\d{4})/i);
      if (foundedMatch) founded = foundedMatch[1];

      // Location: prefer headquarters field
      if (!companyLocation && headquarters) companyLocation = headquarters;

      // Extract recent posts/updates
      var posts = [];
      var updatesSection = pt.match(/(?:Updates|Posts)\s*\n([\s\S]*?)(?=\n(?:Similar pages|Affiliated|People also viewed|Browse jobs)\b|$)/i);
      if (updatesSection) {
        var postBlocks = updatesSection[1].split(/\n(?=.*?\b(?:likes?|comments?|reactions?)\b)/i);
        for (var pi = 0; pi < Math.min(postBlocks.length, 3); pi++) {
          var postText = normalizeText(postBlocks[pi]);
          if (postText && postText.length > 20 && !/^(?:Show|See|Load)\s/i.test(postText)) {
            posts.push(postText.substring(0, 500));
          }
        }
      }

      // Build details
      var details = [];
      if (industry) details.push("Industry: " + industry);
      if (followerCount) details.push("Followers: " + followerCount);
      if (companyLocation) details.push("Location: " + companyLocation);
      if (website) details.push("Website: " + website);
      if (companySize) details.push("Size: " + companySize);
      if (companyType) details.push("Type: " + companyType);
      if (founded) details.push("Founded: " + founded);
      if (headquarters && headquarters !== companyLocation) details.push("Headquarters: " + headquarters);
      if (specialties) details.push("Specialties: " + specialties);
      if (metadata.image) details.push("Image: " + metadata.image);

      var descParts = [];
      if (aboutText) descParts.push(aboutText);
      if (posts.length) descParts.push("## Recent Updates\n\n" + posts.join("\n\n"));

      return articleContentFromParts({
        title: companyName || "LinkedIn Company",
        description: descParts.join("\n\n") || metadata.excerpt || "",
        details: details,
        siteName: "LinkedIn",
        hostAware: true,
        contentType: "article"
      });
    }

    // --- Personal profile extraction ---
    var personName = (metadata.title || "").replace(/\s*[|\-–—]\s*LinkedIn.*$/i, "").trim();
    var personTitle = "";
    var personLocation = "";
    var personFollowers = "";
    var personConnections = "";
    var personAbout = "";

    // Parse title/headline — usually right after name
    var namePattern = personName ? new RegExp(personName.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + "\\s*\\n\\s*(.+?)\\s*\\n", "i") : null;
    if (namePattern) {
      var titleMatch = pt.match(namePattern);
      if (titleMatch) personTitle = normalizeText(titleMatch[1]);
    }

    // Follower count
    var pFollowerMatch = pt.match(/([\d,.]+[KMB]?)\s+followers/i);
    if (pFollowerMatch) personFollowers = pFollowerMatch[1];

    // Connections
    var connMatch = pt.match(/([\d,.]+\+?)\s+connections?/i);
    if (connMatch) personConnections = connMatch[1];

    // Location — from OG metadata title suffix (e.g., "Satya Nadella - Chairman and CEO at Microsoft")
    // or explicitly labeled in page text
    var locationLabel = pt.match(/Location\s*\n\s*([A-Z][\w\s,.-]+)/i);
    if (locationLabel) personLocation = normalizeText(locationLabel[1]);

    // About section
    var aboutMatch = pt.match(/\bAbout\s*\n([\s\S]*?)(?=\n(?:Experience|Education|Skills|Activity|Courses|Articles|Interests|Licenses|Certifications|Recommendations)\b)/i);
    if (aboutMatch) personAbout = normalizeText(aboutMatch[1]);
    // Clean "… see more" from about
    personAbout = personAbout.replace(/\s*\.{3}\s*see more\s*$/i, "").replace(/\s*…\s*see more\s*$/i, "");

    // Extract activity/articles
    var articles = [];
    var activityMatch = pt.match(/(?:Activity|Articles)\s*\n([\s\S]*?)(?=\n(?:Experience|Education|Skills|Interests|Courses|Licenses|Certifications|Recommendations)\b|$)/i);
    if (activityMatch) {
      var actText = activityMatch[1];
      var artMatches = actText.match(/.{20,}(?:\d+\s*(?:likes?|comments?|reactions?|views?))/gi);
      if (artMatches) {
        for (var ai = 0; ai < Math.min(artMatches.length, 3); ai++) {
          articles.push(normalizeText(artMatches[ai]));
        }
      }
    }

    // Build details
    var pDetails = [];
    if (personTitle) pDetails.push("Title: " + personTitle);
    if (personFollowers) pDetails.push("Followers: " + personFollowers);
    if (personConnections) pDetails.push("Connections: " + personConnections);
    if (personLocation) pDetails.push("Location: " + personLocation);
    if (metadata.image) pDetails.push("Image: " + metadata.image);

    var pDescParts = [];
    if (personAbout) pDescParts.push(personAbout);
    if (articles.length) pDescParts.push("## Recent Activity\n\n" + articles.join("\n\n"));

    return articleContentFromParts({
      title: personName || "LinkedIn Profile",
      description: pDescParts.join("\n\n") || metadata.excerpt || "",
      details: pDetails,
      siteName: "LinkedIn",
      hostAware: true,
      contentType: "article"
    });
  }

  function blueskyContent(metadata, pageText) {
    if (!hostMatches(/(^|\.)bsky\.(app|social)$/)) return null;

    var isProfilePage = !!document.querySelector('[data-testid="profileScreen"], [data-testid="profileView"]');
    var isPostPage = /^\/profile\/[^/]+\/post\//.test(location.pathname);

    if (!isProfilePage && !isPostPage) return null;

    // --- Profile page extraction ---
    if (isProfilePage) {
      var nameEl = document.querySelector('[data-testid="profileHeaderDisplayName"]');
      var descEl = document.querySelector('[data-testid="profileHeaderDescription"]');
      var followersEl = document.querySelector('[data-testid="profileHeaderFollowersButton"]');
      var followingEl = document.querySelector('[data-testid="profileHeaderFollowsButton"]');

      var displayName = nameEl ? normalizeText(nameEl.textContent) : "";
      var bio = descEl ? normalizeText(descEl.textContent) : "";

      // Handle from URL path
      var handle = "";
      var pathParts = (location.pathname || "").split("/").filter(Boolean);
      if (pathParts[0] === "profile" && pathParts[1]) {
        handle = "@" + pathParts[1];
      }

      // Followers/following from aria-labels (exact counts)
      var followers = "";
      var following = "";
      if (followersEl) {
        var fAria = followersEl.getAttribute("aria-label") || "";
        var fMatch = fAria.match(/^([\d,]+)\s+followers/i);
        if (fMatch) {
          followers = fMatch[1];
        } else {
          followers = normalizeText(followersEl.textContent).replace(/\s*followers?$/i, "").trim();
        }
      }
      if (followingEl) {
        var fgAria = followingEl.getAttribute("aria-label") || "";
        var fgMatch = fgAria.match(/^([\d,]+)\s+following/i);
        if (fgMatch) {
          following = fgMatch[1];
        } else {
          following = normalizeText(followingEl.textContent).replace(/\s*following$/i, "").trim();
        }
      }

      // Post count from page text (e.g., "4K posts")
      var postCount = "";
      var pt = (document.body && document.body.innerText) || pageText || "";
      var postCountMatch = pt.match(/([\d,.]+[KMB]?)\s+posts?\b/i);
      if (postCountMatch) postCount = postCountMatch[1];

      // Format large follower counts for readability
      function formatBskyCount(n) {
        var num = parseInt(String(n).replace(/,/g, ""), 10);
        if (isNaN(num)) return n;
        if (num >= 1000000) return (num / 1000000).toFixed(1).replace(/\.0$/, "") + "M";
        if (num >= 10000) return (num / 1000).toFixed(1).replace(/\.0$/, "") + "K";
        return num.toLocaleString();
      }

      // Profile image
      var profileImage = metadata.image || "";
      if (!profileImage) {
        var avatarImg = document.querySelector('[data-testid="userAvatarImage"]');
        if (avatarImg) profileImage = avatarImg.src || "";
      }

      // Extract posts from feed
      var posts = [];
      var postTextEls = document.querySelectorAll('[data-testid="postText"]');
      for (var pi = 0; pi < Math.min(postTextEls.length, 5); pi++) {
        var postEl = postTextEls[pi];
        var postText = normalizeText(postEl.textContent);
        if (!postText || postText.length < 5) continue;

        // Walk up to find the feed item container for engagement data
        var feedItem = postEl.closest('[data-testid^="feedItem-by-"]');
        var engagement = [];
        if (feedItem) {
          var replyBtn = feedItem.querySelector('[data-testid="replyBtn"]');
          var repostCount = feedItem.querySelector('[data-testid="repostCount"]');
          var likeCount = feedItem.querySelector('[data-testid="likeCount"]');

          if (replyBtn) {
            var replyAria = replyBtn.getAttribute("aria-label") || "";
            var replyMatch = replyAria.match(/\((\d[\d,]*)\s+repl/i);
            if (replyMatch) engagement.push(replyMatch[1] + " replies");
          }
          if (repostCount) {
            var rpText = normalizeText(repostCount.textContent);
            if (rpText && rpText !== "0") engagement.push(rpText + " reposts");
          }
          if (likeCount) {
            var lkText = normalizeText(likeCount.textContent);
            if (lkText && lkText !== "0") engagement.push(lkText + " likes");
          }

          // Check if repost
          var repostIndicator = feedItem.querySelector('[data-testid^="feedItem-by-"]');
          var feedTestId = feedItem.getAttribute("data-testid") || "";
          var feedAuthor = feedTestId.replace("feedItem-by-", "");
          var handleClean = handle.replace("@", "");
          var isRepost = feedAuthor && handleClean && feedAuthor !== handleClean;
        }

        var entry = "";
        if (isRepost) entry += "Repost @" + feedAuthor + ": ";
        entry += postText;
        if (engagement.length) entry += " [" + engagement.join(", ") + "]";
        posts.push(entry);
      }

      // Build details
      var details = [];
      if (handle) details.push("Handle: " + handle);
      if (followers) details.push("Followers: " + formatBskyCount(followers));
      if (following) details.push("Following: " + formatBskyCount(following));
      if (postCount) details.push("Posts: " + postCount);
      if (profileImage) details.push("Image: " + profileImage);

      var descParts = [];
      if (bio) descParts.push(bio);
      if (posts.length) descParts.push("## Recent Posts\n\n" + posts.join("\n\n"));

      return articleContentFromParts({
        title: displayName || handle || "Bluesky Profile",
        description: descParts.join("\n\n"),
        details: details,
        siteName: "Bluesky",
        hostAware: true,
        contentType: "article"
      });
    }

    // --- Single post page extraction ---
    var focalPost = document.querySelector('[data-testid="postText"]');
    if (!focalPost) return null;

    var focalText = normalizeText(focalPost.textContent);
    var focalAuthor = "";
    var focalHandle = "";

    // Author from URL path: /profile/{handle}/post/{id}
    var postPathParts = (location.pathname || "").split("/").filter(Boolean);
    if (postPathParts[0] === "profile" && postPathParts[1]) {
      focalHandle = "@" + postPathParts[1];
    }

    // Display name from page
    var postNameEl = document.querySelector('[data-testid="profileHeaderDisplayName"]');
    if (postNameEl) focalAuthor = normalizeText(postNameEl.textContent);
    if (!focalAuthor) focalAuthor = (metadata.title || "").replace(/\s*[-–—|].*$/, "").trim();

    // Engagement from the focal post's feed item
    var focalFeedItem = focalPost.closest('[data-testid^="feedItem-by-"]') || document.querySelector('[data-testid^="feedItem-by-"]');
    var focalEngagement = [];
    if (focalFeedItem) {
      var fReply = focalFeedItem.querySelector('[data-testid="replyBtn"]');
      var fRepost = focalFeedItem.querySelector('[data-testid="repostCount"]');
      var fLike = focalFeedItem.querySelector('[data-testid="likeCount"]');
      if (fReply) {
        var frAria = fReply.getAttribute("aria-label") || "";
        var frMatch = frAria.match(/\((\d[\d,]*)\s+repl/i);
        if (frMatch) focalEngagement.push(frMatch[1] + " replies");
      }
      if (fRepost) {
        var frpText = normalizeText(fRepost.textContent);
        if (frpText && frpText !== "0") focalEngagement.push(frpText + " reposts");
      }
      if (fLike) {
        var flkText = normalizeText(fLike.textContent);
        if (flkText && flkText !== "0") focalEngagement.push(flkText + " likes");
      }
    }

    var postDetails = [];
    if (focalHandle) postDetails.push("Author: " + (focalAuthor ? focalAuthor + " (" + focalHandle + ")" : focalHandle));
    if (focalEngagement.length) postDetails.push("Engagement: " + focalEngagement.join(", "));

    // Collect replies (subsequent postText elements)
    var allPostTexts = document.querySelectorAll('[data-testid="postText"]');
    var replies = [];
    for (var ri = 1; ri < Math.min(allPostTexts.length, 8); ri++) {
      var replyText = normalizeText(allPostTexts[ri].textContent);
      if (replyText && replyText.length > 3) {
        replies.push(replyText);
      }
    }

    var postDesc = focalText;
    if (replies.length) postDesc += "\n\n## Replies\n\n" + replies.join("\n\n");

    return articleContentFromParts({
      title: focalAuthor || "Post on Bluesky",
      description: postDesc,
      details: postDetails,
      siteName: "Bluesky",
      hostAware: true,
      contentType: "article"
    });
  }

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
        if (!text || /^(go to\s+\w+|let us know your cookie preferences)$/i.test(text)) return false;
        body = text;
        return true;
      });
    }
    var commentCount = parseInt(post.getAttribute("comment-count") || "0", 10);
    var commentNodes = Array.prototype.slice.call(document.querySelectorAll("shreddit-comment[depth='0'], shreddit-comment:not([depth])"));
    var comments = [];

    commentNodes.forEach(function(node) {
      if (comments.length >= 8) return;

      var author = normalizeText(node.getAttribute("author") || "");
      var score = normalizeText(node.getAttribute("score") || "");
      var metaText = normalizeText((node.querySelector('[slot="commentMeta"]') || {}).innerText || "");
      var text = normalizeText((node.querySelector('[slot="comment"]') || {}).innerText || "");
      if (!text) return;

      var heading = author || "Comment";
      if (score) heading += " (" + score + " points)";
      comments.push({
        heading: heading,
        meta: metaText,
        text: text
      });
    });

    if (!title || (!body && comments.length === 0)) return null;

    var sections = ["# " + title];
    if (byline) sections.push("- Author: " + byline);
    if (credit && (!byline || credit.toLowerCase().indexOf(byline.toLowerCase()) === -1)) sections.push("- Context: " + credit);
    if (body) sections.push(body);
    if (commentCount || comments.length) sections.push("## Top Comments");

    comments.forEach(function(comment) {
      sections.push("### " + comment.heading);
      if (comment.meta && comment.meta.toLowerCase().indexOf(comment.heading.toLowerCase()) === -1) sections.push(comment.meta);
      sections.push(comment.text);
    });

    return {
      title: title,
      byline: byline || metadata.byline,
      excerpt: body || metadata.excerpt,
      siteName: metadata.siteName || "Reddit",
      publishedTime: metadata.publishedTime,
      html: post.outerHTML,
      markdown: sections.filter(Boolean).join("\n\n"),
      textContent: normalizeText([title, body].concat(comments.map(function(comment) { return comment.text; })).join(" ")),
      readerMode: false,
      contentType: "article"
    };
  }

  function redditContent(metadata, pageText) {
    if (!hostMatches(/(^|\.)reddit\.com$/)) return null;
    var liveThread = redditThreadMarkdown(metadata);
    if (liveThread) return liveThread;
    if (!/(cookie preferences|before you continue to reddit|reddit uses cookies|log in|sign up)/i.test(pageText || "")) return null;

    var parts = (location.pathname || "").split("/").filter(Boolean);
    var subreddit = parts[0] === "r" ? parts[1] : null;
    var title = normalizeText((metadata.title || document.title).replace(/\s*:\s*r\/[^|]+$/i, "")) || metadata.title || "Reddit page";
    var description = metadata.excerpt || "This Reddit page requires cookie acceptance or login before the original content is available.";
    var details = ["Access: Reddit cookie or login wall"];
    if (subreddit) details.push("Requested community: r/" + subreddit);

    return articleContentFromParts({
      title: title,
      description: description,
      details: details,
      siteName: metadata.siteName || "Reddit"
    });
  }

  function behanceContent(metadata, pageText) {
    if (!hostMatches(/(^|\.)behance\.net$/)) return null;

    var items = [];
    var seen = {};

    document.querySelectorAll("a[href*='/gallery/'], a[href*='/project/']").forEach(function(link) {
      if (items.length >= 12) return;

      var href = link.getAttribute("href");
      if (!href) return;

      var url = absoluteUrl(href);
      try {
        var parsed = new URL(url, location.href);
        parsed.searchParams.delete("tracking_source");
        parsed.searchParams.delete("l");
        url = parsed.toString();
      } catch (_error) {
      }

      var title = normalizeText(link.textContent || link.getAttribute("aria-label") || "");
      if (!title) return;

      var key = title + "|" + url;
      if (seen[key]) return;
      seen[key] = true;

      var container = link.closest("article, li, div, section") || link.parentElement;
      items.push({ text: title, url: url, detail: searchItemDetail(container, title) });
    });

    if (items.length >= 4) {
      var query = safeDecodeURI((location.pathname || "").split("/").filter(Boolean).slice(-1)[0] || "").replace(/[-_+]+/g, " ");
      query = normalizeText(query);

      return {
        title: query ? "Behance projects for " + query : (metadata.title || document.title),
        byline: null,
        excerpt: metadata.excerpt,
        siteName: metadata.siteName || "Behance",
        publishedTime: null,
        html: "",
        textContent: listMarkdown(items),
        markdown: listMarkdown(items),
      readerMode: false,
      contentType: "list",
      hostAware: true
    };
  }


    if (!/(cookie settings|measure performance|personalize advertising|adobe and our partners)/i.test(pageText || "")) return null;

    var title = normalizeText((metadata.title || document.title).replace(/\s*::\s*Photos, videos, logos, illustrations and branding$/i, "")) || metadata.title || "Behance page";
    var description = metadata.excerpt || "This Behance page is showing Adobe cookie settings before the original content is available.";
    var details = ["Access: Adobe cookie settings wall"];
    if (/^\/search\//.test(location.pathname)) details.push("Requested view: Behance search results");

    return articleContentFromParts({
      title: title,
      description: description,
      details: details,
      siteName: metadata.siteName || "Behance"
    });
  }

  function quoraContent(metadata, pageText) {
    if (!hostMatches(/(^|\.)quora\.com$/)) return null;
    if (!/(security verification|just a moment|protect against malicious bots)/i.test(pageText || "")) return null;

    var slug = safeDecodeURI((location.pathname || "").split("/").filter(Boolean)[0] || "").replace(/[-_]+/g, " ");
    slug = normalizeText(slug);
    if (!slug || /^just a moment$/i.test(slug)) return null;

    return articleContentFromParts({
      title: slug,
      description: metadata.excerpt,
      siteName: metadata.siteName || "Quora"
    });
  }

  function glassdoorContent(metadata) {
    var signature = normalizeText([location.hostname, metadata && metadata.siteName, metadata && metadata.title, document.title].join(" "));
    if (!hostMatches(/(^|\.)glassdoor\.com$/) && !/glassdoor/i.test(signature)) return null;
    if (location.pathname && location.pathname !== "/" && location.pathname !== "/index.htm") return null;

    var title = firstText(["main h1", "h1"]) || normalizeText((metadata.title || document.title).replace(/\s*\|.*$/, ""));
    var lines = manyTexts(["main h2", "main p"], 20).filter(function(text) {
      return text.length >= 12 && !/^(continue with google|continue with apple|or email|sign in|community jobs companies salaries for employers)$/i.test(text);
    });
    var description = lines.find(function(text) {
      return text !== title && text.length >= 40;
    }) || metadata.excerpt;
    var highlights = lines.filter(function(text) {
      return text !== title && text !== description;
    }).slice(0, 6);

    if (!title && !description) return null;

    return articleContentFromParts({
      title: title,
      description: description,
      highlights: highlights,
      siteName: metadata.siteName || "Glassdoor"
    });
  }

  function wykopContent(metadata) {
    var signature = normalizeText([location.hostname, metadata && metadata.siteName, metadata && metadata.title, document.title].join(" "));
    if (!hostMatches(/(^|\.)wykop\.pl$/) && !/wykop/i.test(signature)) return null;
    if (location.pathname && location.pathname !== "/") return null;

    var seen = {};
    var items = [];

    document.querySelectorAll("section.prerender section.link-block.stream-home[id^='link-'], section.home-page section.link-block.stream-home[id^='link-'], section.stream.home-stream.from-pagination-home-stream section.link-block.stream-home[id^='link-']").forEach(function(card) {
      if (items.length >= 12) return;

      var link = card.querySelector("h2.heading a[href^='/link/'], h2 a[href^='/link/'], a[href^='/link/']");
      if (!link) return;

      var title = normalizeText(link.textContent || link.getAttribute("title") || "");
      var url = absoluteUrl(link.getAttribute("href"));
      if (!title || !url || title.length < 12 || title.length > 220 || seen[url]) return;
      if (/^(załóż konto|zaloguj się|ustawienia prywatności)$/i.test(title)) return;

      seen[url] = true;

      var detailParts = [];
      var summary = normalizeText(Array.prototype.map.call(card.querySelectorAll("p, .description, .text, .content"), function(node) {
        return normalizeText(node.textContent || "");
      }).join(" "));
      if (summary && summary !== title && !/we value your privacy|manage choices|privacy settings|ustawienia prywatności|polityka prywatności i cookies|nie widzisz nawet do 30% treści dostępnych w serwisie/i.test(summary)) detailParts.push(summary);

      var counters = normalizeText(Array.prototype.map.call(card.querySelectorAll("a.comment-counter, [class*='vote'], [class*='comment']"), function(node) {
        return normalizeText(node.textContent || "");
      }).join(" ")).replace(/\s{2,}/g, " ");
      if (counters) detailParts.push(counters);

      items.push({ text: title, url: url, detail: normalizeText(detailParts.join(" - ")).slice(0, 220) });
    });

    if (items.length < 4) return null;

    return {
      title: metadata.title || document.title,
      byline: null,
      excerpt: metadata.excerpt,
      siteName: metadata.siteName || "Wykop",
      publishedTime: null,
      html: "",
      textContent: listMarkdown(items),
      markdown: listMarkdown(items),
      readerMode: false,
      contentType: "list"
    };
  }
