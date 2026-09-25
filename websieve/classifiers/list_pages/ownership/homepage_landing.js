  function homepageLandingChrome(node) {
    return node.closest("nav, aside, header, footer, form, [role~='navigation' i], [role~='complementary' i], [role='search']");
  }

  function homepageLandingOwnership() {
    if (!document.body || !homepageRootPath()) return null;
    if (typeof fallbackFocalHeadlineOwnership === "function" && fallbackFocalHeadlineOwnership()) return null;

    var main = document.querySelector("main, [role~='main' i]");
    if (!main || elementSubtreeHidden(main)) return null;

    var sourceClones = new WeakMap();
    var visibleMain = visibilityPrunedClone(main, document, sourceClones);
    var visibleHeadings = Array.prototype.filter.call(visibleMain.querySelectorAll("h1"), function(heading) {
      return !homepageLandingChrome(heading);
    });
    if (visibleHeadings.length !== 1) return null;
    if (visibleHeadings[0].closest("article")) return null;

    var visibleArticles = Array.prototype.filter.call(visibleMain.querySelectorAll("article"), function(article) {
      return !article.parentElement.closest("article") && !homepageLandingChrome(article);
    });
    var proseOwners = visibleArticles.filter(function(article) {
      if (article.querySelector("[itemprop~='headline' i], h2 a[href], h3 a[href]")) return false;
      var paragraphs = Array.prototype.filter.call(article.querySelectorAll("p"), function(paragraph) {
        return paragraph.closest("article") === article && !homepageLandingChrome(paragraph) &&
          normalizeText(paragraph.textContent || "").length >= 80;
      });
      return paragraphs.length >= 2 && normalizeText(paragraphs.map(function(paragraph) {
        return paragraph.textContent || "";
      }).join(" ")).length >= 280;
    });
    if (proseOwners.length !== 1) return null;

    var visibleBody = proseOwners[0];
    var substantialForeignProse = Array.prototype.some.call(visibleMain.querySelectorAll("p"), function(paragraph) {
      return !homepageLandingChrome(paragraph) && paragraph.closest("article") !== visibleBody &&
        normalizeText(paragraph.textContent || "").length >= 80;
    });
    if (substantialForeignProse) return null;

    var foreignHeadedRecord = visibleArticles.some(function(article) {
      return article !== visibleBody && article.querySelector("h1, h2, h3, [itemprop~='headline' i]");
    });
    if (foreignHeadedRecord) return null;

    var ownedMedia = Array.prototype.find.call(visibleBody.querySelectorAll("img[src]"), function(image) {
      return image.closest("article") === visibleBody && !homepageLandingChrome(image);
    });
    if (!ownedMedia) return null;

    var serviceLink = Array.prototype.find.call(visibleMain.querySelectorAll("a[href]"), function(link) {
      if (homepageLandingChrome(link) || link.closest("article") ||
          normalizeText(link.textContent || "").length < 5) return false;
      var url = materializedHttpUrl(link.getAttribute("href"));
      if (!url) return false;
      try {
        var parsed = new URL(url);
        return parsed.origin === location.origin && parsed.pathname !== "/";
      } catch (_error) {
        return false;
      }
    });
    if (!serviceLink) return null;

    var pageHeading = Array.prototype.find.call(main.querySelectorAll("h1"), function(heading) {
      return sourceClones.get(heading) === visibleHeadings[0];
    });
    var body = Array.prototype.find.call(main.querySelectorAll("article"), function(article) {
      return sourceClones.get(article) === visibleBody;
    });
    if (!pageHeading || !body) return null;

    return { main: main, heading: pageHeading, body: body };
  }
