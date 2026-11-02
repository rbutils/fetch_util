# frozen_string_literal: true

module FetchUtil
  # Classification evidence only; the original payload remains the published result.
  class MarkdownEvidence
    EMPTY_ANCHOR = %r{\G<a((?:[ \t]+(?:id|name)[ \t]*=[ \t]*(?:"[^"\r\n]*"|'[^'\r\n]*'))+)[ \t]*></a[ \t]*>}i
    IDENTITY_VALUE = /(?:id|name)[ \t]*=[ \t]*(?:"([^"]*)"|'([^']*)')/i
    HTML_TAG = %r{\G</?([a-z][a-z0-9:-]*)\b(?:"[^"]*"|'[^']*'|[^'">])*?>}i
    LITERAL_TAGS = %w[pre code script style textarea title xmp svg math].freeze
    LIST_MARKER = /\A([ \t]*)(?:[-+*]|\d{1,9}[.)])([ \t]+)(?=\S|\r?\n?\z)/

    def initialize(markdown)
      @markdown = markdown
      @list_indents = []
      @quote_depth = 0
      @paragraph_open = false
      @literal_until = 0
      @fence = nil
    end

    def text
      return @markdown unless @markdown.match?(/<a[ \t]/i)
      return @text if defined?(@text)

      output = String.new(encoding: @markdown.encoding)
      offset = 0
      @markdown.each_line do |line|
        output << project_line(line, offset)
        offset += line.length
      end
      @text = output
    end

    private

    def project_line(line, offset)
      return inline_projection(line, offset) if offset < @literal_until

      depth, content = quote_content(line)
      if @fence
        if depth == @fence.fetch(:quote_depth)
          closing = content.sub(/\A {0,#{@fence.fetch(:indent)}}/, "")
          character = Regexp.escape(@fence.fetch(:character))
          @fence = nil if closing.match?(/\A {0,3}#{character}{#{@fence.fetch(:length)},}[ \t]*\r?\n?\z/)
          return line
        end
        @fence = nil
      end
      if depth != @quote_depth
        @list_indents.clear
        @paragraph_open = false
        @quote_depth = depth
      end
      if content.strip.empty?
        @paragraph_open = false
        return line
      end

      indentation = columns(content[/\A[ \t]*/])
      @list_indents.pop while @list_indents.last && indentation < @list_indents.last
      base = @list_indents.last || 0
      marker = LIST_MARKER.match(content)
      indented = indentation - base >= 4 && !@paragraph_open
      if marker && !indented
        padding = columns(marker[2])
        marker_width = columns(marker[0]) - padding
        @list_indents << marker_width + (padding > 4 ? 1 : padding)
        return line if padding > 4

        fence_content = content[marker.end(0)..]
        fence_indent = @list_indents.last
      else
        return line if indented

        fence_content = content.sub(/\A {0,#{base}}/, "")
        fence_indent = base
      end
      opening = /\A {0,3}(`{3,}|~{3,})([^\r\n]*)/.match(fence_content)
      if opening && !(opening[1].start_with?("`") && opening[2].include?("`"))
        @fence = { character: opening[1][0], length: opening[1].length, indent: fence_indent, quote_depth: depth }
        @paragraph_open = false
        return line
      end

      @paragraph_open = !content.match?(/\A {0,3}(?:\#{1,6}[ \t]|(?:[-*_][ \t]*){3,}\r?\n?\z)/)
      inline_projection(line, offset)
    end

    def quote_content(line)
      content = line
      depth = 0
      while (match = /\A {0,3}>[ \t]?/.match(content))
        content = content[match.end(0)..]
        depth += 1
      end
      [depth, content]
    end

    def columns(whitespace)
      whitespace.each_char.reduce(0) { |column, character| character == "\t" ? column + 4 - column % 4 : column + 1 }
    end

    def inline_projection(line, offset)
      finish = offset + line.length
      position = offset
      output = String.new(encoding: line.encoding)
      while position < finish
        if position < @literal_until
          ending = [@literal_until, finish].min
          output << @markdown[position...ending]
          position = ending
          next
        end
        character = @markdown[position]
        if character == "\\"
          ending = [position + 2, finish].min
          output << @markdown[position...ending]
          position = ending
          next
        end
        if character == "`"
          run = /\G`+/.match(@markdown, position)[0]
          ending = code_span_end(position + run.length, run.length)
          if ending
            @literal_until = ending
            next
          end
          output << run
          position += run.length
          next
        end
        if character == "<"
          protected_end = opaque_region_end(position)
          if protected_end
            @literal_until = protected_end
            next
          end
          anchor = EMPTY_ANCHOR.match(@markdown, position)
          if anchor && anchor[1].scan(IDENTITY_VALUE).flatten.compact.any? { |value| !value.empty? }
            position = anchor.end(0)
            next
          end
          tag = HTML_TAG.match(@markdown, position)
          if tag
            @literal_until = tag.end(0)
            next
          end
        end
        output << character
        position += 1
      end
      output
    end

    def code_span_end(position, length)
      boundary = @markdown.index(/\n[ \t]*\r?\n/, position) || @markdown.length
      closing = /(?<!`)`{#{length}}(?!`)/.match(@markdown, position)
      closing.end(0) if closing && closing.begin(0) < boundary
    end

    def opaque_region_end(position)
      { "<!--" => "-->", "<![CDATA[" => "]]>", "<?" => "?>" }.each do |opening, closing|
        next unless @markdown[position, opening.length] == opening

        ending = @markdown.index(closing, position + opening.length)
        return ending ? ending + closing.length : @markdown.length
      end
      tag = HTML_TAG.match(@markdown, position)
      return unless tag && !tag[0].start_with?("</") && !tag[0].end_with?("/>")
      return unless LITERAL_TAGS.include?(tag[1].downcase)

      return nested_literal_end(tag) if %w[pre code svg math].include?(tag[1].downcase)

      closing = %r{</#{Regexp.escape(tag[1])}[ \t\r\n]*>}i.match(@markdown, tag.end(0))
      closing ? closing.end(0) : @markdown.length
    end

    def nested_literal_end(opening)
      depth = 1
      position = opening.end(0)
      pattern = %r{</?#{Regexp.escape(opening[1])}\b}i
      while (candidate = pattern.match(@markdown, position))
        tag = HTML_TAG.match(@markdown, candidate.begin(0))
        unless tag
          position = candidate.end(0)
          next
        end
        depth -= 1 if tag[0].start_with?("</")
        depth += 1 unless tag[0].start_with?("</") || tag[0].end_with?("/>")
        return tag.end(0) if depth.zero?

        position = tag.end(0)
      end
      @markdown.length
    end
  end
end
