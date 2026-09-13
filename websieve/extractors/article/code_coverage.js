  function articleCodeText(text) {
    return cleanCodeText(text).replace(/[ \t]+(?=\n|$)/g, "").trim();
  }

  function articleBodyCodeBlocks(root) {
    if (!root) return [];

    return Array.prototype.filter.call(root.querySelectorAll("pre"), function(pre) {
      if (elementSubtreeHidden(pre) || pre.closest("a[href], nav, header, footer, aside, form, menu, [hidden], [aria-hidden='true'], [role='navigation'], [role='menu'], [role='complementary'], [role='banner'], [role='contentinfo'], [role='toolbar']")) return false;

      // A linked record's preview is not an instruction owned by the surrounding page.
      var record = closestGenericListCard(pre);
      var primary = genericListStructuredCardLink(record);
      if (!primary || elementSubtreeHidden(primary) || (primary.getAttribute("href") || "")[0] === "#") return true;
      return !Array.prototype.some.call(record.parentElement.children, function(peer) {
        if (peer === record || elementSubtreeHidden(peer)) return false;
        var link = genericListStructuredCardLink(peer);
        return link && !elementSubtreeHidden(link) && (link.getAttribute("href") || "")[0] !== "#" &&
          materializedHttpUrl(link.getAttribute("href")) !== materializedHttpUrl(primary.getAttribute("href"));
      });
    }).map(function(pre) {
      var clone = pre.isConnected ? visibilityPrunedClone(pre, document) : pre.cloneNode(true);
      clone.querySelectorAll("button, [aria-hidden='true'], [hidden]").forEach(function(node) { node.remove(); });
      return articleCodeText(clone.textContent);
    }).filter(Boolean);
  }

  function listCandidateLosesCodeBlocks(root, candidate) {
    if (!candidate || candidate.contentType !== "list") return false;
    var examples = articleBodyCodeBlocks(root);
    if (!examples.length) return false;

    // List HTML can retain PRE nodes even though its Markdown renderer drops them.
    var markdown = candidate.sectionMarkdownWithDescription || candidate.markdown || "";
    var rendered = [];
    var opening = /^ {0,3}(`{3,}|~{3,})[^\n]*\n/gm;
    var match;
    while ((match = opening.exec(markdown))) {
      var fenced = markdownFencedCodeAt(markdown, match.index);
      if (!fenced) continue;
      var body = markdown.slice(opening.lastIndex, fenced.end).replace(/\n[ \t]*(?:`{3,}|~{3,})[ \t]*$/, "");
      rendered.push(articleCodeText(body));
      opening.lastIndex = fenced.end;
    }

    var cursor = 0;
    return examples.some(function(example) {
      while (cursor < rendered.length) {
        if (rendered[cursor++] === example) return false;
      }
      return true;
    });
  }

  function codeAwareHomepageList(candidate) {
    if (listCandidateLosesCodeBlocks(document.body, candidate)) candidate.provisionalPortal = true;
    return candidate;
  }

  function instructionalArticleRoot(source, clone) {
    if (!source.matches("main, article, section, div, [role='main']") ||
        source.closest("nav, header, footer, aside, form, [role='navigation'], [role='complementary']")) return false;
    if (!clone.querySelector("h1, h2, h3") || !clone.querySelector("p")) return false;
    var editor = clone.querySelector(".CodeMirror-code pre, .cm-content pre");
    if (editor && articleCodeText(editor.textContent).includes("\n")) return true;
    return articleBodyCodeBlocks(clone).length >= 2;
  }

  function instructionalFallbackContent(primary, fallback, primaryRoot, fallbackRoot) {
    if (!fallback.instructionalContentRoot || primary.contentType !== "article" ||
        primary.hostAware || primary.docsLike || primary.legalProvision || primary.markdown) return null;

    var primaryExamples = articleBodyCodeBlocks(primaryRoot);
    var fallbackExamples = articleBodyCodeBlocks(fallbackRoot);
    if (fallbackExamples.length <= primaryExamples.length || !articleMaterialPreserved(primaryRoot, fallbackRoot)) return null;

    // Preserve the selected article's metadata and provenance while restoring its examples.
    return Object.assign({}, primary, { html: fallback.html, textContent: fallback.textContent });
  }
