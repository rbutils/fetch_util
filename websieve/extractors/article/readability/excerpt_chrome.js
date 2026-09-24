  function readabilityBreadcrumbExcerpt(excerpt) {
    return Array.prototype.some.call(document.querySelectorAll(
      "[class~='breadcrumb' i], [class~='breadcrumbs' i], [aria-label*='breadcrumb' i]"
    ), function(node) {
      return !elementSubtreeHidden(node) && normalizeText(node.textContent || "") === excerpt;
    });
  }

  function readabilityPublicationLabelExcerpt(excerpt) {
    var value = normalizeText(excerpt || "");
    if (readabilityExcerptLength(value) > 80 ||
        !/^(?:published|updated|last updated|publication date|giriş tarihi|yayın tarihi|fecha de publicación|date de publication|veröffentlicht)\s*[:：-]/i.test(value)) return false;
    return Array.prototype.some.call(document.querySelectorAll("time, p, div, span"), function(node) {
      return !elementSubtreeHidden(node) && normalizeText(node.textContent || "") === value &&
        !node.closest("nav, header, footer, aside, form, [role='navigation'], [role='complementary']");
    });
  }
