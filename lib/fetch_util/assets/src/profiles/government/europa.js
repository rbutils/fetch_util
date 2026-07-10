  function governmentProgramMicrositeContent(metadata) {
    var root = document.querySelector("main#main-content .group--type--microsite.microsite--type--programs") ||
      document.querySelector("main[role='main'] .group--type--microsite.microsite--type--programs") ||
      document.querySelector("main#main-content .node-intro") ||
      null;
    if (!root) return null;
    if (!document.querySelector(".usa-megamenu, .usa-nav__submenu") && !document.querySelector(".usa-banner")) return null;
    if (!root.querySelector("h1, .microsite-title, .field--name--field-intro, .field--name-field-intro")) return null;

    return institutionalArticleResult(metadata, root, {
      minText: 350,
      titleRoot: root,
      strip: function(clone) {
        clone.querySelectorAll(".group-menu, [class*='group-menu'], .usa-breadcrumb, [id*='breadcrumb' i], .slick-dots, .slick-arrow").forEach(function(el) { el.remove(); });
      }
    });
  }

  function europaServiceLandingContent(metadata) {
    var root = document.querySelector("main#main-content #main-article") ||
      document.querySelector("main#main-content") ||
      document.querySelector("main[role='main']");
    if (!root || !document.querySelector("#feedback-form")) return null;
    if (!document.querySelector("main#main-content") || !root.querySelector("nav.contents, .contents, h1")) return null;
    if (!/\bYour Europe\b/i.test([metadata.siteName || "", metadata.title || "", document.title || "", document.body.textContent || ""].join(" "))) return null;

    return institutionalArticleResult(metadata, root, {
      minText: 150,
      preserveContentNav: true,
      titleRoot: document.querySelector("main#main-content") || root,
      strip: function(clone) {
        clone.querySelectorAll("#feedback-form, [id*='feedback' i], [class*='feedback' i], .share, [id^='sh-']").forEach(function(el) { el.remove(); });
      }
    });
  }
