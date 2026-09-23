  var PROMO_ATTR_PATTERN = new RegExp("(?:^|[-_\\s])(" + NOISE_PROMO_ATTR_TERMS + ")(?:[-_\\s]|$)", "i");
  var PROMO_TEXT_PATTERN = new RegExp("\\b(" + NOISE_PROMO_TEXT_TERMS + ")\\b", "i");
  var PROMO_MEDIA_PATTERN = new RegExp("(?:\\/|[-_])(" + NOISE_PROMO_MEDIA_TERMS + ")(?:\\/|[-_.?]|$)", "i");

  function promoCtaOnlyHeading(node, attrs, promoMedia, promoText) {
    if (promoMedia || promoText || PROMO_ATTR_PATTERN.test(attrs.replace(/(?:^|[-_\s])cta(?=[-_\s]|$)/gi, " "))) return false;
    if (node.querySelector("a[href], button, [role='button'], form")) return false;
    return Array.prototype.some.call(node.querySelectorAll("h1, h2, h3, h4"), function(heading) {
      return !!normalizeText(heading.textContent || "");
    });
  }

  function stripPromoAdModules(root) {
    root.querySelectorAll("aside, section, div, figure, picture").forEach(function(el) {
      if (el.matches("main, article, [role='main']")) return;
      if (el.querySelector("article, main, [role='main']")) return;
      if (el.closest("[data-fetchutil-page-overview]") && el.querySelector("p, h1, h2, h3, h4, h5, h6, pre, [data-fetchutil-project-reference]")) return;

      var text = normalizeText(el.textContent || "");
      var textLower = text.toLowerCase();
      var attrs = [
        el.className || "",
        el.id || "",
        el.getAttribute("data-testid") || "",
        el.getAttribute("data-test") || "",
        el.getAttribute("aria-label") || ""
      ].join(" ").toLowerCase();
      var imageSrcs = Array.prototype.map.call(el.querySelectorAll("img, source"), function(img) {
        return (img.getAttribute("src") || img.getAttribute("srcset") || "").toLowerCase();
      }).join(" ");

      var promoAttrs = PROMO_ATTR_PATTERN.test(attrs);
      var promoText = PROMO_TEXT_PATTERN.test(textLower);
      var promoMedia = PROMO_MEDIA_PATTERN.test(imageSrcs);

      // A layout's detached CTA slot is not promotional content when it owns
      // a visible heading and has no action or other promotional evidence.
      if (promoAttrs && promoCtaOnlyHeading(el, attrs, promoMedia, promoText)) return;
      if ((promoAttrs || promoMedia) && (text.length < 900 || promoText)) {
        el.remove();
      } else if (promoText && promoMedia && text.length < 1200) {
        el.remove();
      }
    });
  }
