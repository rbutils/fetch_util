  function parseInstagramStats(pt) {
    var followerMatch = pt.match(/([\d,.]+[MKB]?)\s*(?:Followers|follower|Takipçi|подписчик|متابع)/i);
    var followingMatch = pt.match(/([\d,.]+[MKB]?)\s*(?:Following|following)/i);
    var postMatch = pt.match(/([\d,.]+[MKB]?)\s*(?:Posts?|post|Gönderi|публикац|منشور)/i);

    return {
      followers: followerMatch && followerMatch[1],
      following: followingMatch && followingMatch[1],
      posts: postMatch && postMatch[1]
    };
  }

  function instagramContent(metadata, pageText) {
    if (!hostMatches(/(^|\.)instagram\.com$/)) return null;
    // Instagram can show a dismissible login modal over profile content.
    // If the modal was dismissed and real content is available, let normal
    // Readability extraction handle it. Only return a login-required summary
    // when content is not actually available.
    var pt = bodyInnerText(pageText);

    // Try the current pathname first; inspect `?next=` only for real
    // login/checkpoint redirects so summaries can still identify the target
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

    var postIndex = -1;
    for (var idx = 0; idx < pathParts.length - 1; idx += 1) {
      if (/^(p|reel|reels|tv)$/i.test(pathParts[idx])) {
        postIndex = idx;
        break;
      }
    }
    var isPostPath = postIndex >= 0;
    var pathSrc = isPostPath ? pathParts[postIndex] : (pathParts[0] || "");
    var pathArg = isPostPath ? (pathParts[postIndex + 1] || "") : (pathParts[1] || "");
    var postPath = isPostPath ? "/" + pathParts.slice(postIndex, postIndex + 2).join("/") + "/" : "";
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
      var handle = handleMatch ? normalizeText(handleMatch[1]) : (postIndex > 0 ? normalizeText(pathParts[0]) : "");
      var caption = normalizeText(titleCaption || (excerptCaptionMatch && excerptCaptionMatch[1]) || "");
      var visibleComments = (function() {
        var lines = (pt || "").split(/\n+/).map(normalizeText).filter(Boolean);
        if (!lines.length || !caption) return [];

        var captionIndex = -1;
        var captionNeedle = caption.toLowerCase();
        for (var li = 0; li < lines.length; li += 1) {
          var line = lines[li].toLowerCase();
          if (line.indexOf(captionNeedle) >= 0 || captionNeedle.indexOf(line) >= 0) {
            captionIndex = li;
            break;
          }
        }
        if (captionIndex < 0) return [];

        var comments = [];
        for (var i = captionIndex + 1; i < lines.length && comments.length < 8; i += 1) {
          var user = lines[i];
          var age = normalizeText(lines[i + 1] || "");
          if (/^(?:\d[\d.,]*[KMB]?|log in to like or comment\.?|more posts from\b|see more posts\b|meta\b|about\b|blog\b|jobs\b|help\b|api\b|privacy\b|terms\b|locations\b|instagram lite\b|meta ai\b|threads\b)/i.test(user)) break;
          if (!/^[a-z0-9._]{2,32}$/i.test(user) || !/^(?:\d+\s*(?:s|m|h|d|w)|just now|now)$/i.test(age)) continue;

          var textLines = [];
          var j = i + 2;
          for (; j < lines.length; j += 1) {
            var lineText = lines[j];
            var nextLine = normalizeText(lines[j + 1] || "");
            if (/^(?:like|reply|follow|following)$/i.test(lineText)) break;
            if (/^(?:\d[\d.,]*[KMB]?|log in to like or comment\.?|more posts from\b|see more posts\b|meta\b|about\b|blog\b|jobs\b|help\b|api\b|privacy\b|terms\b|locations\b|instagram lite\b|meta ai\b|threads\b)/i.test(lineText)) break;
            if (/^[a-z0-9._]{2,32}$/i.test(lineText) && /^(?:\d+\s*(?:s|m|h|d|w)|just now|now)$/i.test(nextLine)) break;
            textLines.push(lineText);
          }

          var commentText = normalizeText(textLines.join(" "));
          if (commentText) comments.push("@" + user + ": " + commentText);
          i = j;
        }

        return comments;
      })();
      var hasVisiblePost = (function() {
        var article = document.querySelector("article");
        if (article) {
          var articleText = normalizeText(article && article.innerText);
          if (/something went wrong|log in to instagram|sign up to see/i.test(articleText)) return false;
          if (article.querySelector('img, video')) return true;
          if (articleText.length > 40) return true;
        }

        if (visibleComments.length) return true;
        if (!caption) return false;

        var pageTextLower = normalizeText(pt).toLowerCase();
        return pageTextLower.indexOf(caption.toLowerCase()) >= 0 && /\b(?:like|reply)\b/i.test(pageTextLower);
      })();

      var details = [];
      var pathLabel = /^(reel|reels|tv)$/i.test(pathSrc) ? "Reel" : "Post";
      if (handle) details.push("Profile: @" + handle);
      if (postPath) details.push(pathLabel + ": " + postPath);
      if (likesMatch) details.push(normalizeText(likesMatch[1]) + " likes");
      if (commentsMatch) details.push(normalizeText(commentsMatch[1]) + " comments");
      if (metadata.image) details.push("Image: " + metadata.image);
      if (metadata.video) details.push("Video: " + metadata.video);

      if (hasVisiblePost) {
        var content = articleContentFromParts({
          title: authorName ? authorName + " on Instagram" : (rawTitle || "Instagram post"),
          byline: handle ? "@" + handle : (authorName || null),
          publishedTime: publishedMatch ? normalizeText(publishedMatch[1]) : (metadata.publishedTime || null),
          description: caption || "Instagram post",
          details: details,
          siteName: metadata.siteName || "Instagram",
          hostAware: true
        });

        if (visibleComments.length) {
          content.markdown += "\n\n## Comments\n\n" + visibleComments.map(function(comment) {
            return "- " + comment;
          }).join("\n");
          content.textContent = normalizeText(content.markdown);
        }

        return content;
      }

      return articleContentFromParts({
        title: authorName ? authorName + " on Instagram" : (rawTitle || "Instagram post"),
        byline: handle ? "@" + handle : (authorName || null),
        publishedTime: publishedMatch ? normalizeText(publishedMatch[1]) : (metadata.publishedTime || null),
        description: caption || "Original content on this Instagram post is not available without login.",
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
      var parsedStats = parseInstagramStats(pt);
      if (parsedStats.posts) stats.push(parsedStats.posts + " posts");
      if (parsedStats.followers) stats.push(parsedStats.followers + " followers");
      if (parsedStats.following) stats.push(parsedStats.following + " following");

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

    // Fallback: content is not available without login, so summarize OG metadata.
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
      var parsedStats = parseInstagramStats(pt);
      if (parsedStats.followers) stats.push(parsedStats.followers + " followers");
      if (parsedStats.posts) stats.push(parsedStats.posts + " posts");
      if (stats.length) description = (description ? description + " " : "") + stats.join(", ") + ".";
    }

    // Final fallback if we have no description at all
    if (!description && username) {
      description = "Original content on this Instagram page for " + username + " is not available without login.";
    } else if (!description) {
      description = "Original content on this Instagram page is not available without login.";
    }

    var fallbackDetails = ["Access notice: Instagram login required"];
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
    var pt = bodyInnerText(pageText);

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

    // When Facebook serves real page content, the body text includes followers/
    // following counts, an "Intro" section, and post content.
    var hasRealContent = (function() {
      if (pt.length < 200) return false;
      var hasFollowers = /([\d,.]+[MKB]?)\s*followers?/i.test(pt);
      var hasIntro = /\bIntro\b/.test(pt);
      return hasFollowers && hasIntro;
    })();

    if (hasRealContent) {
      var sections = [];

      var categoryMatch = pt.match(/(?:Page|Profile)\s*·\s*([^\n]+)/);
      if (categoryMatch) sections.push("Category: " + normalizeText(categoryMatch[1]));

      var followersMatch = pt.match(/([\d,.]+[MKB]?)\s*followers?/i);
      var followingMatch = pt.match(/([\d,.]+[MKB]?)\s*following/i);
      if (followersMatch) sections.push(followersMatch[1] + " followers");
      if (followingMatch) sections.push(followingMatch[1] + " following");

      var introStart = pt.indexOf("Intro\n");
      var introText = "";
      if (introStart >= 0) {
        var afterIntro = pt.substring(introStart + 6);
        var sectionEnd = afterIntro.search(/\n(?:Photos|Videos|About|Posts|Reels|Events|See all|Page ·|Information about)\b/);
        introText = normalizeText(sectionEnd > 0 ? afterIntro.substring(0, sectionEnd) : afterIntro.substring(0, 500));
      }

      var contactArea = introText || pt.substring(0, Math.min(pt.length, 1500));
      var emailMatch = contactArea.match(/([\w.+-]+@[\w.-]+\.\w{2,})/);
      var websiteMatch = contactArea.match(/\b(https?:\/\/[\w.-]+[\w.]{2,}(?:\/[\w.-]*)*)\s/i);

      var posts = [];
      var postPattern = new RegExp(
        normalizeText(title || "").replace(/[.*+?^${}()|[\]\\]/g, "\\$&") +
        "\\s*\\n\\s*(?:\\d+[hd]|\\d+ (?:hour|day|minute|week|month)s? ago|Yesterday|Just now|\\w+ \\d+(?:,? \\d+)?)\\s*\\n\\s*·?\\s*\\n([\\s\\S]*?)(?=\\n(?:All reactions|Like|Comment|Share|\\d+ comment))",
        "gi"
      );
      var postMatch;
      while ((postMatch = postPattern.exec(pt)) !== null) {
        var postText = normalizeText(postMatch[1]);
        if (postText && postText.length > 10) {
          postText = postText.replace(/…\s*See more\s*$/i, "…");
          posts.push(postText);
        }
      }

      if (posts.length === 0) {
        var dirAutoDivs = document.querySelectorAll("div[dir=auto]");
        for (var i = 0; i < dirAutoDivs.length; i++) {
          var divText = normalizeText(dirAutoDivs[i].innerText || "");
          if (divText.length > 50 && divText.length < 3000 &&
              !/^(log in|sign up|create|cookie|privacy|terms|information about|see more from)/i.test(divText)) {
            divText = divText.replace(/…\s*See more\s*$/i, "…");
            posts.push(divText);
          }
        }
      }

      var seenPosts = {};
      posts = posts.filter(function(p) {
        var key = p.substring(0, 80).toLowerCase();
        if (seenPosts[key]) return false;
        seenPosts[key] = true;
        return true;
      });

      var description = "";
      if (introText) description = introText;

      var contactParts = [];
      if (emailMatch) contactParts.push(emailMatch[1]);
      if (websiteMatch && !/facebook\.com/i.test(websiteMatch[1])) contactParts.push(websiteMatch[1]);
      if (contactParts.length) {
        description += (description ? "\n\n" : "") + "Contact: " + contactParts.join(" | ");
      }

      if (posts.length > 0) {
        description += (description ? "\n\n" : "") + "## Recent Posts\n\n";
        for (var j = 0; j < Math.min(posts.length, 5); j++) {
          description += posts[j] + "\n\n";
        }
        description = description.replace(/\n\n$/, "");
      }

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

    var rawExcerpt = metadata.excerpt || "";
    if (/create an account or log into facebook|connect with friends|facebook helps you connect/i.test(rawExcerpt)) rawExcerpt = "";

    var likesCount = "";
    var talkingAbout = "";
    var bioText = "";

    var likesMatch = rawExcerpt.match(/([\d][\d,.\s]*\d)\s*likes?\b/i);
    var talkingMatch = rawExcerpt.match(/([\d][\d,.\s]*\d)\s*talking about this/i);
    if (likesMatch) likesCount = normalizeText(likesMatch[1]) + " likes";
    if (talkingMatch) talkingAbout = normalizeText(talkingMatch[1]) + " talking about this";

    if (talkingMatch) {
      var afterTalking = rawExcerpt.substring(rawExcerpt.indexOf(talkingMatch[0]) + talkingMatch[0].length);
      afterTalking = afterTalking.replace(/^[\s.·]+/, "");
      if (afterTalking && !/^(see |view |log in)/i.test(afterTalking)) bioText = normalizeText(afterTalking);
    } else if (likesMatch) {
      var afterLikes = rawExcerpt.substring(rawExcerpt.indexOf(likesMatch[0]) + likesMatch[0].length);
      afterLikes = afterLikes.replace(/^[\s.·]+/, "");
      if (afterLikes && !/^(see |view |log in)/i.test(afterLikes)) bioText = normalizeText(afterLikes);
    } else if (rawExcerpt) {
      bioText = rawExcerpt;
    }

    var fallbackDescription = "";
    if (bioText) fallbackDescription = bioText;
    var statsLine = [likesCount, talkingAbout].filter(Boolean).join(" · ");
    if (statsLine) fallbackDescription = (fallbackDescription ? fallbackDescription + "\n\n" : "") + statsLine + ".";

    if (!likesCount) {
      var ptLikesMatch = pt.match(/([\d][\d,.\s]*\d)\s*(?:likes?|people like this)/i);
      if (ptLikesMatch) {
        var ptStats = normalizeText(ptLikesMatch[1]) + " likes";
        fallbackDescription = (fallbackDescription ? fallbackDescription + " " : "") + ptStats + ".";
      }
    }

    if (!fallbackDescription && pageName) {
      fallbackDescription = "Original content on this Facebook page for " + pageName + " is not available without login.";
    } else if (!fallbackDescription) {
      fallbackDescription = "Original content on this Facebook page is not available without login.";
    }

    var fallbackDetails = ["Access notice: Facebook login required"];
    if (metadata.image) fallbackDetails.push("Image: " + metadata.image);

    return articleContentFromParts({
      title: title || ("Facebook" + (pageName ? " - " + pageName : "")),
      description: fallbackDescription,
      details: fallbackDetails,
      siteName: metadata.siteName || "Facebook",
      hostAware: true
    });
  }

  function threadsContent(metadata, pageText) {
    if (!hostMatches(/(^|\.)threads\.(net|com)$/)) return null;

    // Threads is an SPA with zero DOM content — all <script> tags.
    // Only OG metadata is available (same server-side gating as Instagram).

    var ogTitle = metadata.title || "";
    var ogDesc = metadata.excerpt || "";
    var ogImage = metadata.image || "";

    var profileMatch = ogTitle.match(/^(.+?)\s*\((@\w+)\)\s*[•·]/);
    var displayName = profileMatch ? profileMatch[1].trim() : "";
    var handle = profileMatch ? profileMatch[2] : "";

    if (!profileMatch) {
      var postMatch = ogTitle.match(/^(.+?)\s*\((@\w+)\)\s+on Threads/);
      if (!postMatch) postMatch = ogTitle.match(/^(@\w+)\s+on Threads/);
      if (postMatch) {
        displayName = postMatch[1] ? postMatch[1].trim() : "";
        handle = postMatch[2] || postMatch[1] || "";
      }
    }

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
