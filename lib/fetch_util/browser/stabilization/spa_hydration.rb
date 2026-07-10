# frozen_string_literal: true

module FetchUtil
  class Browser
    module Stabilization
      # rubocop:disable Metrics/ModuleLength
      module SpaHydration
        private

        def wait_for_spa_hydration(page)
          framework = detect_spa_framework(page)
          return unless framework

          retry_until_timeout(SPA_HYDRATION_TIMEOUT, interval: SPA_HYDRATION_POLL) do
            spa_hydration_complete?(page, framework)
          end

          sleep SPA_HYDRATION_POLL
        rescue Ferrum::JavaScriptError, Ferrum::TimeoutError
        end

        def wait_for_structural_readiness(page, region_selector, card_selector)
          previous_count = nil
          retry_until_timeout(SPA_HYDRATION_TIMEOUT, interval: SPA_HYDRATION_POLL) do
            counts = page.evaluate(<<~JS)
              (() => ({
                regions: document.querySelectorAll(#{region_selector.to_json}).length,
                cards: document.querySelectorAll(#{card_selector.to_json}).length
              }))()
            JS
            current_count = [counts["regions"], counts["cards"]]
            ready = current_count == previous_count && current_count[0].positive? && current_count[1] >= 3
            previous_count = current_count
            ready
          end
        rescue Ferrum::JavaScriptError, Ferrum::TimeoutError
        end

        def detect_spa_framework(page)
          result = page.evaluate(spa_framework_detection_script)

          result.is_a?(String) ? result.to_sym : nil
        rescue Ferrum::JavaScriptError, Ferrum::TimeoutError
          nil
        end

        def spa_hydration_complete?(page, framework)
          page.evaluate(spa_hydration_completion_script(framework))
        rescue Ferrum::JavaScriptError, Ferrum::TimeoutError
          true
        end

        def spa_framework_detection_script
          <<~JS
            (() => {
              if (window.__NEXT_DATA__ || (window.next && window.next.version)) return 'next';
              if (window.__NUXT__ || window.$nuxt) return 'nuxt';
              if (window.__remixContext) return 'remix';
              if (document.getElementById('__docusaurus')) return 'docusaurus';
              if (document.getElementById('___gatsby')) return 'gatsby';

              const vueMount = document.querySelector('#app, #root, #__nuxt');
              if ((vueMount && vueMount.__vue_app__) || window.__VUE__) return 'vue';
              if (vueMount && vueMount.__vue__) return 'vue';
              if (document.querySelector('[ng-version]')) return 'angular';
              if (window.__svelte || document.getElementById('svelte-announcer') ||
                  document.querySelector('[data-sveltekit-preload-data]') ||
                  document.querySelector('[class*="svelte-"]')) return 'svelte';
              if (window.Ember) return 'ember';
              if (document.querySelector('[q\\:container]')) return 'qwik';
              if (document.querySelector('meta[name="generator"][content*="Mintlify" i]') || document.querySelector('#content-area')) {
                const gen = (document.querySelector('meta[name="generator"]') || {}).content || '';
                if (/mintlify/i.test(gen) || document.querySelector('[class*="mintlify"]')) return 'mintlify';
              }
              {
                const gen = (document.querySelector('meta[name="generator"]') || {}).content || '';
                if (/gitbook/i.test(gen) || /\.gitbook\.io$/.test(location.hostname)) return 'gitbook';
              }
              if (document.querySelector('.scalar-api-reference, .scalar-app, [data-scalar]')) return 'scalar';
              if (document.querySelector('redoc, rapi-doc, .redoc-wrap')) return 'redoc';
              if (document.querySelector('meta[name="readme-deploy"]') || document.querySelector('.rm-Article, .rm-LandingPage, .rm-ReferenceMain')) return 'readme';

              const reactCandidates = document.querySelectorAll('#root, #app, #__next, [data-reactroot], body > div');
              for (const el of reactCandidates) {
                if (el._reactRootContainer || Object.keys(el).some(k => k.startsWith('__reactContainer$'))) return 'react';
              }

              const mounts = document.querySelectorAll('#root, #app, [data-reactroot]');
              if (mounts.length > 0) {
                const bodyText = (document.body.innerText || '').trim();
                if (bodyText.length < 500) return 'generic_spa';
              }

              return null;
            })()
          JS
        end

        def spa_hydration_completion_script(framework)
          <<~JS
            (() => {
              const mainContent = document.querySelector('main, [role="main"], article, .content, .docs-content, #content');
              const mainText = (mainContent ? mainContent.innerText : document.body.innerText || '').trim();

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
        end
      end
      # rubocop:enable Metrics/ModuleLength
    end
  end
end
