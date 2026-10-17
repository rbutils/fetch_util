  function markdownVideoPosterHidden(video, root) {
    var visibility = "";
    var current = video;
    while (current && current.nodeType === Node.ELEMENT_NODE) {
      if (current.hasAttribute("hidden") || current.hasAttribute("inert")) return true;
      var style = current.style;
      if (style) {
        if (style.display === "none" || (style.opacity !== "" && Number(style.opacity) === 0)) return true;
        if (!visibility && /^(?:visible|hidden|collapse)$/.test(style.visibility)) visibility = style.visibility;
      }
      if (current === root) break;
      current = current.parentElement;
    }
    return visibility === "hidden" || visibility === "collapse";
  }

  function materializeMarkdownVideoReferences(root) {
    var videos = Array.prototype.slice.call(root.querySelectorAll("video"));
    if (root.nodeType === Node.ELEMENT_NODE && root.matches("video")) videos.unshift(root);
    videos.forEach(function(video) {
      if (video.closest("pre, code, script, style, noscript, template") || markdownVideoPosterHidden(video, root)) return;
      var poster = materializedHttpUrl(video.getAttribute("poster"));
      var supplied = Array.prototype.some.call(video.querySelectorAll("img[src]"), function(image) {
        if (markdownVideoPosterHidden(image, video) || materializedHttpUrl(image.getAttribute("src")) !== poster) return false;
        if (!normalizeText(image.getAttribute("alt"))) {
          image.setAttribute("alt", normalizeText(video.getAttribute("aria-label") || video.getAttribute("title")) || "Video poster");
        }
        return true;
      });
      if (poster && !supplied) {
        var image = video.ownerDocument.createElement("img");
        image.setAttribute("src", poster);
        image.setAttribute("alt", normalizeText(video.getAttribute("aria-label") || video.getAttribute("title")) || "Video poster");
        video.appendChild(image);
      }
      var sources = [video].concat(Array.prototype.slice.call(video.querySelectorAll("source[src]")));
      sources.forEach(function(source) {
        var url = materializedHttpUrl(source.getAttribute("src"));
        if (!url) return;
        var linked = Array.prototype.some.call(video.querySelectorAll("a[href]"), function(link) {
          return !markdownVideoPosterHidden(link, video) &&
            (normalizeText(link.textContent) || normalizeText(link.getAttribute("aria-label"))) &&
            materializedHttpUrl(link.getAttribute("href")) === url;
        });
        if (linked) return;
        var link = video.ownerDocument.createElement("a");
        link.setAttribute("href", url);
        link.appendChild(video.ownerDocument.createTextNode("Video source"));
        video.appendChild(video.ownerDocument.createTextNode(" "));
        video.appendChild(link);
      });
    });
  }
