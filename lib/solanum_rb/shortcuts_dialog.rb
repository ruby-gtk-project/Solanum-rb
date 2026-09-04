# frozen_string_literal: true

require 'gtk4'
require 'adwaita'

require_relative 'i18n'

module SolanumRb
  # The keyboard shortcuts window behind the menu's "Keyboard Shortcuts" item.
  #
  # Upstream ships `help-overlay.blp` as a GtkShortcutsWindow, which GTK 4.22
  # deprecates and the Ruby bindings cannot construct at all
  # (`GtkWindow is not subtype of GtkShortcutsWindow`). AdwShortcutsDialog is
  # its replacement and carries the same four entries.
  class ShortcutsDialog
    include I18n

    CONTEXT = 'shortcut window'
    # F10 is GTK's own binding for a primary menu button, with no action behind
    # it, so this one row spells its accelerator out.
    MENU_ACCELERATOR = 'F10'

    def build
      dialog.tap do |dlg|
        dlg.add(general_section)

        general_section.tap do |section|
          section.add(menu_item)
          section.add(preferences_item)
          section.add(shortcuts_item)
          section.add(quit_item)
        end
      end
    end

    def present(parent) = dialog.present(parent)

    def dialog = @dialog ||= Adwaita::ShortcutsDialog.new

    def general_section
      @general_section ||= Adwaita::ShortcutsSection.new.tap do |section|
        section.title = p_(CONTEXT, 'General Shortcuts')
      end
    end

    def menu_item
      @menu_item ||= Adwaita::ShortcutsItem.new(
        p_(CONTEXT, 'Show Primary Menu'),
        MENU_ACCELERATOR,
      )
    end

    def preferences_item
      @preferences_item ||= item(p_(CONTEXT, 'Show Preferences'), 'app.preferences')
    end

    def shortcuts_item
      @shortcuts_item ||= item(p_(CONTEXT, 'Show Keyboard Shortcuts'), 'win.show-help-overlay')
    end

    def quit_item = @quit_item ||= item(p_(CONTEXT, 'Quit'), 'app.quit')

    # AdwShortcutsItem has two constructors — `(title, accelerator)` and
    # `(title, action_name)` — with identical signatures, so the Ruby bindings
    # can only ever reach the first. An action-backed row is therefore built
    # with an empty accelerator and given its action afterwards; the dialog
    # then shows whatever accelerator the application registered for it.
    def item(title, action_name)
      Adwaita::ShortcutsItem.new(title, '').tap do |row|
        row.action_name = action_name
      end
    end
  end
end
