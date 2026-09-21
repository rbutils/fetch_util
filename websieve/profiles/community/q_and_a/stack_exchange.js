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
    var answerNodes = document.querySelectorAll(".answer, .js-answer, [data-answerid]");
    var answers = collectCommunityThreadEntries(answerNodes, function(node) {
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
        id: node.getAttribute("data-answerid") || node.id,
        score: isNaN(score) ? 0 : score,
        author: author,
        body: answerBody,
        accepted: accepted
      };
    });

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
      html: communityThreadNodesHtml([question].concat(answers.map(function(answer) { return answer.sourceNode; }))),
      markdown: markdown,
      textContent: normalizeText(markdown),
      readerMode: false,
      contentType: "social",
      socialKind: "thread",
      platform: stackExchangePlatform(),
      handle: byline || null,
      replyCount: stackExchangeReplyCount(question),
      community: stackExchangeCommunity(metadata),
      score: stackExchangeVoteCount(question)
    };
  }

  function stackExchangePlatform() {
    return /(^|\.)stackoverflow\.com$/.test(location.hostname) ? "Stack Overflow" : "Stack Exchange";
  }

  function stackExchangeReplyCount(question) {
    var count = question.querySelector(".js-answer-count, [data-answercount]");
    var value = normalizeText(question.getAttribute("data-answercount") || (count && (count.getAttribute("data-answercount") || count.textContent)) || "");
    var match = value.match(/^(\d[\d,]*)\s*(?:answers?)?$/i);
    return match ? Number(match[1].replace(/,/g, "")) : null;
  }

  function stackExchangeVoteCount(question) {
    var vote = question.querySelector(".js-vote-count, .vote-count-post, [itemprop='upvoteCount']");
    var value = normalizeText((vote && (vote.getAttribute("data-value") || vote.getAttribute("content") || vote.textContent)) || "");
    return /^-?\d[\d,]*$/.test(value) ? Number(value.replace(/,/g, "")) : null;
  }

  function stackExchangeCommunity(metadata) {
    var title = normalizeText(metadata.title || document.title || "");
    var match = title.match(/[-|]\s*(.+?(?:Stack Exchange|Stack Overflow|Super User|Server Fault|Ask Ubuntu|MathOverflow))\s*$/i);
    return match ? normalizeText(match[1]) : null;
  }

  function registerStackExchangeProfiles() {
    registerHostAwareProfile(true, stackExchangeContent);
  }
