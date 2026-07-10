  function baselinkerDecodedExample(source) {
    var text = String(source || "").replace(/\\\r?\n\s*/g, "");

    try {
      text = JSON.stringify(JSON.parse(text), null, 2);
    } catch (_error) {
      text = text
        .replace(/\\n/g, "\n")
        .replace(/\\r/g, "\r")
        .replace(/\\t/g, "\t")
        .replace(/\\'/g, "'")
        .replace(/\\"/g, '"')
        .replace(/\\\\/g, "\\");
    }

    return text.trim();
  }

  function baselinkerMethodExample(methodName) {
    if (!methodName) return null;

    var pattern = new RegExp("examples\\[['\"]" + escapeRegex(methodName) + "['\"]\\]\\s*=\\s*'([\\s\\S]*?)';");
    var scripts = Array.prototype.slice.call(document.querySelectorAll("script"));

    for (var i = 0; i < scripts.length; i += 1) {
      var scriptText = scripts[i].textContent || "";
      var match = scriptText.match(pattern);
      if (match && match[1]) return baselinkerDecodedExample(match[1]);
    }

    return null;
  }

  function baselinkerDocsContent(metadata) {
    var signature = docsHostSignature(metadata);
    if (!hostMatches(/(^|\.)api\.baselinker\.com$/) && !/baselinker/i.test(signature)) return null;

    var methodName = queryParam("method");

    // For method pages, extract the visible DOM content (rendered by jQuery SPA)
    // which contains description, input/output parameters, and usage guidance
    var node = firstMatchingNode(["#main", ".main_text", "main"]);
    var result = docsContentForNode(metadata, node, {
      fallbackTitle: methodName || normalizeText((metadata.title || document.title).replace(/\s*-\s*baselinker\.com$/i, "")) || "API documentation",
      rewriteRoot: function(root) {
        // Remove method list navigation and UI chrome
        root.querySelectorAll("nav, aside, footer").forEach(function(el) { el.remove(); });
        removeNodesByText(root, "a, button, div, span", /^(method list|test your request|changelog|copy)$/i);
      }
    });

    // If DOM extraction returned very little content but we have the inline example,
    // build a fallback from the JSON example
    if (methodName && (!result || normalizeText(result.markdown || "").length < 200)) {
      var example = baselinkerMethodExample(methodName);
      if (example) {
        var markdown = [
          "# " + methodName,
          "Baselinker API request example for the `" + methodName + "` method.",
          "```json",
          example,
          "```"
        ].join("\n\n");

        return {
          title: methodName,
          byline: metadata.byline,
          excerpt: "Baselinker API request example for the " + methodName + " method.",
          siteName: metadata.siteName || location.hostname,
          publishedTime: metadata.publishedTime,
          html: "",
          markdown: markdown,
          textContent: normalizeText(markdown),
          readerMode: false,
          contentType: "article"
        };
      }
    }

    return result;
  }
