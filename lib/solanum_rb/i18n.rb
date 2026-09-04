# frozen_string_literal: true

require_relative 'paths'

module SolanumRb
  # Upstream links against gettext. There is no gettext binding in the Ruby
  # GTK stack, so this reads the same `po/*.po` files directly — the catalogue
  # is thirty strings, which is far cheaper than a msgfmt build step plus a
  # runtime MO reader.
  module I18n
    # gettext addresses a contextual entry by context and msgid joined by EOT.
    CONTEXT_SEPARATOR = "\u0004"

    module_function

    # Translate, falling back to the untranslated string. Named `_` so call
    # sites read the way gettext's do.
    def _(text)
      catalogue.fetch(text, text)
    end

    # Translate within a context, the way gettext's `C_`/`pgettext` do.
    def p_(context, text)
      catalogue.fetch(key(context, text), text)
    end

    # Upstream's runtime strings have a single positional slot, spelled `{}`.
    def f_(text, value) = _(text).sub('{}', value.to_s)

    def key(context, text) = "#{context}#{CONTEXT_SEPARATOR}#{text}"

    def catalogue
      @catalogue ||= load_catalogue
    end

    # Reset between tests, or after changing the environment.
    def reset!
      @catalogue = nil
      @language = nil
    end

    # The first locale from the environment that we actually ship a catalogue
    # for. `C` and `POSIX` mean "no translation", so they resolve to nothing.
    def language
      @language ||= candidates.find { |lang| File.exist?(po_path(lang)) }
    end

    def candidates
      locales.flat_map { |locale| [locale, locale.split('_').first] }
             .reject { |lang| %w[C POSIX].include?(lang) }
             .uniq
    end

    def locales
      %w[LANGUAGE LC_ALL LC_MESSAGES LANG]
        .filter_map { |var| ENV.fetch(var, nil) }
        .reject(&:empty?)
        .flat_map { |value| value.split(':') }
        .map { |value| value.split(/[.@]/).first }
    end

    def po_path(lang) = File.join(Paths.po_dir, "#{lang}.po")

    def load_catalogue
      case language
      when nil then {}
      else parse_po(po_path(language))
      end
    end

    # A deliberately small PO parser: msgctxt/msgid/msgstr entries with
    # continuation lines. Fuzzy entries are dropped the way gettext drops them.
    def parse_po(path)
      {}.tap do |catalogue|
        entry = new_entry

        File.foreach(path) do |line|
          entry = consume(catalogue, entry, line.chomp)
        end

        store(catalogue, entry)
      end
    end

    def new_entry
      { msgctxt: +'', msgid: +'', msgstr: +'', spill: +'', field: nil, fuzzy: false }
    end

    # `spill` collects the parts of an entry we keep but do not use, so that
    # their continuation lines do not land on a field that matters.
    def consume(catalogue, entry, line)
      case line
      when /\A#,.*\bfuzzy\b/ then entry.merge(fuzzy: true)
      when /\A#/ then entry
      when /\A\s*\z/ then flush(catalogue, entry)
      when /\Amsgctxt\s+"(.*)"\z/ then set_field(restart(catalogue, entry), :msgctxt, Regexp.last_match(1))
      when /\Amsgid\s+"(.*)"\z/ then set_field(restart(catalogue, entry), :msgid, Regexp.last_match(1))
      # Every plural msgid in this catalogue has an identical msgid_plural, so
      # the singular translation covers both and the other forms are dropped.
      # ponytail: msgstr[0] only, no Plural-Forms evaluation. Add one if a
      # string ever needs genuinely different singular and plural text.
      when /\Amsgid_plural\s+"(.*)"\z/ then set_field(entry, :spill, Regexp.last_match(1))
      when /\Amsgstr\[0\]\s+"(.*)"\z/ then set_field(entry, :msgstr, Regexp.last_match(1))
      when /\Amsgstr\[\d+\]\s+"(.*)"\z/ then set_field(entry, :spill, Regexp.last_match(1))
      when /\Amsgstr\s+"(.*)"\z/ then set_field(entry, :msgstr, Regexp.last_match(1))
      when /\A"(.*)"\z/ then append(entry, Regexp.last_match(1))
      else entry
      end
    end

    def flush(catalogue, entry)
      store(catalogue, entry)
      new_entry
    end

    def set_field(entry, field, text) = entry.merge(field: field, field => unescape(text))

    # A bare `msgctxt`/`msgid` after a completed entry starts the next one,
    # since PO files are not required to separate entries with a blank line.
    # The match text stays at the call site: `Regexp.last_match` is scoped to
    # the frame that ran the match, so a callee would only ever see nil.
    def restart(catalogue, entry)
      case entry[:field]
      when :msgstr, :spill
        store(catalogue, entry)
        new_entry
      else entry
      end
    end

    def append(entry, text)
      case entry[:field]
      when nil then entry
      else entry.merge(entry[:field] => entry[entry[:field]] + unescape(text))
      end
    end

    def store(catalogue, entry)
      usable = !entry[:fuzzy] && !entry[:msgid].empty? && !entry[:msgstr].empty?

      case usable
      when true then catalogue[catalogue_key(entry)] = entry[:msgstr]
      end
    end

    def catalogue_key(entry)
      case entry[:msgctxt].empty?
      when true then entry[:msgid]
      else key(entry[:msgctxt], entry[:msgid])
      end
    end

    def unescape(text)
      text.gsub(/\\(.)/) do
        case Regexp.last_match(1)
        when 'n' then "\n"
        when 't' then "\t"
        else Regexp.last_match(1)
        end
      end
    end
  end
end
