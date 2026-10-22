  function linkedArticleResourceFigure(figure) {
    if (!figure || !figure.matches("figure") || elementVisuallyHidden(figure)) return null;
    if (figure.closest("header, nav, aside, footer, form")) return null;
    var links = Array.prototype.slice.call(figure.querySelectorAll("a[href]"));
    if (links.length !== 1) return null;
    var link = links[0];
    var href = materializedHttpUrl(link.getAttribute("href"));
    if (!href || href.split("#")[0] === location.href.split("#")[0]) return null;
    if (normalizeText(figure.textContent || "") !== normalizeText(link.textContent || "")) return null;
    var labels = Array.prototype.filter.call(link.querySelectorAll("div, p"), function(node) {
      return !node.querySelector("div, p") && !elementVisuallyHidden(node) && normalizeText(node.textContent || "");
    });
    if (labels.length < 2) return null;
    return { figure: figure, link: link, href: href };
  }

  function articleBylineNode(node) {
    return !linkedArticleResourceFigure(node.closest("figure")) && !bylinePublicationHeadingField(node) &&
      !linkedPublicationBylineOwner(node);
  }
