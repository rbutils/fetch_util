  function transparentMarkdownBlock(node) {
    return node.nodeType === 1 && node.namespaceURI === "http://www.w3.org/1999/xhtml" &&
      /^(?:ARTICLE|SECTION|DIV)$/.test(node.nodeName) &&
      !node.hasAttribute("data-fetch-util-structured-card-field") &&
      !(node.nodeName === "DIV" && paragraphLikeDiv(node));
  }

  function independentMarkdownBlock(node) {
    // A conservative subset of Turndown's block elements. Other elements remain
    // in complete inline runs, including any unknown or namespace-owned syntax.
    return node.nodeType === 1 && node.namespaceURI === "http://www.w3.org/1999/xhtml" &&
      /^(?:P|H[1-6]|PRE|UL|OL|DL|TABLE|BLOCKQUOTE|HR|FIGURE)$/.test(node.nodeName);
  }

  function turndownBlockUnits(service, root) {
    // Reference-style links and append hooks can require whole-document state.
    // This converter is for the configured inline-link extraction service only.
    if (service.options.linkStyle !== "inlined") return service.turndown(root);
    var parts = [];
    var owner = root.ownerDocument;
    var stack = [{ node: root, child: root.firstChild, inline: owner.createDocumentFragment() }];

    function flush(fragment) {
      if (!fragment.firstChild) return;
      var markdown = typeof service.turndownOwnedRoot === "function" ?
        service.turndownOwnedRoot(fragment) : service.turndown(fragment);
      if (markdown) parts.push(markdown);
      fragment.replaceChildren();
    }

    while (stack.length) {
      var frame = stack[stack.length - 1];
      if (!frame.child) {
        flush(frame.inline);
        if (frame.node !== root) frame.node.remove();
        stack.pop();
        continue;
      }
      var child = frame.child;
      frame.child = child.nextSibling;
      if (transparentMarkdownBlock(child)) {
        flush(frame.inline);
        stack.push({ node: child, child: child.firstChild, inline: owner.createDocumentFragment() });
      } else if (independentMarkdownBlock(child)) {
        flush(frame.inline);
        var block = owner.createDocumentFragment();
        block.appendChild(child);
        flush(block);
      } else {
        frame.inline.appendChild(child);
      }
    }
    return parts.join("\n\n");
  }
