function(initialIds) {
  function visible(node) {
    if (!node || node.closest("[hidden], [aria-hidden='true'], nav, dialog, [role='dialog']")) return false;
    var style = getComputedStyle(node);
    return style.display !== "none" && style.visibility !== "hidden" && node.getBoundingClientRect().height > 0;
  }
  function author(article) {
    return Array.from(article.querySelectorAll("[rel~='author'], [itemprop~='author'], [data-author], .author, .username, [class$='-author'], [class$='__author'], [class$='-username'], [class$='__username']")).some(function(node) {
      return visible(node) && node.closest("article") === article &&
        !node.closest("blockquote, pre, code, [role='button']") && (node.textContent || node.getAttribute("data-author") || "").trim();
    });
  }
  function loaded(slot) {
    var article = slot && slot.querySelector("article");
    return !!(article && visible(article) && author(article) &&
      article.querySelector("h2 a[href], h3 a[href], a[href] h2, a[href] h3"));
  }
  function status(ids) {
    var slots = ids.map(function(id) { return document.getElementById(id); });
    var bottom = slots.reduce(function(maximum, slot) {
      return visible(slot) ? Math.max(maximum, slot.getBoundingClientRect().bottom + scrollY) : maximum;
    }, 0);
    return { ids: ids, remaining: ids.filter(function(_, index) { return !loaded(slots[index]); }),
      targetHeight: Math.ceil(bottom + 1), width: innerWidth, height: innerHeight, scale: devicePixelRatio };
  }
  if (initialIds) return status(initialIds);
  var mains = Array.from(document.querySelectorAll("main, [role='main']")).filter(function(main) {
    return visible(main) && !(main.parentElement && main.parentElement.closest("main, [role='main']"));
  });
  if (mains.length !== 1) return null;
  var main = mains[0];
  if (Array.from(main.querySelectorAll("article h1, [itemprop='articleBody'] h1")).some(visible) || main.querySelector("input[type='password']")) return null;
  var roots = Array.from(main.querySelectorAll("article")).map(function(article) {
    if (!visible(article) || article.querySelector("article") || article.closest("blockquote, pre, code, aside, form") ||
        !author(article) || !article.querySelector("time[datetime]") ||
        !article.querySelector("h2 a[href], h3 a[href], a[href] h2, a[href] h3")) return null;
    var owner = article;
    var identified = article.id ? article : null;
    while (owner.parentElement && owner.parentElement !== main && owner.parentElement.querySelectorAll("article").length === 1) {
      owner = owner.parentElement;
      if (owner.id) identified = owner;
    }
    if (!identified || !Array.from(identified.querySelectorAll("[data-score], [itemprop='upvoteCount'], [class*='vote' i], [class*='score' i]")).some(function(node) {
      return visible(node) && !node.closest("blockquote, pre, code") &&
        /^[+−-]?\d+$/.test((node.getAttribute("data-score") || node.textContent || "").trim());
    })) return null;
    return identified;
  }).filter(Boolean);
  if (roots.length < 3) return null;
  var collections = Array.from(new Set(roots.map(function(root) { return root.parentElement; })));
  if (collections.length !== 1) return null;
  var collection = collections[0];
  if (Array.from(main.querySelectorAll("p, blockquote, pre, table")).some(function(node) {
    return visible(node) && node.textContent.trim() && !collection.contains(node) &&
      !node.closest("header, nav, aside, form, dialog, [role='dialog'], footer");
  })) return null;
  var template = roots[0];
  var signature = Array.from(template.classList).sort().join(" ");
  var slots = Array.from(collection.children).filter(function(node) {
    return node.localName === template.localName && Array.from(node.classList).sort().join(" ") === signature && visible(node);
  });
  if (!roots.every(function(root) { return slots.includes(root); }) || !slots.some(function(slot) { return !loaded(slot); })) return null;
  var ids = slots.map(function(slot) { return slot.id; });
  if (ids.some(function(id) { return !id || document.querySelectorAll("[id='" + CSS.escape(id) + "']").length !== 1; }) ||
      new Set(ids).size !== ids.length) return null;
  return status(ids);
}
