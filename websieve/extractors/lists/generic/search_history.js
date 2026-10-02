  function sourceOwnedSearchHistoryContent(metadata, existingContent) {
    if (!document.body || typeof challengePageType === "function" && challengePageType(metadata, pageReadableText())) return null;

    function visible(node) {
      return !!node && !elementSubtreeHidden(node) && !node.closest(
        "nav, aside, footer, header, [role='navigation'], [role='complementary'], blockquote, q, pre, code"
      );
    }

    function historyHeading(node) {
      var text = normalizeText(node.textContent || "").toLowerCase();
      return /(?:search|recent|previous|query|поиск|истори|historial|historique|verlauf|recherche)/i.test(text) &&
        /(?:histor|history|search|query|поиск|истори|busqueda|recherche|verlauf)/i.test(text);
    }

    function primaryOwner(heading) {
      var main = heading.closest("main, [role='main']");
      if (main) return main;
      var parent = heading.parentElement;
      return parent && parent.querySelector("h1, [role='heading']") && parent.querySelector("form") &&
        parent.querySelector("ul, ol") ? parent : null;
    }

    function competingPrimaryContent(owner, heading, form, list) {
      function cloneOf(node, clone) {
        var path = [];
        var current = node;
        while (current && current !== owner) {
          var position = Array.prototype.indexOf.call(current.parentElement.children, current);
          path.unshift(position);
          current = current.parentElement;
        }
        if (current !== owner) return null;
        return path.reduce(function(parent, position) { return parent && parent.children[position]; }, clone);
      }

      var contentNodes = owner.querySelectorAll("p, article, [role='article'], figure, table, dl, blockquote, video, audio, iframe, object, embed, canvas");
      for (var index = 0; index < contentNodes.length; index += 1) {
        var node = contentNodes[index];
        if (node !== heading && node !== form && node !== list && !heading.contains(node) &&
            !form.contains(node) && !list.contains(node) && visible(node) &&
            (node.matches("article, [role='article'], figure, table, dl, blockquote, video, audio, iframe, object, embed, canvas") ||
             normalizeText(node.textContent || "").length > 40)) return true;
      }
      var pageContentNodes = document.body.querySelectorAll("main, [role='main'], article, [role='article']");
      for (var pageIndex = 0; pageIndex < pageContentNodes.length; pageIndex += 1) {
        var pageNode = pageContentNodes[pageIndex];
        if (owner.contains(pageNode) || pageNode.contains(owner) || !visible(pageNode)) continue;
        return true;
      }
      var remainder = owner.cloneNode(true);
      var removalTargets = [heading, form, list];
      Array.prototype.forEach.call(owner.querySelectorAll("*"), function(original) {
        if (!visible(original)) removalTargets.push(original);
      });
      var removals = removalTargets.map(function(original) { return cloneOf(original, remainder); }).filter(Boolean);
      removals.forEach(function(node) { if (node.parentNode) node.parentNode.removeChild(node); });
      Array.prototype.forEach.call(remainder.querySelectorAll("h1"), function(node) {
        if (node.parentNode) node.parentNode.removeChild(node);
      });
      Array.prototype.forEach.call(remainder.querySelectorAll("nav, aside, footer, header, [role='navigation'], [role='complementary']"), function(node) {
        if (node.parentNode) node.parentNode.removeChild(node);
      });
      return normalizeText(remainder.textContent || "").length > 80;
    }

    var headings = Array.prototype.filter.call(document.querySelectorAll("h1, h2, h3, h4, [role='heading']"), function(heading) {
      return visible(heading) && historyHeading(heading);
    });
    var matches = [];
    headings.forEach(function(heading) {
      var owner = primaryOwner(heading);
      if (!owner || !visible(owner) || owner.closest("nav, aside, footer, [role='navigation'], [role='complementary']")) return;
      var searchForms = Array.prototype.filter.call(owner.querySelectorAll("form"), function(form) {
        return visible(form) && (form.compareDocumentPosition(heading) & Node.DOCUMENT_POSITION_FOLLOWING) &&
          !!form.querySelector("input[type='search'], input[name][type='text'], input[type='text'][name]");
      });
      if (searchForms.length !== 1) return;
      var field = searchForms[0].querySelector("input[type='search'], input[name][type='text'], input[type='text'][name]");
      var list = heading.nextElementSibling;
      while (list && !normalizeText(list.textContent || "")) list = list.nextElementSibling;
      if (!list || !list.matches("ul, ol") || !visible(list) || !list.children.length) return;
      var fieldName = field.getAttribute("name") || "";
      var records = [];
      var queryDestinations = new Set();
      Array.prototype.forEach.call(list.children, function(row) {
        if (!visible(row)) {
          if (normalizeText(row.textContent || "")) records = null;
          return;
        }
        if (!row.matches("li")) {
          if (normalizeText(row.textContent || "") || row.querySelector("img, video, audio, iframe, object, embed, canvas, svg")) records = null;
          return;
        }
        if (records === null) return;
        var text = normalizeText(row.textContent || "");
        if (!text) { records = null; return; }
        var descendants = row.querySelectorAll("*");
        if (Array.prototype.some.call(descendants, function(node) { return !visible(node); }) ||
            row.querySelector("img, video, audio, iframe, object, embed, canvas, svg, blockquote, q, pre, code, input, button, [role='button']")) {
          records = null;
          return;
        }
        var links = Array.prototype.filter.call(row.querySelectorAll("a[href]"), visible);
        if (links.length > 1 || links.length !== row.querySelectorAll("a[href]").length) { records = null; return; }
        var destination = null;
        if (links.length) {
          var link = links[0];
          var url;
          try { url = new URL(link.getAttribute("href"), location.href); } catch (_error) { records = null; return; }
          var query = url.searchParams.get(fieldName);
          var linkText = normalizeText(link.textContent || "");
          if (url.origin !== location.origin || url.pathname !== location.pathname || !fieldName ||
              !query || !linkText || normalizeText(query) !== linkText) { records = null; return; }
          destination = url.href;
          queryDestinations.add(destination);
        }
        records.push({ text: text, url: destination, detail: "", rankScore: text.length, card: row });
      });
      if (!records || queryDestinations.size < 2 || records.length < 2) return;
      if (competingPrimaryContent(owner, heading, searchForms[0], list)) {
        if (existingContent && existingContent.contentType === "article") existingContent.sourceOwnedSearchHistoryArticleVeto = true;
        return;
      }
      matches.push({ heading: heading, list: list, owner: owner, records: records });
    });
    if (matches.length !== 1) return null;

    var match = matches[0];
    var html = document.createElement("div");
    html.appendChild(match.heading.cloneNode(true));
    var outputList = document.createElement(match.list.tagName.toLowerCase());
    match.records.forEach(function(record) { outputList.appendChild(record.card.cloneNode(true)); });
    html.appendChild(outputList);
    var output = listItemsContentResult(metadata, {
      title: metadata.title || document.title,
      excerpt: match.records[0].text,
      html: html.innerHTML,
      items: match.records,
      markdown: listMarkdown(match.records)
    });
    output.sourceOwnedSearchHistory = true;
    output.sourceOwnedSearchHistoryCoverage = match.records.length;
    if (existingContent &&
        (listCandidateLosesArticleMaterial(existingContent, output) || listCandidateLosesArticleListMaterial(existingContent, output))) {
      if (existingContent.contentType === "article") existingContent.sourceOwnedSearchHistoryArticleVeto = true;
      return null;
    }
    return output;
  }
