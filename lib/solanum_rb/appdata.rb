# frozen_string_literal: true

require_relative 'config'

module SolanumRb
  # The fields `adw_about_dialog_new_from_appdata` lifts out of the metainfo.
  #
  # Upstream builds its about window from the metainfo compiled into a
  # GResource. There is no GResource here, so the same file is read off disk
  # and the same handful of elements are pulled out of it.
  #
  # ponytail: a regexp reader, not an XML parser. The file is ours, generated
  # by `rake desktop` from a template in this repo, and only its top-level
  # single-line elements and the release notes are wanted. Reach for REXML if
  # this ever has to read a metainfo file it did not write.
  class Appdata
    # Elements taken verbatim from the component, and where AdwAboutDialog puts
    # them.
    FIELDS = {
      name:           'name',
      summary:        'summary',
      license:        'project_license',
      developer_name: 'developer_name',
    }.freeze

    def initialize(path = Config.metainfo_path)
      @path = path
    end

    def available? = File.exist?(@path)

    def source
      @source ||= File.read(@path, encoding: 'UTF-8')
    end

    # Untranslated elements only: the localised siblings carry an `xml:lang`
    # attribute, and the running locale is applied by `I18n`, not by picking a
    # translated element out of the file.
    def field(key)
      source[%r{<#{FIELDS.fetch(key)}>([^<]*)</#{FIELDS.fetch(key)}>}, 1].then do |value|
        case value
        when nil then nil
        else unescape(value.strip)
        end
      end
    end

    def url(type)
      source[%r{<url type="#{type}">([^<]*)</url>}, 1]&.strip
    end

    # The description, flattened to the plain text AdwAboutDialog's `comments`
    # takes. Upstream's is a single paragraph.
    def description
      source[%r{<description>(.*?)</description>}m, 1].then do |block|
        case block
        when nil then nil
        else paragraphs(block)
        end
      end
    end

    def paragraphs(block)
      block.scan(%r{<p>(.*?)</p>}m)
           .map { |(text)| unescape(text.split.join(' ')) }
           .reject(&:empty?)
           .join("\n\n")
    end

    # The `<description>` of the release matching this build's version, as the
    # raw appstream markup AdwAboutDialog's `release_notes` expects.
    def release_notes(version = Config::BASE_VERSION)
      source[%r{<release version="#{Regexp.escape(version)}"[^>]*>\s*<description>(.*?)</description>}m, 1]
        &.strip
    end

    def unescape(text)
      text.gsub('&lt;', '<').gsub('&gt;', '>').gsub('&quot;', '"')
          .gsub('&apos;', "'").gsub('&amp;', '&')
    end
  end
end
