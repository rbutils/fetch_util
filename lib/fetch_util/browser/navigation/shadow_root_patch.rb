# frozen_string_literal: true

module FetchUtil
  class Browser
    module Navigation
      module ShadowRootPatch
        private

        def shadow_root_patch
          token = JSON.generate(Browser::SHADOW_ROOT_ACCESS_TOKEN)
          property = JSON.generate(Browser::SHADOW_ROOT_READER_PROPERTY)
          <<~JS
            {
              const shadowRootReaderProperty = #{property};
              const shadowRootInstallProperty = shadowRootReaderProperty + ":installed";
              const shadowRootToken = #{token};
              const weakMapGet = WeakMap.prototype.get;
              const weakMapSet = WeakMap.prototype.set;
              const reflectApply = Reflect.apply;
              let readShadowRoot = null;

              try {
                readShadowRoot = window.top[shadowRootReaderProperty];
              } catch (_error) {
              }

              if (typeof readShadowRoot !== "function") {
                const shadowRoots = new WeakMap();
                readShadowRoot = function(candidateToken, operation, host, root) {
                  if (candidateToken !== shadowRootToken) return null;
                  try {
                    if (operation === "set") {
                      reflectApply(weakMapSet, shadowRoots, [host, root]);
                      return true;
                    }
                    return operation === "get" ? reflectApply(weakMapGet, shadowRoots, [host]) || null : null;
                  } catch (_error) {
                    return null;
                  }
                };
              }

              try {
                if (!Object.prototype.hasOwnProperty.call(window, shadowRootReaderProperty)) {
                  Object.defineProperty(window, shadowRootReaderProperty, {
                    value: readShadowRoot,
                    configurable: false,
                    enumerable: false,
                    writable: false
                  });
                }
              } catch (_error) {
              }

              const installed = window[shadowRootInstallProperty] === true;
              const descriptor = Object.getOwnPropertyDescriptor(Element.prototype, "attachShadow");
              const attachShadow = descriptor && descriptor.value;
              if (attachShadow && !installed) {
                const trackedAttachShadow = new Proxy(attachShadow, {
                  apply: function(target, thisArg, args) {
                    const root = reflectApply(target, thisArg, args);
                    try {
                      readShadowRoot(shadowRootToken, "set", thisArg, root);
                    } catch (_error) {
                    }
                    return root;
                  }
                });
                Object.defineProperty(Element.prototype, "attachShadow", Object.assign({}, descriptor, {
                  value: trackedAttachShadow
                }));
                Object.defineProperty(window, shadowRootInstallProperty, {
                  value: true,
                  configurable: false,
                  enumerable: false,
                  writable: false
                });
              }
            }
          JS
        end
      end
    end
  end
end
