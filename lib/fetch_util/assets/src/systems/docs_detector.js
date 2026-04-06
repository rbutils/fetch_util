  function docsSystemInfo(metadata) {
    var generator = normalizeText(firstText(["meta[name='generator']"], "content") || "").toLowerCase();
    var appName = normalizeText(firstText(["meta[name='application-name']", "meta[property='og:site_name']"], "content") || "").toLowerCase();
    var signature = normalizeText([
      location.hostname,
      metadata && metadata.siteName,
      metadata && metadata.title,
      document.title,
      generator,
      appName
    ].join(" ")).toLowerCase();

    if (document.querySelector("[class*='stldocs-']")) return { system: "stldocs", generator: generator, appName: appName, signature: signature };
    if (/astro/.test(generator) && (document.querySelector("#starlight__sidebar, starlight-menu-button, [class*='sl-markdown-content']") || /starlight/.test(signature))) {
      return { system: "starlight", generator: generator, appName: appName, signature: signature };
    }
    if (/mkdocs/.test(generator) || (document.querySelector(".md-content") && document.querySelector(".md-sidebar, .md-header, .md-nav"))) {
      return { system: "mkdocs", generator: generator, appName: appName, signature: signature };
    }
    if (document.querySelector("meta[name='readme-deploy']") || document.querySelector(".rm-Article, .rm-LandingPage, .rm-ReferenceMain") || /\.readme\.(io|com)$/.test(location.hostname)) {
      return { system: "readme", generator: generator, appName: appName, signature: signature };
    }
    if (document.querySelector("redoc, rapi-doc") || /redoc/i.test(generator) || document.querySelector(".redoc-wrap, .api-content[role='main']")) {
      return { system: "redoc", generator: generator, appName: appName, signature: signature };
    }
    if (/buildwithfern|fern/.test(generator) || document.querySelector("#fern-sidebar, .fern-page-heading, .fern-prose, .fern-layout-reference, .fern-layout-overview")) {
      return { system: "fern", generator: generator, appName: appName, signature: signature };
    }
    if (/nextra/.test(signature) || document.querySelector(".nextra-content, .nextra-breadcrumb, #nextra-skip-nav, .nextra-nav-container")) {
      return { system: "nextra", generator: generator, appName: appName, signature: signature };
    }
    if (/vitepress/.test(generator) || document.querySelector("#VPContent, .VPDoc, .VPSidebar, .VPNav")) {
      return { system: "vitepress", generator: generator, appName: appName, signature: signature };
    }
    if (/rspress/.test(generator) || document.querySelector("#__rspress_root, .rspress-doc, .rp-sidebar, .rp-nav")) {
      return { system: "rspress", generator: generator, appName: appName, signature: signature };
    }
    if (/mdbook/i.test(generator) || document.querySelector("#sidebar.sidebar, #menu-bar-hover-placeholder, nav.sidebar, #sidebar-toggle")) {
      return { system: "mdbook", generator: generator, appName: appName, signature: signature };
    }
    if (/antora/.test(generator) || document.querySelector("article.doc, main.main article.doc, .doc .homecards")) {
      return { system: "antora", generator: generator, appName: appName, signature: signature };
    }
    if (/mintlify/.test(generator) || document.querySelector("[class*='mintlify'], [data-testid='table-of-contents'], nav[aria-label='Table of contents']")) {
      return { system: "mintlify", generator: generator, appName: appName, signature: signature };
    }
    if (/gitbook/i.test(generator) || /\.gitbook\.io$/.test(location.hostname) || (document.querySelector("main [class*='whitespace-pre-wrap']") && /powered by gitbook/i.test(document.body.innerText))) {
      return { system: "gitbook", generator: generator, appName: appName, signature: signature };
    }
    if (document.querySelector(".scalar-api-reference, .scalar-app, [data-scalar]")) {
      return { system: "scalar", generator: generator, appName: appName, signature: signature };
    }
    if (/docusaurus/.test(generator) || document.querySelector("#__docusaurus, .theme-doc-markdown, .theme-doc-sidebar-container, nav[aria-label='Docs sidebar']")) {
      return { system: "docusaurus", generator: generator, appName: appName, signature: signature };
    }
    if (/^(doc\.rust-lang\.org|docs\.rs)$/.test(location.hostname) || document.querySelector(".rustdoc, .sidebar-elems, #crate-search")) {
      return { system: "rustdoc", generator: generator, appName: appName, signature: signature };
    }
    if (/^pkg\.go\.dev$/.test(location.hostname) || document.querySelector("#main-content .Documentation, #main-content #pkg-index, .go-DetailsHeader")) {
      return { system: "go_pkg", generator: generator, appName: appName, signature: signature };
    }
    if (/readthedocs/.test(signature) || document.querySelector(".rst-content, .wy-nav-content, .wy-nav-side")) {
      return { system: "readthedocs", generator: generator, appName: appName, signature: signature };
    }
    if (/sphinx/.test(generator) || document.querySelector("div.body[role='main'], dt.sig, a.headerlink, div.highlight")) {
      return { system: "sphinx", generator: generator, appName: appName, signature: signature };
    }
    if (document.querySelector("devsite-header, devsite-content, devsite-toc, devsite-nav") || /devsite/.test(signature)) {
      return { system: "google_devsite", generator: generator, appName: appName, signature: signature };
    }
    if (document.querySelector("[class*='elastic-docs'], [data-elastic-docs]") || (/elastic/i.test(signature) && document.querySelector("[class*='docBody'], article[class*='doc']"))) {
      return { system: "elastic_docs", generator: generator, appName: appName, signature: signature };
    }
    if (document.querySelector("main .markdown-body, main article, main [data-pagefind-body], main .prose")) {
      return { system: "generic_docs", generator: generator, appName: appName, signature: signature };
    }

    return null;
  }
