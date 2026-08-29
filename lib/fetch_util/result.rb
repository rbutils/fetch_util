# frozen_string_literal: true

module FetchUtil
  class Result
    attr_reader :url, :final_url, :title, :byline, :excerpt, :site_name,
                :published_time, :canonical_url, :language, :name, :company, :location,
                :description, :ingredients, :instructions, :bedrooms, :bathrooms,
                :area_sqft, :html, :markdown,
                :metadata, :reader_mode, :content_type, :suspect, :warnings,
                :content_completeness_ratio, :content_format, :paywall_state,
                :price, :rating, :address, :social_kind, :platform, :handle,
                :reply_count, :community, :score, :error_message

    class << self
      def from_payload(url:, final_url:, payload:, canonical_url:, content_type:, warnings:, suspect:)
        metadata = payload_metadata(
          payload,
          canonical_url: canonical_url,
          final_url: final_url,
          content_type: content_type,
          suspect: suspect,
          warnings: warnings
        )

        new(
          url: url,
          final_url: final_url,
          html: payload["html"],
          markdown: payload["markdown"],
          metadata: metadata,
          **metadata.except(:content_url)
        )
      end

      def error(url:, warning:, message:)
        warnings = [warning.to_s.dup.freeze].freeze
        metadata = {
          content_url: url,
          content_type: "error",
          suspect: true,
          warnings: warnings,
          error_message: message,
          social_kind: nil,
          platform: nil,
          handle: nil,
          reply_count: nil,
          community: nil,
          score: nil
        }.freeze

        new(
          url: url,
          final_url: url,
          title: nil,
          byline: nil,
          excerpt: nil,
          site_name: nil,
          published_time: nil,
          canonical_url: nil,
          language: nil,
          name: nil,
          company: nil,
          location: nil,
          description: nil,
          ingredients: nil,
          instructions: nil,
          bedrooms: nil,
          bathrooms: nil,
          area_sqft: nil,
          html: nil,
          markdown: "",
          metadata: metadata,
          reader_mode: nil,
          content_type: "error",
          suspect: true,
          warnings: warnings,
          error_message: message
        )
      end

      private

      def payload_metadata(payload, canonical_url:, final_url:, content_type:, suspect:, warnings:)
        {
          title: payload["title"],
          byline: payload["byline"],
          excerpt: payload["excerpt"],
          site_name: payload["siteName"],
          published_time: payload["publishedTime"],
          canonical_url: canonical_url,
          language: payload["language"],
          name: payload["name"],
          company: payload["company"],
          location: payload["location"],
          description: payload["description"],
          ingredients: payload["ingredients"],
          instructions: payload["instructions"],
          bedrooms: payload["bedrooms"],
          bathrooms: payload["bathrooms"],
          area_sqft: payload["areaSqft"],
          content_url: final_url,
          reader_mode: payload["readerMode"],
          content_type: content_type,
          suspect: suspect,
          warnings: warnings,
          content_completeness_ratio: payload["contentCompletenessRatio"]&.to_f || 1.0,
          content_format: payload["contentFormat"],
          paywall_state: payload["paywallState"],
          price: payload["price"],
          rating: payload["rating"],
          address: payload["address"],
          social_kind: payload["socialKind"],
          platform: payload["platform"],
          handle: payload["handle"],
          reply_count: payload["replyCount"],
          community: payload["community"],
          score: payload["score"]
        }.freeze
      end
    end

    def initialize(url:, final_url:, title:, byline:, excerpt:, site_name:, published_time:,
                   canonical_url:, language:, name:, company:, location:, description:, ingredients:,
                   instructions:, bedrooms:, bathrooms:, area_sqft:, html:, markdown:, metadata:,
                   reader_mode:, content_type:, suspect:, warnings:,
                   content_completeness_ratio: 1.0, content_format: nil, paywall_state: nil,
                   price: nil, rating: nil, address: nil, social_kind: nil, platform: nil,
                   handle: nil, reply_count: nil, community: nil, score: nil, error_message: nil)
      @url = url
      @final_url = final_url
      @title = title
      @byline = byline
      @excerpt = excerpt
      @site_name = site_name
      @published_time = published_time
      @canonical_url = canonical_url
      @language = language
      @name = name
      @company = company
      @location = location
      @description = description
      @ingredients = ingredients
      @instructions = instructions
      @bedrooms = bedrooms
      @bathrooms = bathrooms
      @area_sqft = area_sqft
      @html = html
      @markdown = markdown
      @metadata = metadata.freeze
      @reader_mode = reader_mode
      @content_type = content_type
      @suspect = suspect
      @warnings = warnings.freeze
      @content_completeness_ratio = content_completeness_ratio
      @content_format = content_format&.freeze
      @paywall_state = paywall_state&.freeze
      @price = price
      @rating = rating
      @address = address
      @social_kind = social_kind
      @platform = platform
      @handle = handle
      @reply_count = reply_count
      @community = community
      @score = score
      @error_message = error_message
    end

    def to_h
      {
        url: url,
        final_url: final_url,
        title: title,
        byline: byline,
        excerpt: excerpt,
        site_name: site_name,
        published_time: published_time,
        canonical_url: canonical_url,
        language: language,
        name: name,
        company: company,
        location: location,
        description: description,
        ingredients: ingredients,
        instructions: instructions,
        bedrooms: bedrooms,
        bathrooms: bathrooms,
        area_sqft: area_sqft,
        html: html,
        markdown: markdown,
        metadata: metadata,
        reader_mode: reader_mode,
        content_type: content_type,
        suspect: suspect,
        warnings: warnings,
        content_completeness_ratio: content_completeness_ratio,
        content_format: content_format,
        paywall_state: paywall_state,
        price: price,
        rating: rating,
        address: address,
        social_kind: social_kind,
        platform: platform,
        handle: handle,
        reply_count: reply_count,
        community: community,
        score: score,
        error_message: error_message
      }
    end
  end
end
