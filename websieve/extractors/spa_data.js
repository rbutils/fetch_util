  // Fallback extractor for SPA pages that embed page data in JSON blobs.
  // Supports Next.js __NEXT_DATA__.

  // These are resource safeguards, not presentation quotas: normal data is fully
  // traversed, while pathological blobs stop deterministically and warn callers.
  var SPA_DATA_MAX_TRAVERSAL_CHARS = 16000000;
  var SPA_DATA_MAX_TRAVERSAL_MILLISECONDS = 100;

  function spaDataNow() {
    return typeof performance !== "undefined" && performance.now ? performance.now() : Date.now();
  }

  function spaDataFieldPriority(key) {
    var normalized = String(key || "").toLowerCase();
    if (["content", "body", "markdown", "html", "text", "rawbody", "compiledsource"].indexOf(normalized) !== -1) return 3;
    if (["article", "post", "doc", "page"].indexOf(normalized) !== -1) return 2;
    if (normalized === "description") return 1;
    return 0;
  }

  function spaDataExcludedOwnerKey(key) {
    return /^(?:related|recommend|sidebar|navigation|nav$|footer|header|advert|promot|suggested|morelikethis)/i.test(String(key || "").replace(/[_-]/g, ""));
  }

  function nextDataContent() {
    var script = document.getElementById("__NEXT_DATA__");
    if (!script) return null;

    var data;
    try { data = JSON.parse(script.textContent); } catch (e) { return null; }
    if (!data || !data.props) return null;

    var pageProps = data.props.pageProps || data.props;
    if (!pageProps) return null;

    // Walk pageProps looking for substantial text content.
    // Many Next.js API docs sites store rendered content in fields like
    // "content", "body", "markdown", "html", "description", etc.
    var texts = [];
    var title = null;
    var queue = [{ value: pageProps, priority: 0, excluded: false }];
    var visited = [];
    var queueIndex = 0;
    var traversalChars = 0;
    var traversalStarted = spaDataNow();
    var traversalGuarded = false;
    var titleKeys = ["title", "name", "heading"];

    // Traverse evidence-rich keys first, but never discard later siblings.
    while (queueIndex < queue.length && !traversalGuarded) {
      var queueEntry = queue[queueIndex++];
      var current = queueEntry.value;
      var keys;
      var orderedKeys;
      var keyIndex;

      if (typeof current === "string") {
        var trimmed = current.trim();
        traversalChars += current.length;
        if (!queueEntry.excluded && trimmed.length > 80) {
          texts.push({ text: trimmed, priority: queueEntry.priority });
        }
      } else if (current && typeof current === "object") {
        if (visited.indexOf(current) !== -1) continue;
        visited.push(current);
        keys = Object.keys(current);
        orderedKeys = [];
        keys.filter(function(key) { return spaDataFieldPriority(key) > 0; }).forEach(function(key) { orderedKeys.push(key); });
        keys.forEach(function(key) { if (orderedKeys.indexOf(key) === -1) orderedKeys.push(key); });

        if (!title) {
          for (keyIndex = 0; keyIndex < titleKeys.length; keyIndex++) {
            var titleValue = current[titleKeys[keyIndex]];
            if (typeof titleValue === "string" && titleValue.trim().length > 2) {
              title = titleValue.trim();
              break;
            }
          }
        }
        orderedKeys.forEach(function(key) {
          if (!traversalGuarded) {
            traversalChars += key.length;
            var excluded = queueEntry.excluded || spaDataExcludedOwnerKey(key);
            queue.push({
              value: current[key],
              priority: excluded ? -1 : Math.max(queueEntry.priority, spaDataFieldPriority(key)),
              excluded: excluded
            });
          }
        });
      }

      if (traversalChars >= SPA_DATA_MAX_TRAVERSAL_CHARS ||
          spaDataNow() - traversalStarted >= SPA_DATA_MAX_TRAVERSAL_MILLISECONDS) {
        traversalGuarded = queue.length > 0;
      }
    }

    // Prefer text owned by content-bearing fields, using length only within the
    // same ownership class. Unknown schemas remain eligible as a fallback.
    var bestCandidate = texts.length ? texts.reduce(function(a, b) {
      if (a.priority !== b.priority) return a.priority > b.priority ? a : b;
      return a.text.length >= b.text.length ? a : b;
    }) : null;
    var best = bestCandidate ? bestCandidate.text : "";
    if (best.length < 200) {
      if (!traversalGuarded) return null;
      return {
        title: title || document.title,
        byline: null,
        excerpt: null,
        siteName: location.hostname,
        publishedTime: null,
        html: null,
        textContent: "",
        markdown: null,
        contentType: "article",
        spaFallback: true,
        spaDataGuard: true
      };
    }

    // If the best text looks like HTML, convert it through the normal pipeline
    var isHtml = /<[a-z][^>]*>/i.test(best) && /<\/[a-z]+>/i.test(best);
    var markdown, html, textContent;

    if (isHtml) {
      html = best;
      var div = document.createElement("div");
      div.innerHTML = best;
      cleanupAgentRoot(div);
      textContent = normalizeText(div.textContent);
      markdown = null; // Let extract_api convert via markdownFor
    } else {
      // Might be raw markdown or plain text
      html = null;
      textContent = normalizeText(best);
      markdown = best;
    }

    return {
      title: title || document.title,
      byline: null,
      excerpt: textContent ? textContent.slice(0, 280) : null,
      siteName: location.hostname,
      publishedTime: null,
      html: html,
      textContent: textContent || best,
      markdown: markdown,
      contentType: "article",
      spaFallback: true,
      spaDataGuard: traversalGuarded
    };
  }

  // Check if the current extraction result is too sparse to be useful
  // and a SPA data fallback might help.
  function spaDataFallbackNeeded(content) {
    if (!content) return true;
    var text = normalizeText(content.markdown || content.textContent || "");
    // If we got very little from normal extraction, try SPA data
    return text.length < 300;
  }
