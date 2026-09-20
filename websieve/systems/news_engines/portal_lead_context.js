  function homepageLeadRole(node, role) {
    return normalizeText(node.getAttribute("role") || "").toLowerCase().split(/\s+/).indexOf(role) !== -1;
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
        (node !== leadRoot.root && elementSubtreeHiddenWithin(node, composedDomParent(node)));
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
      } else if (node.tagName === "P") {
        contexts.push({
          kind: "paragraph",
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
      } else {
        var words = text.split(/\s+/).filter(Boolean).length;
        if (text.length < 30 || text.length > 2000 || words < 4 || itemValues.has(text)) return null;
        if (listNoiseText(text) || cookieNoticeText(text) || legalFooterText(text) || weatherModuleText(text)) return null;
      }
      itemValues.add(text);
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
