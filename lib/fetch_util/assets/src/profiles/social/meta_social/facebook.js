  function facebookContent(metadata, pageText) {
    if (!hostMatches(/(^|\.)facebook\.com$/)) return null;
    var pt = bodyInnerText(pageText);

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
    if (/^(login|watch|marketplace|groups|gaming|events|pages|profile\.php|photo|story|reel|permalink|hashtag)$/i.test(pathSrc)) pathSrc = "";
    var pageName = safeDecodeURI(pathSrc).replace(/[-_.]+/g, " ");
    pageName = normalizeText(pageName);

    var title = normalizeText((metadata.title || "").replace(/\s*[-–—|]\s*(Facebook|Log in or sign up).*$/i, "").replace(/\s*\|\s*Facebook\s*$/i, "")) || metadata.title;
    if (/^(facebook\s*[-–—]?\s*log in|log in to facebook|log in or sign up)/i.test(title || "")) {
      title = pageName || "Facebook";
    }

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
        escapeRegex(normalizeText(title || "")) +
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

  function registerFacebookProfiles() {
    registerHostAwareProfile(true, facebookContent);
  }
