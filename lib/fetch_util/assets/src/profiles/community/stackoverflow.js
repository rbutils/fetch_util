  function stackOverflowContent(metadata) {
    if (!hostMatches(/(^|\.)stackoverflow\.com$/)) return null;
    if (!/^\/questions\/\d+(?:\/|$)/.test(location.pathname || "")) return null;

    var question = document.querySelector("#question, .question[data-questionid], .question");
    if (!question) return null;

    var questionBody = question.querySelector(".js-post-body, .s-prose[itemprop='text'], [itemprop='text']");
    var title = normalizeText(firstText(["#question-header h1 a", "#question-header h1", "h1[itemprop='name']", "main h1", "h1"]) || metadata.title || document.title);
    title = title.replace(/\s*-\s*Stack Overflow\s*$/i, "");

    var questionMarkdown = stackOverflowPostMarkdown(questionBody);
    if (!title || !questionMarkdown) return null;

    var answerNodes = Array.prototype.slice.call(document.querySelectorAll("#answers .answer, .answer[data-answerid]"));
    var answers = [];
    answerNodes.forEach(function(answer) {
      if (answers.length >= 6) return;

      var body = answer.querySelector(".js-post-body, .s-prose[itemprop='text'], [itemprop='text']");
      var markdown = stackOverflowPostMarkdown(body);
      if (!markdown) return;

      var votes = stackOverflowVoteCount(answer);
      var accepted = !!answer.querySelector(".js-accepted-answer-indicator, .fc-green-500, [title*='accepted']");
      var heading = accepted ? "Accepted answer" : "Answer";
      if (votes) heading += " (" + votes + " votes)";

      answers.push({ heading: heading, markdown: markdown });
    });

    var sections = ["# " + title, "## Question", questionMarkdown];
    if (answers.length > 0) sections.push("## Answers");
    answers.forEach(function(answer) {
      sections.push("### " + answer.heading);
      sections.push(answer.markdown);
    });

    return {
      title: title,
      byline: metadata.byline,
      excerpt: normalizeText((questionBody && questionBody.textContent) || metadata.excerpt || ""),
      siteName: metadata.siteName || "Stack Overflow",
      publishedTime: metadata.publishedTime,
      html: [question.outerHTML].concat(answerNodes.slice(0, 6).map(function(answer) { return answer.outerHTML; })).join("\n"),
      markdown: sections.filter(Boolean).join("\n\n"),
      textContent: normalizeText([title, questionMarkdown].concat(answers.map(function(answer) { return answer.markdown; })).join(" ")),
      hostAware: true,
      singleTopicPage: true,
      readerMode: false,
      contentType: "social",
      socialKind: "thread",
      platform: "Stack Overflow",
      handle: stackOverflowAuthor(question),
      replyCount: stackOverflowReplyCount(question),
      community: "Stack Overflow",
      score: stackOverflowVoteCount(question)
    };
  }

  function stackOverflowPostMarkdown(node) {
    if (!node) return "";

    var clone = cleanClone(node);
    removeAll(clone, ".js-post-menu, .post-menu, .comments, .js-comments-container, .js-add-link, .dno, [aria-hidden='true']");
    return cleanupMarkdownNoise(markdownFor(clone.innerHTML));
  }

  function stackOverflowVoteCount(root) {
    var voteNode = root.querySelector(".js-vote-count, .vote-count-post, [itemprop='upvoteCount']");
    var votes = normalizeText((voteNode && (voteNode.getAttribute("data-value") || voteNode.getAttribute("content") || voteNode.textContent)) || "");
    return /^-?\d[\d,]*$/.test(votes) ? votes.replace(/,/g, "") : "";
  }

  function stackOverflowAuthor(root) {
    return normalizeText(((root.querySelector(".user-details a") || {}).textContent || "")) || null;
  }

  function stackOverflowReplyCount(root) {
    var count = root.querySelector(".js-answer-count, [data-answercount]");
    var value = normalizeText(root.getAttribute("data-answercount") || (count && (count.getAttribute("data-answercount") || count.textContent)) || "");
    var match = value.match(/^(\d[\d,]*)\s*(?:answers?)?$/i);
    return match ? Number(match[1].replace(/,/g, "")) : null;
  }

  function registerStackOverflowProfiles() {
    registerHostAwareProfile(/(^|\.)stackoverflow\.com$/, stackOverflowContent);
  }
