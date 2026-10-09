  function componentHubPageOwner(root) {
    var chrome = "nav, aside, footer, form, [role='navigation'], [role='complementary']";
    if (!root || root.closest(chrome + ", article") || elementSubtreeHidden(root)) return null;
    var main = root.closest("main, [role='main']");
    if (!main || main === root) return null;
    var mains = Array.from(document.querySelectorAll("main, [role='main']")).filter(function(node) {
      return !elementSubtreeHidden(node);
    });
    if (mains.length !== 1 || mains[0] !== main) return null;
    var headings = Array.from(main.querySelectorAll("h1")).filter(function(node) {
      return !node.closest(chrome + ", article") && !elementSubtreeHidden(node);
    });
    if (headings.length !== 1) return null;
    var outside = Array.from(main.querySelectorAll("p, h2, h3, h4, blockquote, pre, table, figure")).some(function(node) {
      return !root.contains(node) && !node.contains(root) && !node.closest(chrome) &&
        !elementSubtreeHidden(node) && normalizeText(node.textContent || "");
    });
    return outside ? main : null;
  }

  function materializeComponentHubFields(root) {
    Array.from(root.querySelectorAll("[heading-text], [content-text]")).forEach(function(node) {
      ["heading-text", "content-text"].forEach(function(attribute) {
        var text = normalizeText(node.getAttribute(attribute) || "");
        if (!text || normalizeText(node.textContent || "").indexOf(text) !== -1) return;
        var tag = attribute === "heading-text" ? "h3" : "p";
        if (attribute === "heading-text" && /^[1-6]$/.test(node.getAttribute("heading-level") || "")) {
          tag = "h" + node.getAttribute("heading-level");
        }
        var field = document.createElement(tag);
        field.textContent = text;
        if (attribute === "heading-text") node.insertBefore(field, node.firstChild);
        else node.appendChild(field);
      });
    });
    Array.from(root.querySelectorAll("[data-cmp-data-layer]")).forEach(function(card) {
      var url = materializedHttpUrl(customElementTileDataUrl(card));
      if (!url || Array.from(card.querySelectorAll("a[href]")).some(function(link) {
        return materializedHttpUrl(link.getAttribute("href")) === url;
      })) return;
      var heading = card.querySelector("[heading-text] h1, [heading-text] h2, [heading-text] h3, [heading-text] h4, [heading-text] h5, [heading-text] h6");
      if (!heading || heading.querySelector("a")) return;
      var link = document.createElement("a");
      link.setAttribute("href", url);
      while (heading.firstChild) link.appendChild(heading.firstChild);
      heading.appendChild(link);
    });
  }

  function componentHubPageContent(metadata, root) {
    var owner = componentHubPageOwner(root);
    if (!owner) return null;
    return institutionalArticleResult(metadata, owner, {
      contentType: "list",
      minText: 1,
      titleRoot: owner,
      strip: materializeComponentHubFields
    });
  }
