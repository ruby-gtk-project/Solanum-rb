# frozen_string_literal: true

require 'gtk4'
require 'adwaita'

require_relative 'i18n'
require_relative 'settings'

module SolanumRb
  # Session lengths, the long-break interval and the fullscreen switch. Every
  # row is bound straight to its GSettings key, so there is nothing to apply
  # and nothing to cancel — which is why upstream has no buttons here either.
  #
  # Upstream subclasses AdwPreferencesWindow; that is deprecated in libadwaita
  # 1.6, and AdwPreferencesDialog is the same page inside the parent window.
  class PreferencesDialog
    include I18n

    LOWER = 1
    UPPER = 99
    STEP = 1

    # Settings key => the row method that shows it, and the row property that
    # carries the value.
    BINDINGS = {
      'lap-length'                => %i[lap_row value],
      'short-break-length'        => %i[short_break_row value],
      'long-break-length'         => %i[long_break_row value],
      'sessions-until-long-break' => %i[session_count_row value],
      'fullscreen-break'          => %i[fullscreen_row active],
    }.freeze

    def build
      dialog.tap do |dlg|
        dlg.add(page)

        page.tap do |pg|
          pg.add(length_group)
          pg.add(session_group)
          pg.add(fullscreen_group)

          length_group.tap do |group|
            group.add(lap_row)
            group.add(short_break_row)
            group.add(long_break_row)
          end

          session_group.add(session_count_row)
          fullscreen_group.add(fullscreen_row)
        end

        bind_settings
      end
    end

    def present(parent) = dialog.present(parent)

    # GSettings stores the lengths as uint32 and AdwSpinRow's `value` is a
    # double; the default binding maps between the two, so no custom mapping
    # is needed.
    def bind_settings
      BINDINGS.each do |key, (row, property)|
        settings.bind(
          key,
          send(row),
          property.to_s,
          :default,
        )
      end
    end

    def dialog
      @dialog ||= Adwaita::PreferencesDialog.new.tap do |dlg|
        dlg.search_enabled = false
      end
    end

    def page = @page ||= Adwaita::PreferencesPage.new

    def length_group
      @length_group ||= Adwaita::PreferencesGroup.new.tap do |group|
        group.title = _('Session Length')
        group.description = _(GROUP_DESCRIPTION)
      end
    end

    GROUP_DESCRIPTION =
      'The length of each session type in minutes. Changes apply to the ' \
      'next session of each type.'

    def session_group = @session_group ||= Adwaita::PreferencesGroup.new

    def fullscreen_group = @fullscreen_group ||= Adwaita::PreferencesGroup.new

    def lap_row = @lap_row ||= spin_row(_('Lap Length'))

    def short_break_row = @short_break_row ||= spin_row(_('Short Break Length'))

    def long_break_row = @long_break_row ||= spin_row(_('Long Break Length'))

    def session_count_row
      @session_count_row ||= spin_row(_('Sessions Until Long Break'))
    end

    def fullscreen_row
      @fullscreen_row ||= Adwaita::SwitchRow.new.tap do |row|
        row.title = _('Fullscreen During Breaks')
      end
    end

    # Upstream's blueprint binds every adjustment to the first one's bounds;
    # they are all 1-99 by step 1, so each row just gets its own.
    def spin_row(title)
      Adwaita::SpinRow.new(adjustment, STEP, 0).tap do |row|
        row.title = title
        row.numeric = true
      end
    end

    # value, lower, upper, step, page increment, page size.
    def adjustment
      Gtk::Adjustment.new(
        LOWER,
        LOWER,
        UPPER,
        STEP,
        0,
        0,
      )
    end

    def settings = Settings.gsettings
  end
end
