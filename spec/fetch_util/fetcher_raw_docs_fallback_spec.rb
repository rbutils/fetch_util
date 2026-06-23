# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FetchUtil::Fetcher do
  include_context 'fetcher spec helpers'

  it 'falls back to raw docs extraction when browser extraction fails on docs pages' do
    fallback_payload = payload.merge(
      'title' => 'Pod v1 core',
      'markdown' => '# Pod v1 core\n\nPod is a collection of containers.',
      'canonicalUrl' => 'https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.31/',
      'siteName' => 'kubernetes.io'
    )

    stub_browser_failure('https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.31/#pod-v1-core', FetchUtil::ExtractionError, 'timeout')
    stub_raw_docs_fallback('https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.31/#pod-v1-core', payload: fallback_payload)

    result = fetch_with_dependencies('https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.31/#pod-v1-core')

    expect(result.title).to eq('Pod v1 core')
    expect(result.final_url).to eq('https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.31/#pod-v1-core')
    expect(result.warnings).to eq([])
  end

  it 'replaces obviously bad docs output with raw docs fallback content' do
    docs_page = instance_double('FerrumPage', current_url: 'https://caddyserver.com/docs/caddyfile/directives/reverse_proxy')
    weak_payload = payload.merge(
      'title' => 'Caddy - The Ultimate Server with Automatic HTTPS',
      'markdown' => "# Caddy - The Ultimate Server with Automatic HTTPS\n\n# reverse_proxy\n\nProxies requests to one or more backends.",
      'canonicalUrl' => 'https://caddyserver.com/docs/caddyfile/directives/reverse_proxy',
      'warnings' => []
    )
    fallback_payload = payload.merge(
      'title' => 'reverse_proxy',
      'markdown' => '# reverse_proxy\n\nProxies requests to one or more backends.',
      'canonicalUrl' => 'https://caddyserver.com/docs/caddyfile/directives/reverse_proxy',
      'siteName' => 'Caddy Documentation'
    )

    stub_browser_extraction('https://caddyserver.com/docs/caddyfile/directives/reverse_proxy', page: docs_page, payload: weak_payload)
    stub_raw_docs_fallback('https://caddyserver.com/docs/caddyfile/directives/reverse_proxy', payload: fallback_payload)

    result = fetch_with_dependencies('https://caddyserver.com/docs/caddyfile/directives/reverse_proxy')

    expect(result.title).to eq('reverse_proxy')
    expect(result.markdown).to include('Proxies requests to one or more backends')
  end

  it 'allows docs fallback when the extracted final url looks docs-like even if the requested url did not' do
    redirected_page = instance_double('FerrumPage', current_url: 'https://docs.example.dev/reference/widgets')
    weak_payload = payload.merge(
      'title' => 'Documentation Portal',
      'markdown' => "# Documentation Portal\n\n# Widgets\n\nReference content.",
      'canonicalUrl' => 'https://docs.example.dev/reference/widgets',
      'warnings' => []
    )
    fallback_payload = payload.merge(
      'title' => 'Widgets',
      'markdown' => '# Widgets\n\nReference content.',
      'canonicalUrl' => 'https://docs.example.dev/reference/widgets',
      'siteName' => 'Example Docs'
    )

    stub_browser_extraction('https://example.com/go/widgets', page: redirected_page, payload: weak_payload)
    stub_raw_docs_fallback('https://example.com/go/widgets', final_url: 'https://docs.example.dev/reference/widgets', payload: fallback_payload)

    result = fetch_with_dependencies('https://example.com/go/widgets')

    expect(result.title).to eq('Widgets')
    expect(result.final_url).to eq('https://docs.example.dev/reference/widgets')
    expect(result.site_name).to eq('Example Docs')
  end

  it 'uses raw docs fallback for developer-hosted docs urls after browser failure' do
    fallback_payload = payload.merge(
      'title' => 'terraform_data',
      'markdown' => '# terraform_data\n\nManages arbitrary values in Terraform.',
      'canonicalUrl' => 'https://developer.hashicorp.com/terraform/language/resources/terraform-data',
      'siteName' => 'HashiCorp Developer'
    )

    stub_browser_failure('https://developer.hashicorp.com/terraform/language/resources/terraform-data', FetchUtil::BrowserError, 'boom')
    stub_raw_docs_fallback('https://developer.hashicorp.com/terraform/language/resources/terraform-data', payload: fallback_payload)

    result = fetch_with_dependencies('https://developer.hashicorp.com/terraform/language/resources/terraform-data')

    expect(result.title).to eq('terraform_data')
    expect(result.final_url).to eq('https://developer.hashicorp.com/terraform/language/resources/terraform-data')
    expect(result.site_name).to eq('HashiCorp Developer')
  end
end
