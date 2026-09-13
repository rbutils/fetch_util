# frozen_string_literal: true

require 'spec_helper'
require_relative '../../support/extractor_integration_helpers'

RSpec.describe FetchUtil::Extractor do
  include_context 'extractor integration helpers'

  it 'preserves short named image resources while removing evidenced status badges' do
    html = <<~HTML
      <html><head><title>Editor integration guide</title></head><body><main>
      <h1>Editor integration guide</h1>
      <p>These tools provide editor support and build integration for your application.
      Follow the linked instructions to install the integration that matches your environment.</p>
      <div><a href="https://tools.example.test/emacs">
        <img src="https://images.example.test/emacs.svg" alt="Emacs logo">
        <strong>Emacs</strong><span>Emacs plugin</span>
      </a></div>
      <div><a href="https://tools.example.test/build">
        <img src="https://images.example.test/build.svg" alt="Build logo">Build
      </a></div>
      <p><a href="https://ci.example.test/status">
        <img src="https://images.example.test/status.svg" alt="Build status">
      </a></p>
      <p><a href="https://ci.example.test/coverage">
        <img src="https://img.shields.io/badge/coverage-100-green" alt="">
      </a></p>
      <p>Configure the chosen tool with the project settings before running the application.</p>
      </main></body></html>
    HTML

    result = extract_from_url('https://guide.example.test/editors', html, reader_mode: false) { |payload| payload }
    expect(result.fetch('markdown')).to include('https://tools.example.test/emacs', 'Emacs plugin', 'https://tools.example.test/build')
    expect(result.fetch('markdown')).not_to include('https://ci.example.test/status', 'https://ci.example.test/coverage', 'img.shields.io')
  end
end
