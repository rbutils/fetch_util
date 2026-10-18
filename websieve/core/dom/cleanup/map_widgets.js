  function mapWidgetHasStaticImage(root) {
    return Array.prototype.some.call(root.querySelectorAll("img.leaflet-image-layer[src]"), function(img) {
      return !img.classList.contains("leaflet-tile") &&
        !!materializedHttpUrl(img.getAttribute("src")) && !elementSubtreeHidden(img);
    });
  }

  function stripMapWidgets(root) {
    root.querySelectorAll("img").forEach(function(img) {
      var src = img.getAttribute("src") || "";
      if (/maps\.wikimedia\.org\/osm|\/osm-intl\/\d+\/|tile\.openstreetmap\.org|maps\.wikimedia\.org\/v4\/marker/i.test(src)) img.remove();
    });
    root.querySelectorAll("a, button, div, span").forEach(function(el) {
      var text = normalizeText(el.textContent).toLowerCase();
      var title = (el.getAttribute("title") || "").toLowerCase();
      var textControl = /^(zoom in|zoom out|show in full screen|layers|leaflet|maplibre)$/.test(text) && textLength(el) < 40;
      var titleControl = /^(zoom in|zoom out)$/.test(title) && textLength(el) < 10;
      if ((textControl || titleControl) && !codeContentNode(el) && !mapWidgetHasStaticImage(el)) el.remove();
    });

    // Match actual library containers, retaining their physical static image layers.
    var mapContainerSelector = [
      ".leaflet-container, .leaflet-pane, .leaflet-control, .leaflet-top, .leaflet-bottom",
      ".maplibregl-map, .maplibregl-canvas-container, .maplibregl-control-container, .maplibre-map",
      ".map-container, .mw-kartographer-container, .kartographer-container"
    ].join(", ");
    root.querySelectorAll(mapContainerSelector).forEach(function(el) {
      if (textLength(el) < 200 && !mapWidgetHasStaticImage(el)) el.remove();
    });
    return root;
  }
