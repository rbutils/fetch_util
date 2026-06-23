  function twitterContent(metadata, pageText) {
    if (!hostMatches(/(^|\.)(twitter\.com|x\.com)$/)) return null;

    var isStatusPage = /^\/[^/]+\/status\/\d+/.test(location.pathname);

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

    if (!isStatusPage) {
      var nameEl = document.querySelector('[data-testid="UserName"]');
      var descEl = document.querySelector('[data-testid="UserDescription"]');
      var urlEl = document.querySelector('[data-testid="UserUrl"]');
      var joinEl = document.querySelector('[data-testid="UserJoinDate"]');
      var locEl = document.querySelector('[data-testid="UserLocation"]');
      var birthEl = document.querySelector('[data-testid="UserBirthdate"]');

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

      if (!followers) {
        var followerLink = document.querySelector('a[href$="/verified_followers"], a[href$="/followers"]');
        if (followerLink) followers = normalizeText(followerLink.textContent).replace(/\s*followers?$/i, "");
      }
      if (!following) {
        var followingLink = document.querySelector('a[href$="/following"]');
        if (followingLink) following = normalizeText(followingLink.textContent).replace(/\s*following$/i, "");
      }

      var profileImage = "";
      if (ldProfile && ldProfile.image && ldProfile.image.contentUrl) {
        profileImage = ldProfile.image.contentUrl;
      }
      if (!profileImage) {
        var avatarImg = document.querySelector('[data-testid^="UserAvatar"] img[src*="profile_images"]');
        if (avatarImg) profileImage = avatarImg.src;
      }

      if (!userUrl && ldProfile && ldProfile.relatedLink) {
        var links = Array.isArray(ldProfile.relatedLink) ? ldProfile.relatedLink : [ldProfile.relatedLink];
        var realLinks = links.filter(function(l) { return !/t\.co\//.test(l); });
        userUrl = (realLinks[0] || links[0] || "").replace(/^https?:\/\//, "");
      }

      var tweets = [];
      var tweetEls = document.querySelectorAll('[data-testid="tweet"]');
      for (var ti = 0; ti < Math.min(tweetEls.length, 5); ti++) {
        var tweetEl = tweetEls[ti];
        var textEl = tweetEl.querySelector('[data-testid="tweetText"]');
        if (!textEl) continue;

        var tweetText = normalizeText(textEl.textContent);
        if (!tweetText || tweetText.length < 5) continue;

        var authorEl = tweetEl.querySelector('[data-testid="User-Name"]');
        var timeEl = tweetEl.querySelector("time");
        var pinned = tweetEl.querySelector('[data-testid="socialContext"]');

        var tweetAuthor = "";
        if (authorEl) {
          var authorText = normalizeText(authorEl.textContent);
          var authorMatch = authorText.match(/^(.+?)(\s*@\w+)/);
          if (authorMatch) tweetAuthor = authorMatch[1].trim();
        }

        var tweetTime = timeEl ? (timeEl.getAttribute("datetime") || normalizeText(timeEl.textContent)) : "";

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

        var isRetweet = tweetAuthor && displayName && tweetAuthor !== displayName;

        var tweetEntry = "";
        if (pinned) tweetEntry += "[Pinned] ";
        if (isRetweet) tweetEntry += "RT @" + tweetAuthor + ": ";
        tweetEntry += tweetText;
        if (tweetTime) tweetEntry += " (" + tweetTime + ")";
        if (engagement.length) tweetEntry += " [" + engagement.join(", ") + "]";

        tweets.push(tweetEntry);
      }

      var details = [];
      if (handle) details.push("Handle: " + handle);
      if (followers) details.push("Followers: " + socialCompactCount(followers));
      if (following) details.push("Following: " + socialCompactCount(following));
      if (tweetCount) details.push("Posts: " + socialCompactCount(tweetCount));
      if (userLocation) details.push("Location: " + userLocation);
      if (userUrl) details.push("Website: " + userUrl);
      if (birthDate) details.push(birthDate);
      if (joinDate) details.push(joinDate);
      if (profileImage) details.push("Image: " + profileImage);

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

    var focalTweet = document.querySelector('[data-testid="tweet"]');
    if (!focalTweet) {
      var ogTitle = metadata.title || "";
      var tweetMatch = ogTitle.match(/^(.+?)\s+on X:\s*"(.+?)"\s*\/\s*X$/);
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

    var focalTimeEl = focalTweet.querySelector("time");
    var focalTime = focalTimeEl ? (focalTimeEl.getAttribute("datetime") || normalizeText(focalTimeEl.textContent)) : "";

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
