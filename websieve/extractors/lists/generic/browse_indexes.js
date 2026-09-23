  function sourceOwnedBrowseGroup(heading) {
    if (elementSubtreeHidden(heading) ||
        heading.closest("header, footer, nav, aside, menu, form, [role='navigation'], [role='complementary']")) return null;

    var links = Array.from(heading.querySelectorAll("a[href]")).filter(function(link) {
      return !elementSubtreeHidden(link);
    });
    if (links.length < 12) return null;

    var destinations = new Set();
    var letters = 0;
    var years = 0;
    var items = [];
    for (var index = 0; index < links.length; index += 1) {
      var text = normalizeText(links[index].textContent || "");
      var url = materializedHttpUrl(links[index].getAttribute("href"));
      if (!text || !url || destinations.has(listCanonicalKey(url)) ||
          new URL(url, location.href).origin !== location.origin) return null;
      destinations.add(listCanonicalKey(url));
      if (/^[A-Z]$/i.test(text)) letters += 1;
      if (/^[12]\d{3}$/.test(text)) years += 1;
      items.push({ text: text, url: url });
    }
    if ((letters < 12 || letters * 4 < items.length * 3) &&
        (years < 12 || years * 4 < items.length * 3)) return null;

    var label = heading.cloneNode(true);
    label.querySelectorAll("a[href]").forEach(function(link) { link.remove(); });
    return { node: heading, label: normalizeText(label.textContent || ""), items: items };
  }

  function sourceOwnedBrowseIndexContent(content, metadata) {
    if (!document.body || !content || content.contentType !== "article" || !content.readerMode ||
        content.hostAware || content.docsLike || content.legalProvision || articleRouteFocalContent(content)) return null;

    var owner = document.querySelector("main, [role='main'], #content") || document.body;
    var title = owner.matches("body") ? Array.from(owner.children).find(function(child) {
      return child.matches("h1") && !elementSubtreeHidden(child);
    }) : owner.querySelector("h1");
    if (!title || !normalizeText(title.textContent || "")) return null;

    var indexHeadings = Array.from(owner.querySelectorAll("h2, h3, h4")).filter(function(heading) {
      return !heading.closest("header, footer, nav, aside, menu, form, [role='navigation'], [role='complementary']") &&
        heading.querySelectorAll("a[href]").length >= 12 &&
        !!(title.compareDocumentPosition(heading) & Node.DOCUMENT_POSITION_FOLLOWING);
    });
    if (!indexHeadings.length) return null;
    var groups = indexHeadings.map(sourceOwnedBrowseGroup);
    if (groups.some(function(group) { return !group; })) return null;

    var items = groups.reduce(function(all, group) { return all.concat(group.items); }, []);
    var namedLinks = Array.from(owner.querySelectorAll("a[href]")).filter(function(link) {
      return !elementSubtreeHidden(link) && normalizeText(link.textContent || "") &&
        materializedHttpUrl(link.getAttribute("href"));
    });
    if (items.length < 20 || items.length * 10 < namedLinks.length * 6 ||
        new Set(items.map(function(item) { return listCanonicalKey(item.url); })).size !== items.length) return null;

    var previous = document.createElement("div");
    previous.innerHTML = content.html || "";
    var previousHeading = previous.querySelector("h1, h2, h3");
    var ownedPreviousHeading = previousHeading && Array.from(owner.querySelectorAll("h1, h2, h3")).find(function(heading) {
      return normalizeText(heading.textContent || "") === normalizeText(previousHeading.textContent || "");
    });
    if (!ownedPreviousHeading || groups.some(function(group) {
      return group.items.some(function(item) { return previous.innerHTML.indexOf(item.url) >= 0; });
    })) return null;

    var root = document.createElement("div");
    var pageTitle = document.createElement("h1");
    pageTitle.textContent = normalizeText(title.textContent || "");
    root.appendChild(pageTitle);
    var markdownParts = ["# " + pageTitle.textContent];
    var parts = groups.map(function(group) { return { node: group.node, group: group }; });
    parts.push({ node: ownedPreviousHeading, previous: previous });
    parts.sort(function(a, b) {
      var position = a.node.compareDocumentPosition(b.node);
      return position & Node.DOCUMENT_POSITION_FOLLOWING ? -1 : position & Node.DOCUMENT_POSITION_PRECEDING ? 1 : 0;
    });
    parts.forEach(function(part) {
      if (part.previous) {
        root.appendChild(part.previous);
        markdownParts.push(markdownFor(part.previous.innerHTML));
        return;
      }
      var heading = document.createElement("h2");
      heading.textContent = part.group.label;
      root.appendChild(heading);
      var list = document.createElement("ul");
      part.group.items.forEach(function(item) {
        var row = document.createElement("li");
        var link = document.createElement("a");
        link.href = item.url;
        link.textContent = item.text;
        row.appendChild(link);
        list.appendChild(row);
      });
      root.appendChild(list);
      markdownParts.push("## " + part.group.label + "\n\n" + part.group.items.map(function(item) {
        return "- " + markdownLink(item.text, item.url);
      }).join("\n"));
    });

    var result = listItemsContentResult(metadata, {
      title: content.title || metadata.title || document.title,
      html: root.innerHTML,
      textContent: normalizeText(root.textContent || ""),
      markdown: markdownParts.join("\n\n"),
      items: items
    });
    result.browseIndexEvidence = true;
    return result;
  }

  function prepareSourceOwnedBrowseIndex(content, metadata) {
    if (content && content.contentType === "article" && !content.hostAware) {
      var owned = sourceOwnedBrowseIndexContent(content, metadata);
      if (owned) content.browseIndexContent = owned;
    }
    return content;
  }
