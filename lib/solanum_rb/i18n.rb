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
    #
    # A plural entry's catalogue value is an array of forms (see
    # `plural_value`); a bare lookup through `_` has no count to pick a form
    # with, so it takes the first form, same as gettext's `gettext()` called
    # on a msgid that also has a `msgid_plural`.
    def _(text)
      singularize(catalogue.fetch(text, text))
    end

    # Translate within a context, the way gettext's `C_`/`pgettext` do.
    def p_(context, text)
      singularize(catalogue.fetch(key(context, text), text))
    end

    # Upstream's runtime strings may carry any number of positional slots,
    # all spelled `{}`. Each is filled from `values` in order, left to
    # right — the same walk as upstream's `freplace`.
    def f_(text, *values) = freplace(_(text), values)

    # Upstream's `kreplace`: named slots spelled `{name}`, each filled from
    # `kwargs` everywhere it appears in the string.
    def k_(text, **kwargs) = kreplace(_(text), kwargs)

    # Upstream's `ni18n`/`ngettext`: picks the singular or plural form by
    # `number`, using the catalogue's own plural rule (parsed from the
    # `Plural-Forms` header) rather than assuming English's "singular iff 1".
    # Falls back to English's rule when the catalogue has no entry at all.
    def ni18n(single, multiple, number)
      plural_lookup(catalogue[single], single, multiple, number)
    end

    def ni18n_f(single, multiple, number, *values) = freplace(ni18n(single, multiple, number), values)

    def ni18n_k(single, multiple, number, **kwargs) = kreplace(ni18n(single, multiple, number), kwargs)

    # Upstream's `pi18n`/`pgettext` with placeholders — `p_` plus freplace or
    # kreplace, the same relationship `f_`/`k_` have to `_`.
    def pi18n_f(context, text, *values) = freplace(p_(context, text), values)

    def pi18n_k(context, text, **kwargs) = kreplace(p_(context, text), kwargs)

    # Upstream's `pni18n`/`npgettext`: plural dispatch within a context.
    def pni18n(context, single, multiple, number)
      plural_lookup(catalogue[key(context, single)], single, multiple, number)
    end

    def pni18n_f(context, single, multiple, number, *values)
      freplace(pni18n(context, single, multiple, number), values)
    end

    def pni18n_k(context, single, multiple, number, **kwargs)
      kreplace(pni18n(context, single, multiple, number), kwargs)
    end

    def key(context, text) = "#{context}#{CONTEXT_SEPARATOR}#{text}"

    # A catalogue value is either a plain translated string, or — for an
    # entry that had a `msgid_plural` — an array of forms indexed the way
    # `msgstr[N]` indexes them. A lookup with no count takes the first form.
    def singularize(value)
      case value
      when Array then value.first
      else value
      end
    end

    def freplace(text, values)
      index = 0
      text.gsub('{}') do
        value = values[index]
        index += 1
        value.to_s
      end
    end

    def kreplace(text, kwargs)
      kwargs.reduce(text) do |string, (name, value)|
        string.gsub("{#{name}}", value.to_s)
      end
    end

    # Shared by `ni18n` and `pni18n`: `entry` is whatever the catalogue held
    # at the looked-up key (an array of forms, a bare string from a
    # catalogue that disagrees about plurality, or nil when untranslated).
    def plural_lookup(entry, single, multiple, number)
      case entry
      when Array then entry[plural_index(number)] || entry.first || default_plural(single, multiple, number)
      else default_plural(single, multiple, number)
      end
    end

    # gettext's own fallback when a msgid has no translation at all: English
    # has exactly two forms, singular iff the count is 1.
    def default_plural(single, multiple, number) = number == 1 ? single : multiple

    # The index into a catalogue entry's plural-forms array for `number`,
    # per the loaded catalogue's own `Plural-Forms` header — not English's
    # rule. Four shipped locales (ca, fur, oc, pt_BR) have genuinely
    # different singular/plural wording for at least one msgid, so reading
    # msgstr[0] unconditionally renders the wrong grammatical number on every
    # locale whose plural rule differs from English's.
    def plural_index(number)
      rule = plural_rule
      rule[:proc].call(number.to_i).clamp(0, rule[:nplurals] - 1)
    rescue StandardError
      default_plural(0, 1, number)
    end

    # Parsed once per loaded catalogue from the header entry's `Plural-Forms`
    # line (msgid "", stored like any other entry). No header, or no
    # catalogue at all (the `C`/`POSIX` locales), means English's rule.
    def plural_rule
      @plural_rule ||= parse_plural_forms(singularize(catalogue['']))
    end

    ENGLISH_PLURAL_RULE = { nplurals: 2, proc: ->(n) { n == 1 ? 0 : 1 } }.freeze

    def parse_plural_forms(header)
      match = header.to_s.match(/Plural-Forms:\s*nplurals\s*=\s*(\d+)\s*;\s*plural\s*=\s*([^;\n]+);/)
      case match
      when nil then ENGLISH_PLURAL_RULE
      else { nplurals: match[1].to_i, proc: PluralExpr.compile(match[2]) }
      end
    end

    def catalogue
      @catalogue ||= load_catalogue
    end

    # Reset between tests, or after changing the environment.
    def reset!
      @catalogue = nil
      @language = nil
      @plural_rule = nil
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
    #
    # The encoding is named explicitly: PO files are UTF-8, but Ruby reads
    # them in the ambient one, which is US-ASCII under a C locale — so
    # `LANG=C LANGUAGE=fr`, or any process with no locale set at all, would
    # otherwise raise on the first accented character.
    def parse_po(path)
      {}.tap do |catalogue|
        entry = new_entry

        File.foreach(path, encoding: 'UTF-8') do |line|
          entry = consume(catalogue, entry, line.chomp)
        end

        store(catalogue, entry)
      end
    end

    # `msgstrs` collects every `msgstr[N]` (or the bare `msgstr` of a
    # non-plural entry, stored under index 0), so a plural entry's forms are
    # all kept, not just the first.
    def new_entry
      { msgctxt: +'', msgid: +'', msgid_plural: +'', msgstrs: {}, field: nil, fuzzy: false }
    end

    def consume(catalogue, entry, line)
      case line
      when /\A#,.*\bfuzzy\b/ then entry.merge(fuzzy: true)
      when /\A#/ then entry
      when /\A\s*\z/ then flush(catalogue, entry)
      when /\Amsgctxt\s+"(.*)"\z/ then set_field(restart(catalogue, entry), :msgctxt, Regexp.last_match(1))
      when /\Amsgid\s+"(.*)"\z/ then set_field(restart(catalogue, entry), :msgid, Regexp.last_match(1))
      when /\Amsgid_plural\s+"(.*)"\z/ then set_field(entry, :msgid_plural, Regexp.last_match(1))
      when /\Amsgstr\[(\d+)\]\s+"(.*)"\z/ then set_msgstr(entry, Regexp.last_match(1).to_i, Regexp.last_match(2))
      when /\Amsgstr\s+"(.*)"\z/ then set_msgstr(entry, 0, Regexp.last_match(1))
      when /\A"(.*)"\z/ then append(entry, Regexp.last_match(1))
      else entry
      end
    end

    def flush(catalogue, entry)
      store(catalogue, entry)
      new_entry
    end

    def set_field(entry, field, text) = entry.merge(field: field, field => unescape(text))

    def set_msgstr(entry, index, text)
      entry[:msgstrs][index] = unescape(text)
      entry.merge(field: [:msgstr, index])
    end

    # A bare `msgctxt`/`msgid` after a completed entry starts the next one,
    # since PO files are not required to separate entries with a blank line.
    # The match text stays at the call site: `Regexp.last_match` is scoped to
    # the frame that ran the match, so a callee would only ever see nil.
    def restart(catalogue, entry)
      case entry[:field]
      when Array
        store(catalogue, entry)
        new_entry
      else entry
      end
    end

    def append(entry, text)
      case entry[:field]
      when nil then entry
      when Array
        index = entry[:field][1]
        entry[:msgstrs][index] = entry[:msgstrs][index] + unescape(text)
        entry
      else entry.merge(entry[:field] => entry[entry[:field]] + unescape(text))
      end
    end

    def store(catalogue, entry)
      usable = !entry[:fuzzy] && !entry[:msgid].empty? && entry[:msgstrs].values.any? { |form| !form.empty? }

      case usable
      when true then catalogue[catalogue_key(entry)] = plural_value(entry)
      end
    end

    # A real `msgid_plural` keeps every form, ordered by its `msgstr[N]`
    # index, so `ni18n`/`pni18n` can pick the right one for a count. A
    # regular entry collapses to the single string it always was.
    def plural_value(entry)
      case entry[:msgid_plural].empty?
      when true then entry[:msgstrs].fetch(0, '')
      else entry[:msgstrs].sort.to_h.values
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

    # Compiles a PO header's `plural=EXPRESSION` (C syntax, the same grammar
    # gettext itself parses) into a Ruby proc of `n`. A hand-written
    # recursive-descent parser rather than `eval` — the expression comes
    # from a file on disk, not a trusted literal, so it should not run
    # through Ruby's own evaluator.
    class PluralExpr
      TOKEN = /\s*(<=|>=|==|!=|&&|\|\||[()?:<>!+\-*%\/]|\d+|n)/

      def self.compile(source) = new(source).parse

      def initialize(source)
        @tokens = source.scan(TOKEN).flatten
        @pos = 0
      end

      def parse
        expr = ternary
        ->(n) { expr.call(n) }
      end

      private

      def peek = @tokens[@pos]

      def take
        token = @tokens[@pos]
        @pos += 1
        token
      end

      def ternary
        condition = logic_or
        case peek
        when '?'
          take
          if_true = ternary
          take # ':'
          if_false = ternary
          ->(n) { truthy(condition.call(n)) ? if_true.call(n) : if_false.call(n) }
        else condition
        end
      end

      def logic_or
        left = logic_and
        while peek == '||'
          take
          right = logic_and
          left = bool_op(left, right) { |a, b| a || b }
        end
        left
      end

      def logic_and
        left = equality
        while peek == '&&'
          take
          right = equality
          left = bool_op(left, right) { |a, b| a && b }
        end
        left
      end

      def equality
        left = relational
        while %w[== !=].include?(peek)
          op = take
          right = relational
          left = compare_op(left, right, op)
        end
        left
      end

      def relational
        left = additive
        while %w[< <= > >=].include?(peek)
          op = take
          right = additive
          left = compare_op(left, right, op)
        end
        left
      end

      def additive
        left = multiplicative
        while %w[+ -].include?(peek)
          op = take
          right = multiplicative
          left = op == '+' ? arith_op(left, right) { |a, b| a + b } : arith_op(left, right) { |a, b| a - b }
        end
        left
      end

      def multiplicative
        left = unary
        while %w[* / %].include?(peek)
          op = take
          right = unary
          left = arith_op(left, right) { |a, b| op == '*' ? a * b : (op == '/' ? a / b : a % b) }
        end
        left
      end

      def unary
        case peek
        when '!'
          take
          operand = unary
          ->(n) { truthy(operand.call(n)) ? 0 : 1 }
        else primary
        end
      end

      def primary
        case peek
        when '('
          take
          inner = ternary
          take # ')'
          inner
        when 'n'
          take
          ->(n) { n }
        else
          value = take.to_i
          ->(_n) { value }
        end
      end

      def truthy(value) = value != 0

      def bool_op(left, right)
        ->(n) { yield(truthy(left.call(n)), truthy(right.call(n))) ? 1 : 0 }
      end

      def compare_op(left, right, op)
        ->(n) do
          a = left.call(n)
          b = right.call(n)
          case op
          when '==' then a == b
          when '!=' then a != b
          when '<' then a < b
          when '<=' then a <= b
          when '>' then a > b
          when '>=' then a >= b
          end ? 1 : 0
        end
      end

      def arith_op(left, right)
        ->(n) { yield(left.call(n), right.call(n)) }
      end
    end
  end
end
