# frozen_string_literal: true

module FetchUtil
  class Browser
    module Navigation
      module NavigatorPatch
        private

        def navigator_patch = @navigator_patch

        def build_navigator_patch
          ua_version = @user_agent[%r{Chrome/([\d.]+)}, 1] || "136.0.7103.113"
          major = ua_version.split(".").first
          languages_json = JSON.generate(@accept_language.split(",").map { |part| part.split(";").first.strip })
          <<~JS
            Object.defineProperty(navigator, "webdriver", { get: () => undefined });
            Object.defineProperty(navigator, "languages", { get: () => #{languages_json} });
            Object.defineProperty(navigator, "platform", { get: () => "Linux x86_64" });

            Object.defineProperty(navigator, "plugins", {
              get: () => {
                const p = { 0: { name: "PDF Viewer", filename: "internal-pdf-viewer", description: "Portable Document Format" },
                            1: { name: "Chrome PDF Viewer", filename: "internal-pdf-viewer", description: "Portable Document Format" },
                            2: { name: "Chromium PDF Viewer", filename: "internal-pdf-viewer", description: "Portable Document Format" },
                            length: 3 };
                p[Symbol.iterator] = function*() { yield p[0]; yield p[1]; yield p[2]; };
                return p;
              }
            });
            Object.defineProperty(navigator, "mimeTypes", {
              get: () => {
                const m = { 0: { type: "application/pdf", suffixes: "pdf", description: "Portable Document Format" },
                            length: 1 };
                m[Symbol.iterator] = function*() { yield m[0]; };
                return m;
              }
            });

            if (!window.chrome) {
              window.chrome = { runtime: {}, loadTimes: function(){}, csi: function(){} };
            }

            const origQuery = window.Permissions && Permissions.prototype.query;
            if (origQuery) {
              Permissions.prototype.query = function(parameters) {
                return parameters.name === "notifications"
                  ? Promise.resolve({ state: Notification.permission })
                  : origQuery.call(this, parameters);
              };
            }

            Object.defineProperty(navigator, "hardwareConcurrency", { get: () => 4 });

            if (!navigator.deviceMemory) {
              Object.defineProperty(navigator, "deviceMemory", { get: () => 8 });
            }

            if (!navigator.connection) {
              Object.defineProperty(navigator, "connection", {
                get: () => ({ effectiveType: "4g", rtt: 50, downlink: 10, saveData: false })
              });
            }

            {
              const uaData = navigator.userAgentData;
              const missingUserAgentData = !uaData || !Array.isArray(uaData.brands) || uaData.brands.length === 0 || !uaData.platform;
              if (missingUserAgentData) {
                Object.defineProperty(navigator, "userAgentData", {
                  get: () => ({
                    brands: [
                      { brand: "Chromium", version: "#{major}" },
                      { brand: "Google Chrome", version: "#{major}" },
                      { brand: "Not.A/Brand", version: "24" }
                    ],
                    mobile: false,
                    platform: "Linux",
                    getHighEntropyValues: function(hints) {
                      return Promise.resolve({
                        architecture: "x86",
                        bitness: "64",
                        brands: this.brands,
                        fullVersionList: [
                          { brand: "Chromium", version: "#{ua_version}" },
                          { brand: "Google Chrome", version: "#{ua_version}" }
                        ],
                        mobile: false,
                        model: "",
                        platform: "Linux",
                        platformVersion: "6.1.0",
                        uaFullVersion: "#{ua_version}"
                      });
                    }
                  })
                });
              }
            }

            {
              const getParameterProto = WebGLRenderingContext.prototype.getParameter;
              WebGLRenderingContext.prototype.getParameter = function(param) {
                const debugExt = this.getExtension('WEBGL_debug_renderer_info');
                if (debugExt) {
                  if (param === debugExt.UNMASKED_VENDOR_WEBGL) return 'Google Inc. (Intel)';
                  if (param === debugExt.UNMASKED_RENDERER_WEBGL)
                    return 'ANGLE (Intel, Mesa Intel(R) UHD Graphics 630 (CFL GT2), OpenGL 4.6)';
                }
                return getParameterProto.call(this, param);
              };
            }

            Object.defineProperty(screen, "width", { get: () => #{@viewport.fetch(:width)} });
            Object.defineProperty(screen, "height", { get: () => #{@viewport.fetch(:height)} });
            Object.defineProperty(screen, "availWidth", { get: () => #{@viewport.fetch(:width)} });
            Object.defineProperty(screen, "availHeight", { get: () => #{@viewport.fetch(:height)} });
          JS
        end
      end
    end
  end
end
