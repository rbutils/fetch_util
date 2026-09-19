  function genericListDirectAnchorTitle(link, container) {
    if (!genericListDirectAnchorCard(link, container === link ? link.parentElement : container)) return "";
    var titleNode = link.querySelector("[class*='title' i], [class$='-name' i]");
    var title = normalizeText((titleNode && titleNode.textContent) || link.getAttribute("title") || "");
    return title.length >= Math.min(6, minimumListTitleLength(title)) && title.length <= 220 ? title : "";
  }

  function genericListAuthorFieldAmbiguous(node) {
    return Array.from(node.querySelectorAll("*")).some(function(descendant) {
      if (!normalizeText(descendant.textContent || "")) return false;
      return listCardNodeHidden(descendant) || !!genericListInteractionOwner(descendant);
    });
  }

  function genericListOwnedAnchorTitle(link) {
    if (!link || !link.matches || !link.matches("a[href]") ||
        !materializedHttpUrl(link.getAttribute("href"))) return "";
    var record = link.closest("article, li, tr");
    if (!record || genericListPrimaryHeadingLink(record) !== link) return "";

    var headings = Array.from(link.querySelectorAll("h1, h2, h3, h4"));
    if (headings.length !== 1) return "";
    var heading = headings[0];
    var titleFields = Array.from(heading.querySelectorAll(
      "[itemprop~='headline'], [class~='title'], [class*='__title'], [class$='-title']"
    )).filter(function(node) {
      return !listCardNodeHidden(node) && !genericListAuthorMetadataNode(node);
    });
    if (titleFields.length !== 1) return "";

    var title = normalizeText(titleFields[0].textContent || "");
    var declaredTitle = normalizeText(link.getAttribute("title") || "");
    if (!title || declaredTitle !== title || title.length > 220) return "";

    var authorFields = Array.from(heading.querySelectorAll("*"))
      .filter(function(node) {
        return genericListAuthorMetadataNode(node) && !genericListInteractionOwner(node) &&
          !listCardNodeHidden(node) && !genericListAuthorFieldAmbiguous(node);
      })
      .filter(function(node, _index, fields) {
        return !fields.some(function(owner) { return owner !== node && owner.contains(node); });
      });
    if (authorFields.length !== 1) return "";

    var author = normalizeText(authorFields[0].textContent || "");
    var headingText = normalizeText(heading.textContent || "");
    if (!author || (headingText !== normalizeText(title + " " + author) &&
        headingText !== normalizeText(author + " " + title))) return "";
    return title;
  }

  function genericListCardMaterialAfter(card, link) {
    var passedLink = false;
    var material = false;
    var resourceSelector = "img, picture, svg, video, audio, canvas, object, iframe, table, pre, code";

    function visit(node) {
      if (material) return;
      if (node === link) {
        passedLink = true;
        return;
      }
      if (passedLink && node.nodeType === 3) {
        material = !!normalizeText(node.textContent || "");
        return;
      }
      if (node.nodeType !== 1 || listCardNodeHidden(node)) return;
      if (passedLink && (normalizeText(node.textContent || "") || node.matches(resourceSelector))) {
        material = true;
        return;
      }
      composedDomChildren(node).forEach(visit);
    }

    visit(card);
    return material;
  }

  function genericListInertSvgStyle(value) {
    var source = String(value || "").trim();
    if (!source || /["'\\()]|\b(?:url|expression)\b|javascript:|@import/i.test(source)) return false;
    var declarations = source.split(";");
    if (!declarations[declarations.length - 1].trim()) declarations.pop();
    if (!declarations.length || declarations.some(function(declaration) { return !declaration.trim(); })) return false;
    return declarations.every(function(declaration) {
      return /^opacity\s*:\s*(?:0(?:\.\d+)?|1(?:\.0+)?)(?:\s*!important)?$/i.test(declaration.trim()) ||
        /^transform\s*:\s*none(?:\s*!important)?$/i.test(declaration.trim());
    });
  }

  function genericListInertSvgPaint(value) {
    return /^(?:none|currentcolor|context-fill|context-stroke|#[0-9a-f]{3,8})$/i.test(
      String(value || "").trim()
    );
  }

  function genericListInertSvgAttribute(node, attribute) {
    var name = String(attribute.name || "").toLowerCase();
    var tag = String(node.localName || "").toLowerCase();
    var shared = ["x", "y", "width", "height", "opacity", "preserveaspectratio"];
    if (/^on/i.test(String(attribute.name || ""))) return false;
    if (name === "style" && (tag === "svg" || tag === "image")) {
      return genericListInertSvgStyle(attribute.value);
    }
    if ((name === "fill" || name === "stroke") && tag === "svg") {
      return genericListInertSvgPaint(attribute.value);
    }
    if (tag === "image") return ["href", "xlink:href"].concat(shared).indexOf(name) !== -1;
    if (tag !== "svg") return false;
    return ["xmlns", "xmlns:xlink", "viewbox"].concat(shared).indexOf(name) !== -1;
  }

  function genericListInertSvgImageHref(image) {
    var references = Array.prototype.filter.call(image.attributes || [], function(attribute) {
      var name = String(attribute.name || "").toLowerCase();
      return name === "href" || name === "xlink:href";
    }).map(function(attribute) { return String(attribute.value || ""); });
    return references.length > 0 && references.every(function(url) {
      return /^data:(?:image|img)\/(?:avif|bmp|gif|jpe?g|png|webp)(?:[;,])/i.test(url);
    });
  }

  function genericListInertImageSvg(svg, heading) {
    if (!heading || !(svg.compareDocumentPosition(heading) & Node.DOCUMENT_POSITION_FOLLOWING) ||
        normalizeText(svg.textContent || "")) return false;
    var nodes = [svg].concat(Array.prototype.slice.call(svg.querySelectorAll("*")));
    if (nodes.some(function(node) {
      return Array.prototype.some.call(node.attributes || [], function(attribute) {
        return !genericListInertSvgAttribute(node, attribute);
      });
    })) return false;
    var children = nodes.slice(1);
    if (!children.length || children.some(function(node) {
      return String(node.localName || "").toLowerCase() !== "image" ||
        node.namespaceURI !== "http://www.w3.org/2000/svg";
    })) return false;
    return children.every(genericListInertSvgImageHref);
  }

  function genericListCardContextHeading(card, link) {
    if (!card || !link || !card.contains(link) ||
        !materializedHttpUrl(link.getAttribute("href"))) return null;

    var directElements = Array.from(card.children || []);
    var directHeadings = directElements.filter(function(node) {
      return /^H[1-4]$/.test(node.tagName || "");
    });
    var directParagraphs = directElements.filter(function(node) {
      return node.tagName === "P" && normalizeText(node.textContent || "");
    });
    if (link.parentElement !== card || directHeadings.length !== 1 || !directParagraphs.length ||
        directElements.some(function(node) {
          return !/^(?:A|H[1-4]|I|P|SVG)$/.test(node.tagName || "");
        }) || Array.prototype.some.call(card.childNodes || [], function(node) {
          return node.nodeType === 3 && !!normalizeText(node.textContent || "");
        }) || genericListInteractionOwner(card)) return null;

    // Build one descendant inventory only after the cheap direct-child shape proof.
    var descendants = Array.from(card.querySelectorAll("*"));
    if (descendants.some(function(node) { return node.matches([
      "button", "form", "input", "select", "textarea", "summary",
      "[role='button']", "[role='menuitem']", "[role='tab']",
      "[contenteditable]:not([contenteditable='false'])"
    ].join(", ")); })) return null;
    if (descendants.filter(function(node) { return node.hasAttribute("role"); }).some(function(node) {
      var tokens = normalizeText(node.getAttribute("role") || "").toLowerCase().split(/\s+/);
      return tokens.some(function(token) {
        return [
          "button", "checkbox", "combobox", "listbox", "menuitem", "option",
          "radio", "slider", "spinbutton", "switch", "tab", "treeitem"
        ].indexOf(token) !== -1;
      });
    })) return null;
    if (descendants.some(function(node) {
      return String(node.localName || "").indexOf("-") !== -1;
    })) return null;

    var allLinks = descendants.filter(function(node) { return node.matches("a[href]"); });
    var links = allLinks.filter(function(candidate) {
      return !listCardNodeHidden(candidate);
    });
    var headings = directHeadings.filter(function(heading) {
      return !listCardNodeHidden(heading) && !allLinks.some(function(anchor) { return heading.contains(anchor); });
    });
    var heading = headings[0];
    var svgNodes = descendants.filter(function(node) { return node.tagName === "svg"; });
    var decorativeSvgs = svgNodes.filter(function(svg) {
      return genericListInertImageSvg(svg, heading);
    });
    var paragraphs = directParagraphs.filter(function(paragraph) {
      return !listCardNodeHidden(paragraph) && normalizeText(paragraph.textContent || "");
    });
    if (links.length !== 1 || links[0] !== link || headings.length !== 1 ||
        descendants.filter(function(node) { return /^H[1-4]$/.test(node.tagName || ""); }).length !== headings.length ||
        descendants.filter(function(node) { return node.tagName === "P"; }).length !== paragraphs.length ||
        !paragraphs.some(function(paragraph) {
          return normalizeText(paragraph.textContent || "").length >= 40;
        }) || descendants.some(function(node) { return node.matches([
          "article", "aside", "section", "li", "tr", "table", "fieldset", "details",
          "figure", "blockquote", "ul", "ol", "dl", "pre", "code",
          "img", "picture", "video", "audio", "canvas", "iframe",
          "script", "style", "template", "noscript"
        ].join(", ")); })) return null;
    if (svgNodes.length !== decorativeSvgs.length) return null;

    var headingText = normalizeText(heading.textContent || "");
    var headingBeforeLink = !!(heading.compareDocumentPosition(link) & Node.DOCUMENT_POSITION_FOLLOWING);
    var paragraphsBetween = paragraphs.every(function(paragraph) {
      if (paragraph.contains(link)) return false;
      return !!(heading.compareDocumentPosition(paragraph) & Node.DOCUMENT_POSITION_FOLLOWING) &&
        !!(paragraph.compareDocumentPosition(link) & Node.DOCUMENT_POSITION_FOLLOWING);
    });
    if (!headingBeforeLink || !paragraphsBetween || genericListCardMaterialAfter(card, link) ||
        headingText.length < 3 || headingText.length > 160) return null;

    return { text: headingText, node: heading };
  }

  function genericLinkedCollectionHeading(link, card) {
    if (!homepageRootPath() || !link || !card || !card.contains(link)) return false;
    var heading = link.closest("h1, h2, h3");
    if (!heading || heading.closest("article, li, tr") ||
        heading.closest("nav, header, footer, form, menu, [role='navigation'], [role='menu'], [role='toolbar']")) return false;
    var links = Array.from(heading.querySelectorAll("a[href]"));
    var url = links.length === 1 && materializedHttpUrl(link.getAttribute("href"));
    if (!url || links[0] !== link || url.split("#")[0] === location.href.split("#")[0]) return false;

    var hints = [heading.id, heading.className, link.id, link.className].join(" ").replace(/([a-z\d])([A-Z])/g, "$1 $2");
    if (!/(?:^|[\s_-])(?:section|category|topic|desk|collection|widget)(?:$|[\s_-])/i.test(hints) ||
        !/(?:^|[\s_-])(?:title|heading)(?:$|[\s_-])/i.test(hints)) return false;

    var records = Array.from(card.querySelectorAll("article, li, tr")).filter(function(record) {
      if (record.parentElement && record.parentElement.closest("article, li, tr")) return false;
      if (record.closest("nav, header, footer, form, menu, [role='navigation'], [role='menu'], [role='toolbar']")) return false;
      return !listCardNodeHidden(record) && !!genericListPrimaryHeadingLink(record);
    });
    return records.length >= 2;
  }
