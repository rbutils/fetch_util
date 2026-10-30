  function readabilityHeadingCardFingerprint(link) {
    if (!link || link.localName !== "a") return null;
    var headings = Array.from(link.querySelectorAll("h2, h3, h4, h5, h6"));
    if (headings.length !== 1 || headings[0].closest("a") !== link) return null;
    var text = normalizeText(headings[0].textContent);
    var destination = materializedHttpUrl(link.getAttribute("href"));
    return text && destination && normalizeText(link.textContent) === text ?
      JSON.stringify([headings[0].localName, text, destination]) : null;
  }

  function readabilityLinkedHeadingIdentityNodes(root, attribute) {
    var nodes = Array.from(root.querySelectorAll("[" + attribute + "]"));
    if (root.nodeType === Node.ELEMENT_NODE && root.hasAttribute(attribute)) nodes.unshift(root);
    return nodes;
  }

  function readabilityLinkedHeadingIdentityCounts(root, context) {
    function counts(attribute) {
      var result = new Map();
      readabilityLinkedHeadingIdentityNodes(root, attribute).forEach(function(node) {
        var key = node.getAttribute(attribute);
        result.set(key, (result.get(key) || 0) + 1);
      });
      return result;
    }
    return { groups: counts(context.attribute), cards: counts(context.cardAttribute) };
  }

  function readabilityHeadingParagraphFingerprint(paragraph) {
    var clone = paragraph.cloneNode(true);
    [clone].concat(Array.from(clone.querySelectorAll("*"))).forEach(function(node) {
      node.removeAttribute("class");
      node.removeAttribute("style");
      if (node.localName === "a" && node.hasAttribute("href")) {
        var destination = materializedHttpUrl(node.getAttribute("href"));
        if (destination) node.setAttribute("href", destination);
      }
    });
    return clone.outerHTML;
  }

  function readabilityHeadingRegionUnits(node, context, counts) {
    if (node.localName === "a") {
      return readabilityRetainedHeadingCard(node, context, counts) ?
        [["card", node.getAttribute(context.cardAttribute)]] : null;
    }
    if (node.localName === "p") return [["paragraph", readabilityHeadingParagraphFingerprint(node)]];
    if (node.localName !== "div" || Array.from(node.childNodes).some(function(child) {
      return child.nodeType === Node.TEXT_NODE && !!normalizeText(child.nodeValue);
    })) return null;
    var units = [];
    var complete = Array.from(node.children).every(function(child) {
      var nested = readabilityHeadingRegionUnits(child, context, counts);
      if (!nested) return false;
      units = units.concat(nested);
      return true;
    });
    return complete ? units : null;
  }

  function readabilityLinkedHeadingSnapshots(root, selected, blocks, links, cards) {
    var attribute = "data-fetchutil-reader-heading-cards";
    while (root.querySelector("[" + attribute + "], [" + attribute + "-card]")) attribute += "-owned";
    var context = { attribute: attribute, cardAttribute: attribute + "-card", groups: new Map(),
      cards: new Map(), blocks: blocks, links: links };
    var snapshots = selected.map(function(group) { return group.clone.outerHTML; });
    cards.forEach(function(card) {
      var identity = String(context.cards.size);
      context.cards.set(identity, readabilityHeadingCardFingerprint(card));
      card.setAttribute(context.cardAttribute, identity);
    });
    var counts = readabilityLinkedHeadingIdentityCounts(root, context);
    selected.forEach(function(group, index) {
      var key = String(context.groups.size);
      var snapshot = { html: snapshots[index], units: JSON.stringify(readabilityHeadingRegionUnits(group.clone, context, counts)) };
      context.groups.set(key, snapshot);
      group.clone.setAttribute(context.attribute, key);
    });
    return context;
  }

  function readabilityRetainedHeadingCard(node, context, counts) {
    if (!node || node.localName !== "a") return false;
    var identity = node.getAttribute(context.cardAttribute);
    if (!context.cards.has(identity) || readabilityHeadingCardFingerprint(node) !== context.cards.get(identity)) return false;
    var actual = counts || readabilityLinkedHeadingIdentityCounts(node.getRootNode(), context);
    return actual.cards.get(identity) === 1;
  }

  function readabilityRetainedHeadingGroup(node, context, counts) {
    if (!node || node.localName !== "div") return false;
    var identity = node.getAttribute(context.attribute);
    var snapshot = context.groups.get(identity);
    if (!snapshot || counts.groups.get(identity) !== 1) return false;
    var units = readabilityHeadingRegionUnits(node, context, counts);
    return !!units && JSON.stringify(units) === snapshot.units;
  }

  function readabilityReparsedLinkedHeadingBlocks(root, context) {
    var counts = readabilityLinkedHeadingIdentityCounts(root.getRootNode(), context);
    var retained = new WeakSet();
    readabilityLinkedHeadingIdentityNodes(root, context.attribute).forEach(function(node) {
      if (!readabilityRetainedHeadingGroup(node, context, counts)) return;
      retained.add(node);
      node.querySelectorAll("div").forEach(function(part) { retained.add(part); });
    });
    return { has: function(node) {
      if (context.blocks.has(node) || retained.has(node)) return true;
      var card = node.localName === "div" && node.closest("a[" + context.cardAttribute + "]");
      return !!card && readabilityRetainedHeadingCard(card, context, counts);
    } };
  }

  function restoreReadabilityLinkedHeadingCards(html, context) {
    if (!context) return html;
    var template = document.createElement("template");
    template.innerHTML = html;
    var counts = readabilityLinkedHeadingIdentityCounts(template.content, context);
    readabilityLinkedHeadingIdentityNodes(template.content, context.attribute).forEach(function(node) {
      if (!readabilityRetainedHeadingGroup(node, context, counts)) return;
      var original = document.createElement("template");
      original.innerHTML = context.groups.get(node.getAttribute(context.attribute)).html;
      node.replaceWith(original.content);
    });
    template.content.querySelectorAll("[" + context.attribute + "], [" + context.cardAttribute + "]").forEach(function(node) {
      node.removeAttribute(context.attribute);
      node.removeAttribute(context.cardAttribute);
    });
    return template.innerHTML;
  }
