  function physicalIndexedPlayContext(metadata) {
    var family = /\b(?:entire|complete)\s+(?:play|drama)\b/i;
    if (!family.test(document.title || "")) return null;
    var pageUrl = focalCanonicalUrl(location.href);
    var canonical = document.querySelector("link[rel~='canonical' i]");
    var ogUrl = document.querySelector("meta[property='og:url' i]");
    var declaredUrl = canonical ? canonical.getAttribute("href") : ogUrl && ogUrl.getAttribute("content");
    if (declaredUrl && focalCanonicalUrl(declaredUrl) !== pageUrl) return null;
    var ogType = document.querySelector("meta[property='og:type' i]");
    if (ogType && /article|blogposting/i.test(ogType.getAttribute("content") || "")) return null;
    if (structuredDataNodes().some(function(node) {
      return nodeTypes(node).some(function(type) { return /^(?:NewsArticle|ReportageNewsArticle|BlogPosting|Article)$/.test(type); });
    })) return null;
    var roots = document.querySelectorAll("main, [role='main']");
    if (roots.length !== 1) return null;
    var root = roots[0];
    var headings = root.querySelectorAll("h1");
    if (headings.length !== 1) return null;
    var heading = headings[0];
    var title = cleanDocsHeadingText(heading.textContent);
    if (!family.test(title)) return null;
    var titles = [document.title, metadata && metadata.title].concat(Array.from(
      document.querySelectorAll("meta[property='og:title' i]"), function(node) { return node.getAttribute("content"); }
    )).map(function(value) { return normalizeText(value || ""); }).filter(Boolean);
    if (!titles.length || !titles.every(function(value) {
      return value === title || (value.indexOf(title) === 0 && /^(?:-|\||\u2013|\u2014)\s+\S/.test(normalizeText(value.slice(title.length))));
    })) return null;
    if (root.querySelector("[itemprop~='author' i], [rel~='author' i], [itemprop~='datePublished' i]")) return null;
    var textRoots = Array.from(root.querySelectorAll("div, section, article")).filter(function(node) {
      return node.getAttributeNames().some(function(name) {
        return /^xmlns(?::[a-z]+)?$/i.test(name) && node.getAttribute(name) === "http://www.w3.org/1999/xhtml";
      });
    });
    if (textRoots.length !== 1) return null;
    var textRoot = textRoots[0];
    var chrome = "nav, aside, footer, form, menu, [role~='navigation' i], [role~='menu' i], [role~='complementary' i]";
    if (elementSubtreeHidden(root) || elementSubtreeHidden(heading) || elementSubtreeHidden(textRoot) ||
        textRoot.closest(chrome)) return null;
    var indexed = Array.from(textRoot.querySelectorAll("[id]")).map(function(node) {
      var match = (node.id || "").match(/^line-([1-9]\d*)\.([1-9]\d*)\.(\d+)$/);
      return match ? { node: node, act: Number(match[1]), scene: Number(match[2]), line: Number(match[3]) } : null;
    }).filter(Boolean);
    if (new Set(indexed.map(function(entry) { return entry.node.id; })).size !== indexed.length) return null;
    var scenes = indexed.filter(function(entry) { return entry.line === 0; });
    if (scenes.length < 2 || scenes[scenes.length - 1].act < 2) return null;
    var sceneOwners = new Map();
    for (var i = 0; i < scenes.length; i += 1) {
      var scene = scenes[i];
      var previous = scenes[i - 1];
      if ((!previous && (scene.act !== 1 || scene.scene !== 1)) || (previous &&
          !((scene.act === previous.act && scene.scene === previous.scene + 1) ||
            (scene.act === previous.act + 1 && scene.scene === 1)))) return null;
      if (elementSubtreeHidden(scene.node) || scene.node.closest(chrome)) return null;
      function formalLabel(node) {
        return normalizeText(node.textContent || "").replace(/^[\u27e8\u27e9\u231c\u231d\s]+|[\u27e8\u27e9\u231c\u231d\s]+$/g, "");
      }
      if (!Array.from(scene.node.children).some(function(node) {
        return formalLabel(node).toLowerCase() === "scene " + scene.scene;
      }) || !scene.node.parentElement || !Array.from(scene.node.parentElement.children).some(function(node) {
        return formalLabel(node).toLowerCase() === "act " + scene.act;
      })) return null;
      sceneOwners.set(scene.act + "." + scene.scene, { node: scene.node, lines: 0 });
    }
    if (!indexed.every(function(entry) {
      if (entry.line === 0) return true;
      var owner = sceneOwners.get(entry.act + "." + entry.scene);
      if (!owner || !owner.node.contains(entry.node) || elementSubtreeHidden(entry.node)) return false;
      owner.lines += 1;
      return true;
    }) || !Array.from(sceneOwners.values()).every(function(owner) { return owner.lines > 0; })) return null;
    return { root: root, textRoot: textRoot, title: title };
  }

  function physicalIndexedPlayReferenceRoots(context) {
    var workName = normalizeText(context.title.replace(/\s*[-:|\u2013\u2014]?\s*(?:entire|complete)\s+(?:play|drama)\s*$/i, "")).toLowerCase();
    if (!workName) return [];
    return Array.from(context.root.children).filter(function(node) {
      if (node.contains(context.textRoot) || node.matches("nav, aside, footer, form, [role~='navigation' i], [role~='complementary' i]")) return false;
      var headings = node.querySelectorAll("h2, h3, h4");
      if (headings.length !== 1 || normalizeText(headings[0].textContent).toLowerCase().indexOf(workName) < 0) return false;
      if (!node.querySelector("img[src]") || node.querySelector("form, button, input, select, textarea, [role='button']")) return false;
      var links = Array.from(node.querySelectorAll("a[href]"));
      return links.length > 0 && links.every(function(link) {
        return normalizeText(link.textContent || "") && !!materializedHttpUrl(link.href);
      });
    });
  }

  function physicalIndexedPlayContent(metadata) {
    var context = physicalIndexedPlayContext(metadata);
    if (!context) return null;
    var content = docsContentForNode(metadata, context.root, {
      title: context.title, hostAware: false, focusFragment: false,
      pruneSourceVisibility: true, preserveAuthoredSections: true, preserveCleanedRoot: true,
      preserveSourceMaterialRoot: context.textRoot,
      preserveSourceReferenceRoots: physicalIndexedPlayReferenceRoots(context)
    });
    if (content) {
      content.sourceOwnedIndexedPlay = true;
      content.docsLike = false;
      content.byline = null;
      content.publishedTime = null;
    }
    return content;
  }

  function physicalOwnedReferenceContent(metadata) {
    return physicalReferenceContent(metadata) || physicalIndexedPlayContent(metadata);
  }
