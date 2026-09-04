# frozen_string_literal: true

# Stands in for meson's `i18n.merge_file`: substitutes the application id and
# name suffix into the desktop and metainfo templates and folds every shipped
# translation back into them, so the app's name, keywords, summary and
# description are localised in the shell and in the software centre.
#
#   ruby scripts/merge_translations.rb [output-directory]

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'fileutils'

require 'solanum_rb/config'
require 'solanum_rb/i18n'
require 'solanum_rb/paths'

module MergeTranslations
  # The keys GNU `msgfmt --desktop` localises, of the ones this file uses.
  DESKTOP_KEYS = %w[Name GenericName Comment Keywords].freeze

  # The appstream elements `msgfmt --xml` localises, per the shared ITS rules.
  # `developer > name` is covered by the same element name.
  XML_ELEMENTS = %w[name summary p li caption].freeze

  # One translatable element, opening tag to closing tag. `/m` so that a
  # `<p>` broken across lines — which is how the description is written —
  # matches as one element, the way msgfmt sees it.
  ELEMENT = %r{^([ \t]*)<(#{XML_ELEMENTS.join('|')})>(.*?)</\2>[ \t]*\n}m

  module_function

  def catalogues
    @catalogues ||= languages.to_h { |lang| [lang, SolanumRb::I18n.parse_po(po_path(lang))] }
                             .reject { |_lang, catalogue| catalogue.empty? }
  end

  def languages
    File.readlines(File.join(SolanumRb::Paths.po_dir, 'LINGUAS'), encoding: 'UTF-8')
        .map(&:strip)
        .reject { |line| line.empty? || line.start_with?('#') }
        .select { |lang| File.exist?(po_path(lang)) }
  end

  def po_path(lang) = File.join(SolanumRb::Paths.po_dir, "#{lang}.po")

  def substitute(template)
    template.gsub('@APP_ID@', SolanumRb::Config.app_id)
            .gsub('@NAME_SUFFIX@', SolanumRb::Config.name_suffix)
  end

  # --- Desktop entry --------------------------------------------------------

  # Each translatable key gains one `Key[lang]=value` line per language, in the
  # order the LINGUAS file lists them. The value looked up is the untranslated
  # one from the template, so the name suffix is substituted after the lookup.
  def desktop(template)
    template.lines.flat_map { |line| desktop_lines(line) }.join.then { |text| substitute(text) }
  end

  def desktop_lines(line)
    line.match(/\A([A-Za-z-]+)=(.*)\n?\z/).then do |match|
      case match && DESKTOP_KEYS.include?(match[1])
      when true then [line, *translated_desktop_lines(match[1], match[2])]
      else [line]
      end
    end
  end

  def translated_desktop_lines(key, value)
    lookup_key(value).then do |msgid|
      catalogues.filter_map do |lang, catalogue|
        catalogue[msgid].then do |translation|
          case translation
          when nil then nil
          else "#{key}[#{lang}]=#{translation}#{suffix_of(value)}\n"
          end
        end
      end
    end
  end

  # --- Metainfo -------------------------------------------------------------

  # Each translatable element gains one `xml:lang`-qualified sibling per
  # language, indented to match, the way `msgfmt --xml` emits them.
  def metainfo(template)
    template.gsub(ELEMENT) { merged_element(Regexp.last_match) }
            .then { |text| substitute(text) }
  end

  def merged_element(match)
    [
      match[0],
      *translated_metainfo_lines(match[1], match[2], collapse(match[3])),
    ].join
  end

  # msgfmt keys a multi-line element on its text with whitespace collapsed to
  # single spaces, which is how the msgid is written in the PO files.
  def collapse(text) = text.split.join(' ')

  def translated_metainfo_lines(indent, element, text)
    lookup_key(unescape_xml(text)).then do |msgid|
      catalogues.filter_map do |lang, catalogue|
        catalogue[msgid].then do |translation|
          case translation
          when nil then nil
          else qualified(indent, element, [lang, translation + suffix_of(text)])
          end
        end
      end
    end
  end

  def qualified(indent, element, (lang, text))
    %(#{indent}<#{element} xml:lang="#{lang}">#{escape_xml(text)}</#{element}>\n)
  end

  # `@NAME_SUFFIX@` is a build-time marker, not part of the translatable
  # string, so it is stripped before the catalogue lookup and put back after.
  def lookup_key(value) = value.sub('@NAME_SUFFIX@', '')

  def suffix_of(value)
    case value.include?('@NAME_SUFFIX@')
    when true then '@NAME_SUFFIX@'
    else ''
    end
  end

  def escape_xml(text) = text.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')

  def unescape_xml(text) = text.gsub('&lt;', '<').gsub('&gt;', '>').gsub('&amp;', '&')

  # --- Entry point ----------------------------------------------------------

  def run(output_dir)
    FileUtils.mkdir_p(output_dir)
    app_id = SolanumRb::Config.app_id

    {
      "#{app_id}.desktop"      => [desktop_template, method(:desktop)],
      "#{app_id}.metainfo.xml" => [metainfo_template, method(:metainfo)],
    }.each do |name, (template, merge)|
      File.join(output_dir, name).tap do |path|
        File.write(path, merge.call(File.read(template, encoding: 'UTF-8')), encoding: 'UTF-8')
        puts "wrote #{path} (#{catalogues.length} languages)"
      end
    end
  end

  def data_dir = SolanumRb::Paths.data_dir

  def desktop_template = File.join(data_dir, 'org.gnome.Solanum.Rb.desktop.in')

  def metainfo_template = File.join(data_dir, 'org.gnome.Solanum.Rb.metainfo.xml.in')
end

MergeTranslations.run(ARGV.fetch(0, SolanumRb::Paths.generated_dir))
