  function readabilityLeadResourceSection(root, sourceClones) {
    var headings = [];
    var excluded = "nav, footer, aside, form, button, [role='navigation'], [role='banner'], " +
      "[role='complementary'], [role='dialog'], [role='toolbar'], [role='menu']";
    sourceClones.forEach(function(clone, source) {
      if (source.localName === "h1" && root.contains(clone) && !source.closest(excluded) &&
          !elementSubtreeHidden(source) && normalizeText(clone.textContent)) headings.push(source);
    });
    if (headings.length !== 1) return null;
    var heading = headings[0];
    var owner = heading.closest("main, article, [role='main'], [itemprop~='articleBody']");
    var section = heading.closest("section");
    if (!owner || !section || !owner.contains(section) || section.closest(excluded)) return null;
    var sectionClone = sourceClones.get(section);
    if (!sectionClone || !root.contains(sectionClone)) return null;
    var hasProse = Array.from(section.querySelectorAll("p")).some(function(paragraph) {
      var clone = sourceClones.get(paragraph);
      return clone && sectionClone.contains(clone) && !paragraph.closest(excluded) &&
        !elementSubtreeHidden(paragraph) && !!normalizeText(clone.textContent);
    });
    return hasProse ? section : null;
  }

  function readabilityMappedLeadResources(source, clone, sourceClones) {
    var excluded = "p, h1, h2, h3, h4, h5, h6, ul, ol, dl, table, pre, code, kbd, samp, section, article, " +
      "nav, header, footer, aside, form, button, input, select, textarea, [role='button'], " +
      "iframe, object, embed, video, audio, canvas";
    if (clone.querySelector(excluded)) return false;
    var sourceLinks = Array.from(source.querySelectorAll("a[href]")).filter(function(node) { return !elementSubtreeHidden(node); });
    var sourceImages = Array.from(source.querySelectorAll("img")).filter(function(node) { return !elementSubtreeHidden(node); });
    var links = Array.from(clone.querySelectorAll("a[href]"));
    var images = Array.from(clone.querySelectorAll("img"));
    if (!links.length && !images.length) return false;
    if (links.length !== sourceLinks.length || images.length !== sourceImages.length) return false;
    function mappedUrl(sourceNode, clonedNode, attribute) {
      if (sourceClones.get(sourceNode) !== clonedNode) return false;
      var sourceValue = (sourceNode.getAttribute(attribute) || "").trim();
      var cloneValue = (clonedNode.getAttribute(attribute) || "").trim();
      if (!sourceValue || !cloneValue || (attribute === "href" && sourceValue.charAt(0) === "#")) return false;
      try {
        var sourceUrl = new URL(sourceValue, location.href);
        var cloneUrl = new URL(cloneValue, location.href);
        return /^https?:$/.test(sourceUrl.protocol) && sourceUrl.href === cloneUrl.href;
      } catch (_error) { return false; }
    }
    if (!links.every(function(link, index) { return mappedUrl(sourceLinks[index], link, "href"); })) return false;
    if (!images.every(function(image, index) {
      return mappedUrl(sourceImages[index], image, "src") &&
        sourceImages[index].getAttribute("alt") === image.getAttribute("alt");
    })) return false;
    var outside = clone.cloneNode(true);
    outside.querySelectorAll("a, img, picture, svg").forEach(function(node) { node.remove(); });
    return !normalizeText(outside.textContent);
  }

  function readabilityOwnedResourceSections(root, sourceClones) {
    var lead = readabilityLeadResourceSection(root, sourceClones);
    if (!lead) return [];
    var owner = lead.closest("main, article, [role='main'], [itemprop~='articleBody']");
    var sections = [lead];
    var excluded = "nav, footer, aside, form, button, details:not([open]), [role='navigation'], " +
      "[role='complementary'], [role='dialog'], [role='toolbar'], [role='menu']";
    owner.querySelectorAll("section").forEach(function(section) {
      var clone = sourceClones.get(section);
      if (section === lead || !clone || !root.contains(clone) || section.closest(excluded) ||
          elementSubtreeHidden(section) ||
          section.closest("main, article, [role='main'], [itemprop~='articleBody']") !== owner) return;
      function ownsVisible(node) {
        var mapped = sourceClones.get(node);
        return node.closest("section") === section && mapped && clone.contains(mapped) &&
          !node.closest(excluded) && !elementSubtreeHidden(node) && !!normalizeText(mapped.textContent);
      }
      var heading = Array.from(section.querySelectorAll("h2, h3, h4, h5, h6")).some(ownsVisible);
      var prose = Array.from(section.querySelectorAll("p")).some(ownsVisible);
      if (heading && prose) sections.push(section);
    });
    return sections;
  }

  function preserveReadabilityOwnedLeadResources(reader, root, sourceClones, marker) {
    if (!reader || !root || !sourceClones || !marker) return;
    var sections = readabilityOwnedResourceSections(root, sourceClones);
    if (!sections.length) return;
    var attribute = "data-fetchutil-reader-source-resource";
    var blocks = new WeakSet();
    var snapshots = new Map();
    var originals = [];
    var excluded = "nav, footer, aside, form, button, pre, code, details:not([open]), " +
      "[role='navigation'], [role='complementary'], [role='dialog'], [role='toolbar'], [role='menu']";
    sourceClones.forEach(function(clone, source) {
      if (source.localName !== "div" || clone.localName !== "div" || !root.contains(clone) ||
          !sections.some(function(section) { return section.contains(source); })) return;
      if (source.closest(excluded) || elementSubtreeHidden(source) || clone.hasAttribute(attribute)) return;
      if (!readabilityMappedLeadResources(source, clone, sourceClones)) return;
      var identity = marker + ":" + originals.length;
      clone.setAttribute(attribute, identity);
      blocks.add(clone);
      originals.push(clone);
      snapshots.set(identity, clone.outerHTML);
    });
    if (!originals.length) return;
    protectReadabilitySourceBlocks(reader, blocks, function(conditionalRoot) {
      var documentRoot = conditionalRoot.getRootNode();
      originals.forEach(function(node) {
        if (documentRoot.contains(node)) snapshots.set(node.getAttribute(attribute), node.outerHTML);
      });
      var counts = new Map();
      documentRoot.querySelectorAll("div[" + attribute + "]").forEach(function(node) {
        var identity = node.getAttribute(attribute);
        if (snapshots.has(identity)) counts.set(identity, (counts.get(identity) || 0) + 1);
      });
      return { has: function(node) {
        if (blocks.has(node)) return true;
        var identity = node.getAttribute(attribute);
        return node.localName === "div" && counts.get(identity) === 1 && snapshots.get(identity) === node.outerHTML;
      } };
    });
  }

  function stripReadabilityLeadResourceMarkers(html, marker) {
    var template = document.createElement("template");
    template.innerHTML = html;
    var attribute = "data-fetchutil-reader-source-resource";
    template.content.querySelectorAll("[" + attribute + "]").forEach(function(node) {
      if (node.getAttribute(attribute).indexOf(marker + ":") === 0) node.removeAttribute(attribute);
    });
    return template.innerHTML;
  }
