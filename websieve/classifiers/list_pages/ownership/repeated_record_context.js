  function pageOwnedOverviewSection(node) {
    var identity = [node.className || "", node.id || "", node.getAttribute("aria-label") || "",
      node.getAttribute("itemprop") || "", node.getAttribute("data-section") || "", node.getAttribute("data-type") || ""].join(" ");
    if (!/(?:^|[\s_-])(?:about|overview|intro(?:duction)?|chi[-_ ]?siamo)(?:$|[\s_-])/i.test(identity)) return false;
    if (!node.matches("section, div") || node.closest("article, header, footer, nav, aside, [role='navigation'], [role='complementary']") ||
        listChromeNode(node) || listNoiseNode(node) || listExplicitAdvertisementOwner(node) ||
        /(?:^|[\s_-])(?:sidebar|rail|related|recommendations?|support(?:ing)?|promotions?|sponsors?|advert(?:ising)?|widgets?|navigation|toolbar)(?:$|[\s_-])/i.test(identity) ||
        node.querySelector("a[href], article, header, footer, nav, aside, form, button, input, select, textarea, ul, ol, table, [role='list'], [role='navigation'], [role='complementary'], [class*='card' i], [class*='story' i], [class*='news' i], [class*='item' i]")) return false;
    var headings = Array.prototype.filter.call(node.querySelectorAll("h2, h3, h4"), function(heading) {
      return !elementSubtreeHidden(heading) && !heading.closest("a[href]");
    });
    var paragraphs = Array.prototype.filter.call(node.querySelectorAll("p"), function(paragraph) {
      return !elementSubtreeHidden(paragraph) && normalizeText(paragraph.textContent || "").length >= 80;
    });
    return headings.length === 1 && paragraphs.length > 0;
  }

  function pageOwnedHeadingIntro(parent, branch, content) {
    var children = Array.prototype.slice.call(parent.children);
    var ownerIndex = children.indexOf(branch);
    var pageTitles = [normalizeText(content && content.title || ""), normalizeText(document.title || "")].filter(Boolean);
    var headings = children.filter(function(child) {
      return child.matches("h1") && !elementSubtreeHidden(child) && !child.querySelector("a[href]") &&
        pageTitles.indexOf(normalizeText(child.textContent || "")) !== -1;
    });
    if (headings.length !== 1) return [];
    var headingIndex = children.indexOf(headings[0]);
    if (headingIndex >= ownerIndex) return [];
    var introNodes = [headings[0]];
    var paragraphCharacters = 0;
    for (var index = headingIndex + 1; index < ownerIndex; index += 1) {
      var sibling = children[index];
      if (!sibling.matches("p") || elementSubtreeHidden(sibling) || sibling.querySelector("a[href]")) return [];
      var text = normalizeText(sibling.textContent || "");
      if (!text) continue;
      paragraphCharacters += text.length;
      introNodes.push(sibling);
    }
    return introNodes.length > 1 && paragraphCharacters >= 80 ? introNodes : [];
  }

  function pageOwnedRenderContext(owner, content) {
    var branch = owner;
    var parent = branch.parentElement;
    while (parent && !parent.matches("html, main, [role='main']") &&
        !parent.closest("article, nav, header, footer, aside, [role='navigation'], [role='complementary']")) {
      var overviewNodes = Array.prototype.filter.call(parent.children, function(child) {
        return child !== branch && !elementSubtreeHidden(child) && pageOwnedOverviewSection(child);
      });
      var headingIntroNodes = pageOwnedHeadingIntro(parent, branch, content);
      var contextNodes = overviewNodes.concat(headingIntroNodes);
      if (contextNodes.length) {
        return {
          owner: parent,
          nodes: Array.prototype.filter.call(parent.children, function(child) {
            return child === branch || contextNodes.indexOf(child) !== -1;
          })
        };
      }
      if (parent.children.length !== 1 || parent.firstElementChild !== branch) break;
      branch = parent;
      parent = parent.parentElement;
    }
    return null;
  }
