  function inactiveListPanelSelector() {
    return ".slick-slide[aria-hidden='true'], .swiper-slide[aria-hidden='true'], [role='tabpanel'][aria-hidden='true']";
  }

  function listCardNodeHidden(node) {
    return elementVisuallyHidden(node) || !!(node && node.closest && node.closest(inactiveListPanelSelector()));
  }

  function pruneListCardVisibility(source, clone) {
    pruneHiddenClone(source, clone);
    clone.querySelectorAll(inactiveListPanelSelector()).forEach(function(panel) { panel.remove(); });
  }
