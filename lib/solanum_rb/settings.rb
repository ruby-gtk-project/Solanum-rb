# frozen_string_literal: true

require 'gio2'

module SolanumRb
  # The app's GSettings schema. `Gio::Settings.new` aborts the process when a
  # schema is missing, which in a dev checkout means a SIGTRAP and no
  # explanation — so the schema is looked up first and the failure is a plain
  # Ruby error naming the fix.
  module Settings
    SCHEMA_ID = 'org.gnome.Solanum.Rb'

    # Raised when the compiled schema is not on XDG_DATA_DIRS.
    class SchemaMissing < RuntimeError; end

    module_function

    def gsettings = @gsettings ||= Gio::Settings.new(schema_id)

    # Reset between tests, after pointing GSETTINGS_BACKEND somewhere else.
    def reset!
      @gsettings = nil
    end

    def schema_id
      case installed?
      when true then SCHEMA_ID
      else raise(SchemaMissing, missing_message)
      end
    end

    def installed?
      !Gio::SettingsSchemaSource.default.lookup(SCHEMA_ID, true).nil?
    end

    def missing_message
      "GSettings schema #{SCHEMA_ID} is not installed. In a checkout, run " \
        "`rake schema` to compile data/#{SCHEMA_ID}.gschema.xml into build/, " \
        'which the dev shell puts on XDG_DATA_DIRS.'
    end
  end
end
