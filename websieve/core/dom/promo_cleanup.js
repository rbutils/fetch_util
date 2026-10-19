  var PROMO_ATTR_PATTERN = new RegExp("(?:^|[-_\\s])(" + NOISE_PROMO_ATTR_TERMS + ")(?:[-_\\s]|$)", "i");
  var PROMO_TEXT_PATTERN = new RegExp("\\b(" + NOISE_PROMO_TEXT_TERMS + ")\\b", "i");
  var PROMO_MEDIA_PATTERN = new RegExp("(?:\\/|[-_])(" + NOISE_PROMO_MEDIA_TERMS + ")(?:\\/|[-_.?]|$)", "i");

  function promoCtaOnlyMaterial(root, node, attrs, promoMedia, promoText) {
    if (promoMedia || promoText || PROMO_ATTR_PATTERN.test(attrs.replace(/(?:^|[-_\s])cta(?=[-_\s]|$)/gi, " "))) return false;
    if ((node.closest("article, [itemprop~='articleBody']") || docsAuthoredArticleNode(root, node)) &&
        node.querySelector("p, pre, code, ul, ol, dl, table, blockquote, figure")) return true;
    if (node.querySelector("a[href], button, [role='button'], form")) return false;
    return Array.prototype.some.call(node.querySelectorAll("h1, h2, h3, h4"), function(heading) {
      return !!normalizeText(heading.textContent || "");
    });
  }

  function stripPromoAdModules(root) {
    root.querySelectorAll("aside, section, div, figure, picture, p, span").forEach(function(el) {
      if (el.matches("main, article, [role='main']")) return;
      if (el.querySelector("article, main, [role='main']")) return;
      if (el.closest("[data-fetchutil-page-overview], [data-fetchutil-source-owned-primary]") &&
          el.querySelector("p, h1, h2, h3, h4, h5, h6, pre, [data-fetchutil-project-reference]")) return;

      var attrs = [
        el.className || "",
        el.id || "",
        el.getAttribute("data-testid") || "",
        el.getAttribute("data-test") || "",
        el.getAttribute("aria-label") || ""
      ].join(" ").toLowerCase();
      var promoAttrs = PROMO_ATTR_PATTERN.test(attrs);
      if (el.matches("p, span") && !promoAttrs) return;
      var imageSrcs = Array.prototype.map.call(el.querySelectorAll("img, source"), function(img) {
        return (img.getAttribute("src") || img.getAttribute("srcset") || "").toLowerCase();
      }).join(" ");

      var promoMedia = PROMO_MEDIA_PATTERN.test(imageSrcs);
      // Neither removal branch can act without attribute or media evidence.
      // Ordinary sections need no whole-subtree text or paragraph visibility
      // assessment, even when their authored prose discusses subscriptions.
      if (!promoAttrs && !promoMedia) return;
      var text = normalizeText(el.textContent || "");
      var promoText = PROMO_TEXT_PATTERN.test(text.toLowerCase());
      if (el.matches("p, span") && !promoText) return;

      if (promoAttrs && !promoText && !promoMedia) {
        var editorialParagraphs = Array.prototype.filter.call(el.querySelectorAll("p"), function(paragraph) {
          return !elementVisuallyHidden(paragraph) && normalizeText(paragraph.textContent || "").length >= 80 &&
            !paragraph.closest("nav, aside, footer, [role~='navigation' i], [role~='complementary' i]");
        });
        var editorialText = editorialParagraphs.reduce(function(total, paragraph) {
          return total + normalizeText(paragraph.textContent || "").length;
        }, 0);
        if (editorialParagraphs.length >= 2 && editorialText >= 280) return;
      }

      // A CTA marker alone cannot identify article-owned material as promotion.
      if (promoAttrs && promoCtaOnlyMaterial(root, el, attrs, promoMedia, promoText)) return;
      if ((promoAttrs || promoMedia) && (text.length < 900 || promoText)) {
        el.remove();
      } else if (promoText && promoMedia && text.length < 1200) {
        el.remove();
      }
    });
  }
