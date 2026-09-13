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
