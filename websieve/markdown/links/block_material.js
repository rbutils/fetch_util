  function blockMaterialLinkShape(link) {
    if (link.tagName !== "A" || !link.querySelector("div, p, figure")) return false;
    if (link.querySelector("pre, table, ul, ol")) return false;
    if (link.closest("pre, code, kbd, samp, table, [hidden], details:not([open])")) return false;
    return !!materializedHttpUrl(link.getAttribute("href") || "");
  }

  function linkRequiresBlockMaterial(link) {
    if (!blockMaterialLinkShape(link)) return false;
    if (!link.querySelector("h1, h2, h3, h4, h5, h6")) return true;
    if (!link.closest("li")) return false;
    return Array.from(link.querySelectorAll("p")).some(function(paragraph) {
      return !!normalizeText(paragraph.textContent);
    });
  }

  function blockMaterialLinkHtmlBlock(html) {
    if (!/^[ \t]*<div>/i.test(html)) return false;
    var holder = document.createElement("div");
    holder.innerHTML = html;
    var roots = Array.from(holder.childNodes).filter(function(node) {
      return node.nodeType !== Node.TEXT_NODE || node.textContent.trim();
    });
    if (roots.length !== 1 || roots[0].nodeType !== Node.ELEMENT_NODE) return false;
    var wrapper = roots[0];
    if (wrapper.tagName !== "DIV" || wrapper.attributes.length) return false;
    var children = Array.from(wrapper.childNodes).filter(function(node) {
      return node.nodeType !== Node.TEXT_NODE || node.textContent.trim();
    });
    return children.length === 1 && children[0].nodeType === Node.ELEMENT_NODE && blockMaterialLinkShape(children[0]);
  }

  function blockMaterialLinkHtml(link, allowArticleMailto) {
    var holder = document.createElement("div");
    holder.appendChild(link.cloneNode(true));
    var walker = document.createTreeWalker(holder, NodeFilter.SHOW_COMMENT);
    var comments = [];
    var comment;
    while ((comment = walker.nextNode())) comments.push(comment);
    comments.forEach(function(node) { node.remove(); });
    materializeHttpAttributes(holder, false, allowArticleMailto !== false);
    // The neutral block wrapper makes the complete anchor a CommonMark HTML
    // block, keeping its physical paragraphs and literal inline material intact.
    return singleBlockMaterializedHtml(sanitizedHtml(holder.outerHTML));
  }

  function prepareBlockMaterialLinks(root, allowArticleMailto) {
    var candidates = Array.from(root.querySelectorAll("a")).filter(linkRequiresBlockMaterial);
    if (!candidates.length) return null;
    var attribute = "data-fetch-util-link-block";
    while (root.hasAttribute(attribute) || root.querySelector("[" + attribute + "]")) attribute += "-owned";
    var prefix = "FETCHUTILLINKBLOCK";
    while (root.innerHTML.indexOf(prefix) !== -1) prefix += "OWNED";
    var links = [];
    candidates.forEach(function(link) {
      links.push(blockMaterialLinkHtml(link, allowArticleMailto));
      link.setAttribute(attribute, String(links.length - 1));
      link.textContent = "x";
    });
    return { attribute: attribute, prefix: prefix, links: links };
  }

  function addBlockMaterialLinkRule(service, prepared) {
    if (!prepared) return;
    service.addRule("completeBlockLinks", {
      filter: function(node) {
        return node.nodeName === "A" && node.hasAttribute(prepared.attribute);
      },
      replacement: function(_content, node) {
        var key = node.getAttribute(prepared.attribute);
        if (!Object.prototype.hasOwnProperty.call(prepared.links, key)) throw new Error("Missing complete link snapshot");
        return "\n\n" + prepared.prefix + key + "END\n\n";
      }
    });
  }

  function restoreBlockMaterialLinks(markdown, prepared) {
    if (!prepared) return markdown;
    return markdown.replace(new RegExp(prepared.prefix + "([0-9]+)END", "g"), function(_match, key) {
      if (!Object.prototype.hasOwnProperty.call(prepared.links, key)) throw new Error("Missing rendered link snapshot");
      return prepared.links[key];
    });
  }
