(() => {
  const read = (prototype, name, node) => Object.getOwnPropertyDescriptor(prototype, name).get.call(node);
  const parent = node => read(Node.prototype, "parentElement", node);
  const tag = node => read(Element.prototype, "tagName", node);
  const attribute = (node, name) => Element.prototype.getAttribute.call(node, name);
  const nodes = [document.documentElement, ...Element.prototype.querySelectorAll.call(document.documentElement, "*")];
  const indices = new Map(nodes.map((node, index) => [node, index]));
  const styleNames = ["display", "visibility", "opacity", "position", "overflow", "overflowX",
    "overflowY", "clip", "clipPath", "transform", "contentVisibility", "width", "height",
    "maxHeight", "maxWidth", "whiteSpace", "fontSize", "lineHeight", "animationName"];
  const rectangle = node => {
    const rect = Element.prototype.getBoundingClientRect.call(node);
    return {x: rect.x, y: rect.y, width: rect.width, height: rect.height};
  };
  const elements = nodes.map((node, index) => {
    const computed = getComputedStyle(node);
    const styles = Object.fromEntries(styleNames.map(name => [name, computed[name]]));
    const image = node instanceof HTMLImageElement;
    const playable = node instanceof HTMLMediaElement;
    const media = /^(IMG|VIDEO|AUDIO|IFRAME|SOURCE)$/.test(tag(node)) ? {
      src: attribute(node, "src"),
      currentSrc: (image ? read(HTMLImageElement.prototype, "currentSrc", node) : (playable ? read(HTMLMediaElement.prototype, "currentSrc", node) : null)) || null,
      srcset: attribute(node, "srcset"), poster: attribute(node, "poster"),
      complete: image ? read(HTMLImageElement.prototype, "complete", node) : null,
      naturalWidth: image ? read(HTMLImageElement.prototype, "naturalWidth", node) : null,
      naturalHeight: image ? read(HTMLImageElement.prototype, "naturalHeight", node) : null,
      readyState: playable ? read(HTMLMediaElement.prototype, "readyState", node) : null
    } : null;
    return {index, parent: indices.get(parent(node)) ?? null, tag: tag(node),
      attributes: Object.fromEntries(Array.from(read(Element.prototype, "attributes", node), attr => [attr.name, attr.value])),
      styles, rect: rectangle(node), media};
  });
  const texts = [];
  const walker = document.createTreeWalker(document.documentElement, NodeFilter.SHOW_TEXT);
  while (walker.nextNode()) {
    const node = walker.currentNode;
    texts.push({parent: indices.get(parent(node)) ?? null, text: read(Node.prototype, "nodeValue", node)});
  }
  const shadowRoots = nodes.filter(node => read(Element.prototype, "shadowRoot", node)).map(node => {
    const shadow = read(Element.prototype, "shadowRoot", node);
    return {host: indices.get(node), html: read(ShadowRoot.prototype, "innerHTML", shadow),
      text: read(Node.prototype, "textContent", shadow), rect: rectangle(node)};
  });
  return {url: location.href, title: document.title, documentHtml: read(Element.prototype, "outerHTML", document.documentElement),
    bodyText: document.body ? read(HTMLElement.prototype, "innerText", document.body) : "", viewport: [innerWidth, innerHeight],
    devicePixelRatio, elements, texts, openShadowRoots: shadowRoots};
})()
