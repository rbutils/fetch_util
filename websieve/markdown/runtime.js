  function contentBodyMarkdown(content) {
    var markdown = content.markdown;
    var allowArticleMailto = inlineArticleMailtoMaySurviveUntilFinalType(content);
    if (content.focalPublicPreview && content.html) markdown = markdownFor(sanitizedHtml(content.html, true), true, allowArticleMailto);
    else if (!markdown && content.html) markdown = markdownFor(sanitizedHtml(content.html), false, allowArticleMailto);
    return cleanupMarkdownNoise(markdown || content.textContent || "").trim();
  }

  function contentMarkdownWithDetails(body, title, details) {
    var heading = title ? "# " + title : "";
    var lines = body.split("\n");
    var firstHeading = lines[0].match(/^#{1,6}[ \t]+(.+)$/);
    if (firstHeading && normalizeText(firstHeading[1]) === normalizeText(title)) {
      heading = lines.shift();
      body = lines.join("\n").trim();
    }
    return [heading, details, body].filter(Boolean).join("\n\n");
  }

  function convertMarkdownRoot(root, allowSerializedOwnedPublicPreviews, allowArticleMailto, preserveCleanedRoot, convertRoot) {
    pruneClosedMarkdownDisclosures(root);
    var frameReferences = markdownFrameReferences(root);
    materializeMarkdownVideoReferences(root);
    materializeMarkdownSvgText(root);
    preserveAccessibleLinkLabels(root);
    mergeAdjacentCitationLetters(root);
    preserveInlineProse(root);
    mergeAdjacentEmphasis(root);
    preserveLiteralInlineCode(root);
    if (!preserveCleanedRoot) cleanupAgentRoot(root, allowSerializedOwnedPublicPreviews);
    materializeMarkdownFrameReferences(root, frameReferences);
    var blockMaterialTables = prepareBlockMaterialTables(root, allowArticleMailto);
    var blockMaterialLinks = prepareBlockMaterialLinks(root, allowArticleMailto);
    normalizeCodeBlocks(root);
    var blockOwnedPrograms = prepareBlockOwnedLiteralPrograms(root);
    preserveWholeInlineCodeLinks(root);
    preserveStructuredCardLinks(root);
    unwrapWrapperDivs(root);
    materializeMarkdownHeadingLayouts(root);
    separateAdjacentInlineLinks(root);
    materializeHttpAttributes(root, false, allowArticleMailto !== false);
    preserveUnlabeledMarkdownDestinations(root);

    var literalPrograms = prepareLiteralCodePrograms(root);

    var service = new TurndownService({
      headingStyle: "atx",
      preformattedCode: true,
      codeBlockStyle: "fenced",
      bulletListMarker: "-",
      emDelimiter: "_"
    });
    var preparedTables = null;
    var prepareLinkBoundaries = prepareMarkdownLinkBoundaryEscaping(service);
    service.options.fetchUtilPrepareRoot = function(normalizedRoot) {
      prepareLinkBoundaries(normalizedRoot);
      preparedTables = prepareDataTableMarkdown(normalizedRoot);
    };
    service.remove(["script", "style", "noscript", "template"]);
    service.addRule("disclosureBlocks", {
      filter: ["details", "summary"],
      replacement: function(content) {
        return "\n\n" + content.trim() + "\n\n";
      }
    });
    addIntrawordEmphasisRule(service);
    addOrderedListContinuationRule(service);
    preserveLiteralAngleText(service);

    service.addRule("tables", {
      filter: function(node) {
        return node.nodeName === "TABLE";
      },
      replacement: function(content, node) {
        var blockMaterial = blockMaterialTableToken(node, blockMaterialTables);
        if (blockMaterial !== null) return "\n\n" + blockMaterial + "\n\n";
        var prepared = preparedDataTableMarkdown(node, preparedTables);
        if (prepared !== null) return "\n\n" + prepared + "\n\n";
        return "\n\n" + tableToMarkdown(node, content) + "\n\n";
      }
    });

    service.addRule("preformatted", {
      filter: function(node) {
        return node.nodeName === "PRE";
      },
      replacement: function(_content, node) {
        var programKey = node.getAttribute(literalPrograms.attribute);
        if (programKey !== null) {
          var program = literalPrograms.programs[Number(programKey)];
          if (program) return program.html ? "\n\n" + program.html + "\n\n" : fencedCodeBlock(program.language, program.text);
        }
        var code = node.querySelector("code");
        var text = cleanCodeText(code ? code.textContent : node.textContent);
        if (!text) return "\n\n";
        var language = (code && code.getAttribute("data-language")) || guessCodeLanguage(code || node);
        return fencedCodeBlock(language, text);
      }
    });
    addBlockOwnedLiteralProgramRule(service, blockOwnedPrograms);

    service.addRule("blockCodeWrappers", {
      filter: function(node) {
        return node.nodeName === "CODE" && node.querySelector("pre");
      },
      replacement: function(content) {
        return "\n\n" + content.trim() + "\n\n";
      }
    });

    service.addRule("images", {
      filter: function(node) {
        return node.nodeName === "IMG";
      },
      replacement: function(_content, node) {
        var src = node.getAttribute("src") || node.getAttribute("data-src") || node.getAttribute("data-lazy-src") || "";
        var alt = normalizeText(node.getAttribute("alt") || "").replace(/[\[\]]/g, "");
        var url = materializedHttpUrl(src);
        return url ? "![" + alt + "](" + url + ")" : alt;
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
        return markdownLink(text.replace(/[\\[\]]/g, ""), href);
      }
    });

    service.addRule("paragraphLikeDivs", {
      filter: paragraphLikeDiv,
      replacement: function(content) {
        var text = normalizeText(content);
        if (!text) return "";
        return "\n\n" + content.trim() + "\n\n";
      }
    });

    service.addRule("structuredCardField", {
      filter: function(node) {
        return node.nodeType === 1 && node.hasAttribute("data-fetch-util-structured-card-field");
      },
      replacement: function(content) {
        return "\n\n" + STRUCTURED_CARD_FIELD_MARKER + content.trim() + "\n\n";
      }
    });

    service.addRule("blockLabelLinks", {
      filter: function(node) {
        return node.nodeName === "A" && node.querySelector("div, p, figure") &&
          !node.querySelector("pre, table, ul, ol, h1, h2, h3, h4, h5, h6");
      },
      replacement: function(content, node) {
        // Markdown link labels cannot contain the blank lines introduced by block children.
        var label = content.trim().replace(/\s*\n+\s*/g, " ");
        return markdownLinkWithFormattedLabel(label, node.getAttribute("href"));
      }
    });

    service.addRule("headingCardLinks", {
      filter: function(node) {
        return node.nodeName === "A" && !node.closest("li") && node.querySelector("h1, h2, h3, h4, h5, h6") &&
          !node.querySelector("pre, table");
      },
      replacement: function(content, node) {
        // Associate the destination with the card's heading without flattening its body.
        var body = content.trim().replace(/^(#{1,6}[ \t]+)([^\n]+)/m, function(_match, prefix, label) {
          return prefix + markdownLinkWithFormattedLabel(label, node.getAttribute("href"));
        });
        return "\n\n" + body + "\n\n";
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

    addBlockMaterialLinkRule(service, blockMaterialLinks);
    var converted = convertRoot ? convertRoot(service, root) : service.turndown(root);
    var protectedMarkdown = protectMarkdownFences(converted);
    var md = protectedMarkdown.markdown.replace(/\n{3,}/g, "\n\n").trim();
    // Strip residual raw HTML tags outside of code blocks
    md = md.replace(/(```[\s\S]*?```|`[^`\n]+`)|<\/?[a-z][^>]*>/gi, function(match, codeBlock, offset, text) {
      return codeBlock || markdownEscapedAt(text, offset) ? match : "";
    });
    var restored = restoreMarkdownFences(md.replace(/\n{3,}/g, "\n\n").trim(), protectedMarkdown.blocks);
    return restoreBlockMaterialTables(restoreBlockMaterialLinks(restored, blockMaterialLinks), blockMaterialTables);
  }

  function paragraphLikeDiv(node) {
    if (node.nodeName !== "DIV") return false;
    var text = normalizeText(node.textContent);
    if (!text || text.length < 20) return false;
    return !node.querySelector("div, p, table, ul, ol, h1, h2, h3, h4, h5, h6, pre, blockquote, article, section");
  }

  function separateAdjacentInlineLinks(root) {
    root.querySelectorAll("a + a").forEach(function(link) {
      var previous = link.previousSibling;
      if (!previous || previous.nodeType !== Node.ELEMENT_NODE || previous.nodeName !== "A") return;
      if (link.closest("pre, code, kbd, samp") || previous.closest("pre, code, kbd, samp")) return;
      if (!adjacentLinkGroupOwnsSpacing(previous, link)) return;
      var previousLabel = inlineLinkLabel(previous);
      var linkLabel = inlineLinkLabel(link);
      if (!previousLabel || !linkLabel) return;
      if (adjacentTagControlLabel(previousLabel) || adjacentTagControlLabel(linkLabel)) return;
      if (/^["'“”‘’\-–—,.;:!?…)\]}，．。、；：！？）》】」』]/u.test(linkLabel) || /[(\[{“‘«‹（《【「『]$/u.test(previousLabel)) return;
      link.parentNode.insertBefore(document.createTextNode(" "), link);
    });
  }

  function adjacentLinkGroupOwnsSpacing(previous, link) {
    var htmlNamespace = "http://www.w3.org/1999/xhtml";
    if (previous.namespaceURI !== htmlNamespace || link.namespaceURI !== htmlNamespace) return false;
    if (previous.parentElement !== link.parentElement) return false;
    if (previous.matches("[rel~='tag' i]") && link.matches("[rel~='tag' i]")) return true;

    if (tagSpacingEvidence(link.parentElement)) return true;
    return tagSpacingEvidence(previous) && tagSpacingEvidence(link);
  }

  function tagSpacingEvidence(node) {
    var evidence = ["class", "id", "data-component", "data-testid"].flatMap(function(attribute) {
      return String(node.getAttribute(attribute) || "").trim().split(/\s+/).filter(Boolean);
    });
    return evidence.some(function(value) {
      return /^(?:tags?|topics?|categories?|chips?|pills?|tag-list|taglist|tag-cloud|tagcloud|topic-list|topiclist|category-list|category-links|chip-list|chiplist|pill-list|pilllist|article-tags|post-tags|entry-tags|content-tags|story-tags)$/i.test(value);
    });
  }

  function adjacentTagControlLabel(label) {
    var normalized = normalizeText(label).replace(/[.!?…,:;，．。、；：！？]+$/u, "").trim();
    return /^(?:home|menu|search|sign in|log in|login|register|subscribe|newsletter|learn more|read more|view all|see all|show more|more|next|previous|back|continue|open|close)$/i.test(normalized);
  }

  function inlineLinkLabel(link) {
    for (var owner = link; owner; owner = owner.parentElement) {
      if (owner.matches("[hidden], [aria-hidden='true']")) return "";
      if (/display\s*:\s*none|visibility\s*:\s*hidden/i.test(owner.getAttribute("style") || "")) return "";
    }
    var visible = link.cloneNode(true);
    visible.querySelectorAll("script, style, template, [hidden], [aria-hidden='true']").forEach(function(node) {
      node.remove();
    });
    visible.querySelectorAll("[style]").forEach(function(node) {
      if (/display\s*:\s*none|visibility\s*:\s*hidden/i.test(node.getAttribute("style") || "")) node.remove();
    });
    var text = normalizeText(visible.textContent);
    if (text) return text;
    var image = Array.prototype.find.call(visible.querySelectorAll("img[alt]"), function(candidate) {
      return !!normalizeText(candidate.getAttribute("alt"));
    });
    return image ? normalizeText(image.getAttribute("alt")) : "";
  }

  function preserveInlineProse(root) {
    root.querySelectorAll("font, span, a[style], b[style], i[style], u[style], em[style], strong[style], mark[style]").forEach(function(node) {
      node.removeAttribute("style");
    });

    root.querySelectorAll("font, p > span, li > span, blockquote > span").forEach(function(node) {
      node.replaceWith.apply(node, Array.prototype.slice.call(node.childNodes));
    });
  }
