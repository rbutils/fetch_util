  // Fallback extractor for SPA pages that embed page data in JSON blobs.
  // Currently supports Next.js __NEXT_DATA__ and Nuxt __NUXT_DATA__.

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

    function walk(obj, depth) {
      if (depth > 8 || !obj) return;
      if (typeof obj === "string") {
        var trimmed = obj.trim();
        if (trimmed.length > 80) texts.push(trimmed);
        return;
      }
      if (Array.isArray(obj)) {
        for (var i = 0; i < Math.min(obj.length, 200); i++) walk(obj[i], depth + 1);
        return;
      }
      if (typeof obj !== "object") return;

      // Prioritize known content keys
      var contentKeys = ["content", "body", "markdown", "html", "description", "text",
                         "article", "post", "doc", "page", "rawBody", "compiledSource"];
      for (var k = 0; k < contentKeys.length; k++) {
        var key = contentKeys[k];
        if (obj[key] && typeof obj[key] === "string" && obj[key].trim().length > 100) {
          texts.push(obj[key].trim());
        }
      }

      // Extract title
      if (!title) {
        var titleKeys = ["title", "name", "heading"];
        for (var t = 0; t < titleKeys.length; t++) {
          if (obj[titleKeys[t]] && typeof obj[titleKeys[t]] === "string" && obj[titleKeys[t]].trim().length > 2) {
            title = obj[titleKeys[t]].trim();
            break;
          }
        }
      }

      var keys = Object.keys(obj);
      for (var j = 0; j < Math.min(keys.length, 50); j++) {
        walk(obj[keys[j]], depth + 1);
      }
    }

    walk(pageProps, 0);

    if (texts.length === 0) return null;

    // Find the longest text block as the primary content
    var best = texts.reduce(function(a, b) { return a.length >= b.length ? a : b; });
    if (best.length < 200) return null;

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
      spaFallback: true
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

  function spaDataContent() {
    return nextDataContent();
  }
