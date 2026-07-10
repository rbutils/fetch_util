  function markdownFor(html) {
    if (typeof TurndownService !== "function") return html;

    var root = document.createElement("div");
    root.innerHTML = html;
    cleanupAgentRoot(root);
    normalizeCodeBlocks(root);
    unwrapWrapperDivs(root);

    var service = new TurndownService({
      headingStyle: "atx",
      codeBlockStyle: "fenced",
      bulletListMarker: "-",
      emDelimiter: "_"
    });

    service.addRule("tables", {
      filter: function(node) {
        return node.nodeName === "TABLE";
      },
      replacement: function(content, node) {
        return "\n\n" + tableToMarkdown(node, content) + "\n\n";
      }
    });

    service.addRule("preformatted", {
      filter: function(node) {
        return node.nodeName === "PRE";
      },
      replacement: function(_content, node) {
        var code = node.querySelector("code");
        var text = cleanCodeText(code ? code.textContent : node.textContent);
        if (!text) return "\n\n";
        var language = (code && code.getAttribute("data-language")) || guessCodeLanguage(code || node);
        return fencedCodeBlock(language, text);
      }
    });

    service.addRule("images", {
      filter: function(node) {
        return node.nodeName === "IMG";
      },
      replacement: function(_content, node) {
        var src = node.getAttribute("src") || node.getAttribute("data-src") || node.getAttribute("data-lazy-src") || "";
        var alt = normalizeText(node.getAttribute("alt") || "").replace(/[\[\]]/g, "");
        if (!src || !alt) return "";
        return "![" + alt + "](" + absoluteUrl(src) + ")";
      }
    });

    function legalCitationAnchor(node) {
      var href = node.getAttribute("href") || "";
      var text = normalizeText(node.textContent || "");
      if (!text || !href) return false;
      if (/govinfo\.gov\/link\/(?:uscode|plaw|statute)|ecfr\.gov\/current\/title-\d+/i.test(href)) {
        return /^(?:\d+\s+U\.?S\.?C\.?\s+)?[\dA-Za-z][\dA-Za-z.\-(),\s]*(?:\s+(?:note|nt\.?))?[,]?$/.test(text) ||
          /^(?:Pub\.\s*L\.|Section\s+\d)/i.test(text);
      }
      return /^(?:\d+\s+U\.?S\.?C\.?\s+)[\dA-Za-z][\dA-Za-z.\-(),\s]*(?:\s+(?:note|nt\.?))?[,]?$/.test(text);
    }

    service.addRule("legalCitationLinks", {
      filter: function(node) {
        return node.nodeName === "A" && legalCitationAnchor(node);
      },
      replacement: function(_content, node) {
        var href = node.getAttribute("href") || "";
        var text = normalizeText(node.textContent || "").replace(/\s+([,;:.])/g, "$1").replace(/\s+-\s+/g, "-");
        if (!href || !text) return text;
        return "[" + text.replace(/[\\[\]]/g, "") + "](" + absoluteUrl(href) + ")";
      }
    });

    service.addRule("paragraphLikeDivs", {
      filter: function(node) {
        if (node.nodeName !== "DIV") return false;
        var text = normalizeText(node.textContent);
        if (!text || text.length < 20) return false;
        var blockChildren = node.querySelectorAll("div, p, table, ul, ol, h1, h2, h3, h4, h5, h6, pre, blockquote, article, section");
        return blockChildren.length === 0;
      },
      replacement: function(content) {
        var text = normalizeText(content);
        if (!text) return "";
        return "\n\n" + content.trim() + "\n\n";
      }
    });

    // Strip inline-styled elements that Turndown would otherwise pass through as raw HTML
    service.addRule("stripStyledInlineElements", {
      filter: function(node) {
        if (node.nodeType !== 1) return false;
        var tag = node.nodeName;
        // Always strip FONT tags (they carry color/size attrs that produce raw HTML)
        if (tag === "FONT") return true;
        if (tag === "A" || tag === "SPAN" || tag === "B" || tag === "I" || tag === "U" || tag === "EM" || tag === "STRONG" || tag === "MARK") {
          return !!node.getAttribute("style");
        }
        return false;
      },
      replacement: function(content) {
        return content;
      }
    });

    var md = service.turndown(root).replace(/\n{3,}/g, "\n\n").trim();
    // Strip residual raw HTML tags outside of code blocks
    md = md.replace(/(```[\s\S]*?```|`[^`\n]+`)|<\/?[a-z][^>]*>/gi, function(match, codeBlock) {
      return codeBlock ? codeBlock : "";
    });
    return md.replace(/\n{3,}/g, "\n\n").trim();
  }
