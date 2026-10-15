  function ownedExtractionObjectStatesEqual(first, second) {
    return first.length === second.length && first.every(function(record, index) {
      return record.object === second[index].object && record.value === second[index].value;
    });
  }

  function ownedExtractionStylesheets() {
    var pending = Array.prototype.slice.call(document.styleSheets).concat(Array.from(document.adoptedStyleSheets || []));
    var seen = new Set();
    var records = [];
    while (pending.length) {
      var sheet = pending.shift();
      if (seen.has(sheet)) continue;
      seen.add(sheet);
      var rules = null;
      try {
        rules = Array.prototype.map.call(sheet.cssRules, function(rule) {
          if (rule.styleSheet) pending.push(rule.styleSheet);
          return rule.cssText;
        });
      } catch (error) {
        if (error.name !== "SecurityError") throw error;
      }
      records.push({ object: sheet, value: JSON.stringify([sheet.href, sheet.disabled, sheet.media.mediaText, rules]) });
    }
    return records;
  }

  function ownedExtractionScrollState() {
    var nodes = document.querySelectorAll("*");
    var positions = [];
    for (var index = 0; index < nodes.length; index++) {
      var left = nodes[index].scrollLeft || 0;
      var top = nodes[index].scrollTop || 0;
      if (left || top) positions.push([index, left, top]);
    }
    return positions;
  }

  function ownedExtractionSourceState() {
    if (!document.documentElement || document.readyState !== "complete") return null;
    if (nodeHasShadowContent(document.documentElement)) return null;
    if (document.getAnimations && document.getAnimations().some(function(animation) {
      return animation.playState !== "finished" && animation.playState !== "idle";
    })) return null;
    var controls = Array.prototype.map.call(document.querySelectorAll("input, select, textarea"), function(control) {
      return [control.value, control.checked, control.indeterminate, control.selectedIndex,
        control.options && Array.prototype.map.call(control.options, function(option) { return option.selected; })];
    });
    var fonts = Array.from(document.fonts || []).map(function(face) {
      return { object: face, value: JSON.stringify([face.status, face.family, face.style, face.weight,
        face.stretch, face.unicodeRange, face.display, face.featureSettings]) };
    });
    return {
      root: document.documentElement,
      html: document.documentElement.outerHTML,
      url: location.href,
      active: document.activeElement,
      hover: Array.prototype.slice.call(document.querySelectorAll(":hover")),
      styles: ownedExtractionStylesheets(),
      fonts: fonts,
      rendering: JSON.stringify([innerWidth, innerHeight, devicePixelRatio, scrollX, scrollY,
        document.fonts && document.fonts.status, controls, ownedExtractionScrollState()])
    };
  }

  function ownedExtractionSourceUnchanged(previous) {
    var current = ownedExtractionSourceState();
    return !!current && current.root === previous.root && current.html === previous.html &&
      current.url === previous.url && current.active === previous.active && current.rendering === previous.rendering &&
      current.hover.length === previous.hover.length && current.hover.every(function(node, index) {
        return node === previous.hover[index];
      }) && ownedExtractionObjectStatesEqual(previous.styles, current.styles) &&
      ownedExtractionObjectStatesEqual(previous.fonts, current.fonts);
  }
