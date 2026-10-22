  function homepageLeadRole(node, role) {
    return normalizeText(node.getAttribute("role") || "").toLowerCase().split(/\s+/).indexOf(role) !== -1;
  }

  function sourceOwnedPortalPath(metadata) {
    if (homepageRootPath()) return true;
    var signature = normalizeText([
      metadata && metadata.title, metadata && metadata.excerpt, document.title
    ].filter(Boolean).join(" "));
    if (!/\b(news|headlines|top stories|latest|breaking)\b/i.test(signature)) return false;
    var roots = Array.from(document.querySelectorAll("main, [role='main']")).filter(function(root) {
      return !elementSubtreeHidden(root) && !root.parentElement.closest("main, [role='main']");
    });
    if (roots.length !== 1) return false;
    var root = roots[0];
    if (root.querySelector("article h1, [itemprop~='articleBody'], [role='article'] h1")) return false;
    var cards = new Set();
    root.querySelectorAll("a[href]").forEach(function(link) {
      if (!leadTitle(link)) return;
      var card = link.closest("article, section, li, [class~='card'], [class~='story'], [role='listitem']");
      if (card && card !== root && root.contains(card)) cards.add(card);
    });
    var independentCards = Array.from(cards).filter(function(card) {
      var parent = card.parentElement;
      while (parent && parent !== root) {
        if (cards.has(parent)) return false;
        parent = parent.parentElement;
      }
      return true;
    });
    if (independentCards.length < 4) return false;
    var independentSet = new Set(independentCards);
    function cardOwns(node) {
      while (node && node !== root) {
        if (independentSet.has(node)) return true;
        node = node.parentElement;
      }
      return false;
    }
    var declaredSection = Array.from(root.querySelectorAll("h2, h3")).some(function(heading) {
      return !elementSubtreeHidden(heading) && !cardOwns(heading);
    });
    if (declaredSection) return false;
    return !Array.from(root.querySelectorAll("p, pre, table, blockquote")).some(function(node) {
      if (elementSubtreeHidden(node) || node.closest("nav, aside, footer, [role='navigation']")) return false;
      if (cardOwns(node)) return false;
      var text = normalizeText(node.textContent || "");
      return !!text && text !== normalizeText(metadata && metadata.excerpt || "");
    });
  }

  function homepageLeadButton(node) {
    return node.tagName === "BUTTON" || homepageLeadRole(node, "button");
  }

  function homepageLeadInterfaceOwner(node) {
    if (node.matches("header, nav, footer, aside, dialog, form")) return true;
    if (["navigation", "menu", "menubar", "toolbar", "dialog", "alertdialog"].some(function(role) {
      return homepageLeadRole(node, role);
    })) return true;
    if (normalizeText(node.getAttribute("aria-modal")).toLowerCase() === "true") return true;
    if (node.hasAttribute("aria-pressed")) return true;
    if (normalizeText(node.getAttribute("aria-controls"))) return true;
    return node.hasAttribute("aria-haspopup") && normalizeText(node.getAttribute("aria-haspopup")).toLowerCase() !== "false";
  }

  function homepageLeadUnavailableOwner(node) {
    return node.hasAttribute("inert") ||
      (node.tagName === "FIELDSET" && node.hasAttribute("disabled")) ||
      normalizeText(node.getAttribute("aria-disabled")).toLowerCase() === "true";
  }

  function homepageLeadRecordOwner(node, itemCards) {
    return itemCards.has(node) || node.matches(
      "article, li, tr, figure, dl, [role='article' i], [role='listitem' i], [role='complementary' i]"
    ) || Array.prototype.some.call(node.classList || [], function(className) {
      return /(?:^|[-_])(?:card|story|teaser|item|result|news|post|entry|record)(?:$|[-_])/i.test(className) ||
        /(?:Card|Story|Teaser|Item|Result|News|Record)(?:$|[A-Z])/.test(className);
    });
  }

  function homepageLeadInteractiveNode(node) {
    return homepageLeadButton(node) || node.matches(
      "a[href], input, select, textarea, audio[controls], video[controls], " +
      "[contenteditable]:not([contenteditable='false' i])"
    );
  }

  function homepageLeadDecorativeNodeInteractive(node) {
    if (homepageLeadInteractiveNode(node) || homepageLeadInterfaceOwner(node)) return true;
    var localName = String(node.localName || node.tagName).toLowerCase();
    var namespace = node.namespaceURI || "";
    if (namespace === "http://www.w3.org/1999/xhtml" && localName !== "img") return true;
    if (namespace && ["http://www.w3.org/1999/xhtml", "http://www.w3.org/2000/svg"].indexOf(namespace) === -1) {
      return true;
    }
    if (["a", "desc", "foreignobject", "script", "style", "text", "title"].indexOf(localName) !== -1) {
      return true;
    }
    if (node.matches(
      "summary, details, [tabindex], [autofocus], [usemap], [popover], [popovertarget], [commandfor], " +
      "[draggable='true' i]"
    )) return true;
    var roles = normalizeText(node.getAttribute("role") || "").toLowerCase().split(/\s+/).filter(Boolean);
    if (roles.some(function(role) { return ["img", "none", "presentation"].indexOf(role) === -1; })) return true;
    return Array.prototype.some.call(node.attributes || [], function(attribute) {
      return /^on/i.test(attribute.name);
    });
  }

  function homepageLeadDecorativeControl(node) {
    if (node.tagName === "BUTTON") return false;
    if (normalizeText(node.getAttribute("aria-label") || node.getAttribute("title") || "")) return false;
    return Array.prototype.every.call(node.childNodes, function(child) {
      if (child.nodeType === Node.TEXT_NODE) return !normalizeText(child.nodeValue || "");
      if (child.nodeType === Node.COMMENT_NODE) return true;
      if (child.nodeType !== Node.ELEMENT_NODE ||
          ["img", "svg"].indexOf(String(child.localName || child.tagName).toLowerCase()) === -1) return false;
      if (normalizeText(child.textContent || "") || homepageLeadDecorativeNodeInteractive(child)) return false;
      return !Array.prototype.some.call(child.querySelectorAll("*"), homepageLeadDecorativeNodeInteractive);
    });
  }

  function homepageLeadContextDescriptions(leadRoot) {
    if (!leadRoot || !leadRoot.root || !leadRoot.items || !leadRoot.items.length) return [];
    if (elementSubtreeHidden(leadRoot.root)) return [];

    var itemCards = new Set(leadRoot.items.map(function(item) { return item.card; }).filter(Boolean));
    var itemValues = new Set();
    leadRoot.items.forEach(function(item) {
      [item.text, item.detail, item.byline, item.publishedTime].forEach(function(value) {
        value = normalizeText(value);
        if (value) itemValues.add(value);
      });
    });
    var unsafeControls = new Set();
    var interactiveParagraphs = new Set();
    var nestedParagraphs = new Set();
    var contexts = [];
    var stack = [{
      node: leadRoot.root,
      control: null,
      interactiveOwner: null,
      paragraph: null,
      hidden: false,
      unavailable: false,
      interfaceOwned: false,
      recordOwned: itemCards.has(leadRoot.root)
    }];

    while (stack.length) {
      var state = stack.pop();
      var node = state.node;
      var hidden = state.hidden ||
        (node !== leadRoot.root && elementSubtreeHiddenWithin(node, composedDomParent(node))) ||
        listNodeWithinClosedDisclosure(node);
      var unavailable = state.unavailable || homepageLeadUnavailableOwner(node);
      var interfaceOwned = state.interfaceOwned || homepageLeadInterfaceOwner(node);
      var recordOwned = state.recordOwned || homepageLeadRecordOwner(node, itemCards);
      var control = homepageLeadButton(node);
      var interactive = homepageLeadInteractiveNode(node);

      if (state.interactiveOwner && interactive) {
        if (control) {
          unsafeControls.add(node);
          if (state.control && !homepageLeadDecorativeControl(node)) unsafeControls.add(state.control);
        } else if (state.control) {
          unsafeControls.add(state.control);
        }
      }
      if (state.paragraph && interactive) interactiveParagraphs.add(state.paragraph);
      if (state.paragraph && node.tagName === "P") {
        nestedParagraphs.add(state.paragraph);
        nestedParagraphs.add(node);
      }

      if (control) {
        contexts.push({
          kind: "control",
          node: node,
          hidden: hidden,
          unavailable: unavailable || node.disabled || node.hasAttribute("disabled"),
          interfaceOwned: interfaceOwned,
          recordOwned: recordOwned
        });
      } else if (node.tagName === "P" || /^H[2-6]$/.test(node.tagName)) {
        contexts.push({
          kind: node.tagName === "P" ? "paragraph" : "heading",
          node: node,
          hidden: hidden,
          unavailable: unavailable,
          interfaceOwned: interfaceOwned,
          recordOwned: recordOwned
        });
      }

      var nextControl = control ? node : state.control;
      var nextInteractiveOwner = interactive ? node : state.interactiveOwner;
      var nextParagraph = node.tagName === "P" ? node : state.paragraph;
      for (var index = node.children.length - 1; index >= 0; index -= 1) {
        stack.push({
          node: node.children[index],
          control: nextControl,
          interactiveOwner: nextInteractiveOwner,
          paragraph: nextParagraph,
          hidden: hidden,
          unavailable: unavailable,
          interfaceOwned: interfaceOwned,
          recordOwned: recordOwned
        });
      }
    }

    var descriptions = contexts.map(function(context) {
      if (context.hidden || context.unavailable || context.interfaceOwned || context.recordOwned) return null;
      if (context.kind === "control" && unsafeControls.has(context.node)) return null;
      if (context.kind === "paragraph" &&
          (interactiveParagraphs.has(context.node) || nestedParagraphs.has(context.node))) return null;

      var visible = leadVisibleClone(context.node, true);
      var text = normalizeText(visible && visible.textContent || "");
      if (context.kind === "control") {
        if (!meaningfulButtonText(text) || itemValues.has(text)) return null;
        itemValues.add(text);
      } else if (context.kind === "heading") {
        if (!text || context.node.closest("a[href], pre, code, kbd, samp, blockquote") ||
            visible.querySelector("a[href], button, input, select, textarea, form, nav, details")) return null;
        var headingMarkdown = markdownFor(visible.outerHTML).trim();
        return headingMarkdown ? { node: context.node, markdown: headingMarkdown } : null;
      } else {
        var words = text.split(/\s+/).filter(Boolean).length;
        if (text.length < 30 || text.length > 2000 || words < 4) return null;
        if (listNoiseText(text) || cookieNoticeText(text) || legalFooterText(text) || weatherModuleText(text)) return null;
      }
      return { node: context.node, markdown: text };
    }).filter(Boolean);
    var substantialParagraphs = 0;
    var paragraphChars = 0;
    descriptions.forEach(function(description) {
      if (description.node.tagName !== "P") return;
      var text = normalizeText(description.markdown);
      paragraphChars += text.length;
      if (text.length >= 80) substantialParagraphs += 1;
    });
    if (substantialParagraphs >= 3 && paragraphChars >= 1200) {
      return descriptions.filter(function(description) { return description.node.tagName !== "P"; });
    }
    return descriptions;
  }

  function homepageLeadContextRepresentsDescription(leadRoot, descriptions, description) {
    var text = normalizeText(description || "");
    if (!leadRoot || !leadRoot.root || !text) return false;
    var paragraphs = descriptions.filter(function(part) {
      return part.node && part.node.tagName === "P" && leadRoot.root.contains(part.node);
    });
    // A synopsis is another serialization of context, not another authored node.
    // Every physical paragraph remains in the source-ordered description list.
    return paragraphs.some(function(part) {
      return normalizeText(part.markdown) === text;
    }) || normalizeText(paragraphs.map(function(part) { return part.markdown; }).join("\n\n")) === text;
  }
