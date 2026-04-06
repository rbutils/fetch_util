# frozen_string_literal: true

module FetchUtil
  class Browser
    module Stabilization
      # rubocop:disable Metrics/ModuleLength
      module SpaHydration
        private

        # Detect SPA framework and wait for hydration to complete.
        # Polls for framework-specific signals that indicate the app has finished
        # mounting/hydrating, then gives a brief grace period for post-hydration rendering.
        def wait_for_spa_hydration(page)
          framework = detect_spa_framework(page)
          return unless framework

          retry_until_timeout(SPA_HYDRATION_TIMEOUT, interval: SPA_HYDRATION_POLL) do
            spa_hydration_complete?(page, framework)
          end

          # Brief grace after hydration for any post-hydration rendering (lazy components, etc.)
          sleep SPA_HYDRATION_POLL
        rescue Ferrum::JavaScriptError, Ferrum::TimeoutError
          # Best-effort - don't fail the fetch if hydration detection errors
        end

        # Detect which SPA framework is running on the page.
        # Returns a symbol (:react, :next, :vue, :nuxt, :angular, :svelte, :ember,
        # :remix, :qwik, :gatsby, :docusaurus, :generic_spa) or nil if no SPA detected.
        def detect_spa_framework(page)
          result = page.evaluate(<<~JS)
            (() => {
              // Next.js (check before generic React since Next uses React)
              if (window.__NEXT_DATA__ || (window.next && window.next.version)) return 'next';

              // Nuxt (check before Vue since Nuxt uses Vue)
              if (window.__NUXT__ || window.$nuxt) return 'nuxt';

              // Remix (check before generic React since Remix uses React)
              if (window.__remixContext) return 'remix';

              // Docusaurus (check before generic React)
              if (document.getElementById('__docusaurus')) return 'docusaurus';

              // Gatsby (check before generic React)
              if (document.getElementById('___gatsby')) return 'gatsby';

              // Vue 3
              const vueMount = document.querySelector('#app, #root, #__nuxt');
              if ((vueMount && vueMount.__vue_app__) || window.__VUE__) return 'vue';

              // Vue 2
              if (vueMount && vueMount.__vue__) return 'vue';

              // Angular
              if (document.querySelector('[ng-version]')) return 'angular';

              // Svelte / SvelteKit
              if (window.__svelte || document.getElementById('svelte-announcer') ||
                  document.querySelector('[data-sveltekit-preload-data]') ||
                  document.querySelector('[class*="svelte-"]')) return 'svelte';

              // Ember
              if (window.Ember) return 'ember';

              // Qwik
              if (document.querySelector('[q\\:container]')) return 'qwik';

              // Mintlify docs platform (React SPA, renders content asynchronously into #content-area)
              if (document.querySelector('meta[name="generator"][content*="Mintlify" i]') || document.querySelector('#content-area')) {
                const gen = (document.querySelector('meta[name="generator"]') || {}).content || '';
                if (/mintlify/i.test(gen) || document.querySelector('[class*="mintlify"]')) return 'mintlify';
              }

              // GitBook docs platform (React SPA, renders content asynchronously)
              {
                const gen = (document.querySelector('meta[name="generator"]') || {}).content || '';
                if (/gitbook/i.test(gen) || /\.gitbook\.io$/.test(location.hostname)) return 'gitbook';
              }

              // Scalar OpenAPI viewer (renders API reference asynchronously)
              if (document.querySelector('.scalar-api-reference, .scalar-app, [data-scalar]')) return 'scalar';

              // Redoc / OpenAPI spec viewer (renders asynchronously from spec-url)
              if (document.querySelector('redoc, rapi-doc, .redoc-wrap')) return 'redoc';

              // ReadMe.io docs platform (React SPA, renders article content asynchronously)
              if (document.querySelector('meta[name="readme-deploy"]') || document.querySelector('.rm-Article, .rm-LandingPage, .rm-ReferenceMain')) return 'readme';

              // Generic React (last - many frameworks use React internally)
              const reactCandidates = document.querySelectorAll('#root, #app, #__next, [data-reactroot], body > div');
              for (const el of reactCandidates) {
                if (el._reactRootContainer || Object.keys(el).some(k => k.startsWith('__reactContainer$'))) return 'react';
              }

              // Generic SPA mount point with minimal content
              const mounts = document.querySelectorAll('#root, #app, [data-reactroot]');
              if (mounts.length > 0) {
                const bodyText = (document.body.innerText || '').trim();
                if (bodyText.length < 500) return 'generic_spa';
              }

              return null;
            })()
          JS

          result.is_a?(String) ? result.to_sym : nil
        rescue Ferrum::JavaScriptError, Ferrum::TimeoutError
          nil
        end

        # Check if SPA hydration is complete for the detected framework.
        def spa_hydration_complete?(page, framework)
          page.evaluate(<<~JS)
            (() => {
              const mainContent = document.querySelector('main, [role="main"], article, .content, .docs-content, #content');
              const mainText = (mainContent ? mainContent.innerText : document.body.innerText || '').trim();

              // Content-based fallback: if main area has substantial text, hydration is done
              if (mainText.length > 500) return true;

              switch ('#{framework}') {
                case 'next': {
                  const mount = document.getElementById('__next');
                  if (mount && Object.keys(mount).some(k => k.startsWith('__reactFiber$'))) return true;
                  if (window.next && window.next.version) {
                    const bodyKids = document.body.children;
                    for (let i = 0; i < bodyKids.length; i++) {
                      if (Object.keys(bodyKids[i]).some(k => k.startsWith('__reactFiber$'))) return true;
                    }
                  }
                  return false;
                }
                case 'nuxt': {
                  const mount = document.getElementById('__nuxt');
                  return !!(mount && mount.__vue_app__ && mount.__vue_app__._instance);
                }
                case 'vue': {
                  const mount = document.querySelector('#app, #root');
                  return !!(mount && (mount.__vue_app__ ? mount.__vue_app__._instance : mount.__vue__));
                }
                case 'react': {
                  const candidates = document.querySelectorAll('#root, #app, [data-reactroot], body > div');
                  for (const el of candidates) {
                    if (Object.keys(el).some(k => k.startsWith('__reactFiber$'))) return true;
                  }
                  return false;
                }
                case 'angular': {
                  const hasNgh = document.querySelectorAll('[ngh]').length > 0;
                  if (hasNgh) return false;
                  return !!document.querySelector('[ng-version]');
                }
                case 'svelte': {
                  return !!document.getElementById('svelte-announcer') ||
                         !!document.querySelector('[class*="svelte-"]');
                }
                case 'remix': {
                  const candidates = document.querySelectorAll('#root, #app, body > div');
                  for (const el of candidates) {
                    if (Object.keys(el).some(k => k.startsWith('__reactFiber$'))) return true;
                  }
                  return !!window.__remixContext;
                }
                case 'ember': {
                  return !!window.Ember && !!document.querySelector('.ember-view');
                }
                case 'qwik': {
                  return !!document.querySelector('[q\\:container]');
                }
                case 'mintlify': {
                  const contentArea = document.querySelector('#content-area, [id="content-area"]');
                  if (contentArea && (contentArea.innerText || '').trim().length > 100) return true;
                  return false;
                }
                case 'gitbook': {
                  const gbMain = document.querySelector('main');
                  if (gbMain && (gbMain.innerText || '').trim().length > 100) return true;
                  return false;
                }
                case 'scalar': {
                  const scalarRef = document.querySelector('.scalar-api-reference, .scalar-app');
                  if (scalarRef && (scalarRef.innerText || '').trim().length > 500) return true;
                  return false;
                }
                case 'redoc': {
                  const apiContent = document.querySelector('.api-content, .redoc-wrap [role="main"], .redoc-wrap');
                  if (apiContent && (apiContent.innerText || '').trim().length > 500) return true;
                  return false;
                }
                case 'readme': {
                  const rmArticle = document.querySelector('.rm-Article, .rm-LandingPage, article .markdown-body');
                  if (rmArticle && (rmArticle.innerText || '').trim().length > 100) return true;
                  return false;
                }
                case 'gatsby':
                case 'docusaurus': {
                  const mountId = '#{framework}' === 'gatsby' ? '___gatsby' : '__docusaurus';
                  const mount = document.getElementById(mountId);
                  return !!(mount && Object.keys(mount).some(k => k.startsWith('__reactFiber$')));
                }
                case 'generic_spa': {
                  return mainText.length > 200;
                }
                default:
                  return true;
              }
            })()
          JS
        rescue Ferrum::JavaScriptError, Ferrum::TimeoutError
          true
        end
      end
      # rubocop:enable Metrics/ModuleLength
    end
  end
end
