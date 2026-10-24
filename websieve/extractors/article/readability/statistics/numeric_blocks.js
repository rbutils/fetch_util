  function readabilityNumericStatisticBlock(node) {
    if (node.localName !== "div" || !node.closest("article, main, [role='main'], [itemprop~='articleBody']")) return false;
    var excludedOwner = "nav, header, footer, aside, form, button, pre, code, kbd, samp, " +
      "[aria-controls], [role='navigation'], [role='complementary'], [role='dialog'], " +
      "[role='toolbar'], [role='menu'], [role='button'], [role='slider'], [role='progressbar']";
    if (node.closest(excludedOwner)) return false;
    if (node.querySelector("a[href], h1, h2, h3, h4, h5, h6, ul, ol, dl, table, blockquote, " +
        "pre, code, kbd, samp, button, input, select, textarea, video, audio, iframe, object, embed, " +
        "script, style, noscript, template, [aria-controls], [role='button'], [role='slider']")) return false;

    var numericValue = /^\d+(?::\d+)+$/;
    if (numericValue.test(normalizeText(node.textContent))) return true;
    var children = Array.from(node.children);
    if (children.length !== 2 || Array.from(node.childNodes).some(function(child) {
      return child.nodeType === Node.TEXT_NODE && !!normalizeText(child.textContent);
    })) return false;
    var values = children.filter(function(child) {
      return numericValue.test(normalizeText(child.textContent));
    });
    if (values.length !== 1) return false;
    var label = children.find(function(child) { return child !== values[0]; });
    return /\p{L}/u.test(normalizeText(label.textContent));
  }

  function preserveReadabilityNumericStatistics(reader) {
    protectReadabilitySourceBlocks(reader, { has: readabilityNumericStatisticBlock });
  }
