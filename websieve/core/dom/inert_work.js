  function withInertDomWork(extract) {
    return function(options) {
      var creationDescriptor = Object.getOwnPropertyDescriptor(document, "createElement");
      var cloningDescriptor = Object.getOwnPropertyDescriptor(Node.prototype, "cloneNode");
      var createElement = document.createElement;
      var cloneNode = Node.prototype.cloneNode;
      var workingDocument = document.implementation.createHTMLDocument(document.title || "");
      var base = createElement.call(workingDocument, "base");
      base.href = document.baseURI;
      workingDocument.head.appendChild(base);
      var language = document.documentElement && document.documentElement.getAttribute("lang");
      if (language) workingDocument.documentElement.setAttribute("lang", language);
      var replaceCreation = !creationDescriptor || creationDescriptor.configurable || creationDescriptor.writable;
      var replaceCloning = cloningDescriptor && (cloningDescriptor.configurable || cloningDescriptor.writable);

      try {
        if (replaceCreation) Object.defineProperty(document, "createElement", {
          configurable: !creationDescriptor || creationDescriptor.configurable,
          enumerable: !!(creationDescriptor && creationDescriptor.enumerable),
          writable: true,
          value: function(name, elementOptions) {
            return createElement.call(workingDocument, name, elementOptions);
          }
        });
        if (replaceCloning) Object.defineProperty(Node.prototype, "cloneNode", Object.assign({}, cloningDescriptor, {
          value: function(deep) {
            if (this.nodeType === 9) return cloneNode.call(this, deep);
            var owner = this.ownerDocument && !this.ownerDocument.defaultView ? this.ownerDocument : workingDocument;
            return owner.importNode(this, !!deep);
          }
        }));
        return extract(options);
      } finally {
        if (replaceCreation) {
          if (creationDescriptor) Object.defineProperty(document, "createElement", creationDescriptor);
          else delete document.createElement;
        }
        if (replaceCloning) Object.defineProperty(Node.prototype, "cloneNode", cloningDescriptor);
      }
    };
  }
