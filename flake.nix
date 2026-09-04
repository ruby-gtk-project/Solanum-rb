{
  description = "Solanum-rb — a Ruby GTK4 port of Solanum";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        ruby = pkgs.ruby_3_3;

        # GStreamer plays the chime and the beep. Upstream uses GstPlay; this
        # port uses the same library through the `gstreamer` gem, because
        # nixpkgs' gtk4 is built without any GtkMediaFile backend, so
        # Gtk::MediaFile would resolve to GtkNothingMedia and play silence.
        gstStack = with pkgs.gst_all_1; [
          gstreamer
          gst-plugins-base
          gst-plugins-good
        ];

        # Shared libraries every ruby-gnome extension links against.
        gtkStack = with pkgs; [
          glib
          gobject-introspection
          cairo
          pango
          gdk-pixbuf
          graphene
          atk
          gtk4
          libadwaita
          harfbuzz
          # The app icon is an SVG, and GTK loads icons through gdk-pixbuf —
          # without librsvg's loader it resolves and then paints nothing.
          librsvg
        ]
        ++ gstStack
        # The Ruby `pkg-config` gem resolves `Requires.private` transitively and
        # hard-fails if any .pc in the chain is missing, so gtk4's whole
        # private closure has to be on PKG_CONFIG_PATH, not just its public deps.
        ++ (with pkgs; [
          fontconfig
          freetype
          libepoxy
          libpng
          libxkbcommon
          pcre2
          util-linux
          wayland
          zlib
          fribidi
          libdatrie
          libthai
          libselinux
          libsepol
          expat
          brotli
          bzip2
          graphite2
          icu
          libffi
          libxml2
          lerc
          libdeflate
          xz
          zstd
          orc
          libunwind
          elfutils
        ])
        ++ (with pkgs; [
          libx11
          libxau
          libxcursor
          libxdmcp
          libxext
          libxfixes
          libxi
          libxinerama
          libxrandr
          libxrender
          libxcb
          xorgproto
        ]);

        # ruby-gnome gems build C extensions with extconf.rb + the pkg-config
        # gem; nixpkgs only ships gemConfig entries for the GTK3-era subset, so
        # the GTK4 gems get their build inputs declared here.
        rubyGnomeGem = attrs: {
          nativeBuildInputs = [ pkgs.pkg-config ];
          buildInputs = gtkStack;
        };

        gemConfig = pkgs.defaultGemConfig // {
          gdk4 = rubyGnomeGem;
          gsk4 = rubyGnomeGem;
          gtk4 = rubyGnomeGem;
          graphene1 = rubyGnomeGem;
          adwaita = rubyGnomeGem;
          gstreamer = rubyGnomeGem;
        };

        # `makeSearchPath` would take each package's *first* output, and glib's
        # first output is `bin`, which carries no typelibs — hence the explicit
        # `.out`. at-spi2-core is here for the Atk typelib.
        typelibPath = pkgs.lib.makeSearchPath "lib/girepository-1.0"
          (map (drv: drv.out or drv) (gtkStack ++ [ pkgs.at-spi2-core ]));

        gstPluginPath = pkgs.lib.makeSearchPath "lib/gstreamer-1.0"
          (map (drv: drv.out or drv) gstStack);

        gems = pkgs.bundlerEnv {
          name = "solanum-rb-gems";
          inherit ruby gemConfig;
          gemdir = ./.;
        };

        # Upstream's -Dprofile=default|development. The devel build gets its
        # own application id and icon, so it installs alongside the release
        # one, and the app stripes its window.
        solanum = { development ? false }:
          let
            appId = "org.gnome.Solanum.Rb" + (if development then ".Devel" else "");
            profile = if development then "development" else "default";
          in
          pkgs.stdenv.mkDerivation {
            pname = "solanum-rb" + (if development then "-devel" else "");
            version = "6.0.0";
            src = ./.;

            nativeBuildInputs = [ pkgs.makeWrapper gems.wrappedRuby ];
            buildInputs = [ gems ] ++ gtkStack;

            # Stands in for meson's i18n.merge_file: folds po/*.po back into
            # the desktop entry and the metainfo.
            buildPhase = ''
              runHook preBuild
              SOLANUM_RB_PROFILE=${profile} \
                ruby scripts/merge_translations.rb generated
              runHook postBuild
            '';

            installPhase = ''
              runHook preInstall

              mkdir -p $out/share/solanum-rb
              cp -r lib data po $out/share/solanum-rb/
              # bin/ has to sit next to lib/ for the launcher's require_relative.
              install -Dm755 bin/solanum-rb $out/share/solanum-rb/bin/solanum-rb

              # The generated desktop entry and metainfo. The app reads the
              # metainfo back at runtime to build its about dialog, which is
              # what SOLANUM_RB_GENERATED_DIR below points at.
              install -Dm644 generated/${appId}.desktop -t $out/share/applications
              install -Dm644 generated/${appId}.metainfo.xml -t $out/share/metainfo
              install -Dm644 generated/${appId}.metainfo.xml \
                -t $out/share/solanum-rb/generated

              install -Dm644 data/icons/hicolor/scalable/apps/${appId}.svg \
                -t $out/share/icons/hicolor/scalable/apps
              install -Dm644 data/icons/hicolor/symbolic/apps/${appId}-symbolic.svg \
                -t $out/share/icons/hicolor/symbolic/apps

              # The GSettings schema has to be compiled and on XDG_DATA_DIRS
              # before Gio::Settings will look it up. glib's setup hook then
              # relocates it to share/gsettings-schemas/$name, which is why the
              # wrapper below puts that directory on the path and not just
              # $out/share. The schema id does not carry the profile suffix —
              # upstream installs the same schema for both builds.
              install -Dm644 data/org.gnome.Solanum.Rb.gschema.xml \
                -t $out/share/glib-2.0/schemas
              ${pkgs.glib.dev}/bin/glib-compile-schemas $out/share/glib-2.0/schemas

              # -rbundler/setup puts the bundled gems on the load path, and
              # GI_TYPELIB_PATH keeps GObject-Introspection from re-registering
              # types the cairo gem's C extension has already registered.
              makeWrapper ${gems.wrappedRuby}/bin/ruby $out/bin/solanum-rb \
                --add-flags "-rbundler/setup" \
                --add-flags "$out/share/solanum-rb/bin/solanum-rb" \
                --set SOLANUM_RB_PROFILE "${profile}" \
                --set SOLANUM_RB_GENERATED_DIR "$out/share/solanum-rb/generated" \
                --set GI_TYPELIB_PATH "${typelibPath}" \
                --set GST_PLUGIN_SYSTEM_PATH_1_0 "${gstPluginPath}" \
                --set GDK_PIXBUF_MODULE_FILE "${pkgs.librsvg}/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache" \
                --prefix XDG_DATA_DIRS : "$out/share" \
                --prefix XDG_DATA_DIRS : "$out/share/gsettings-schemas/$name" \
                --prefix XDG_DATA_DIRS : "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}" \
                --prefix XDG_DATA_DIRS : "${pkgs.gtk4}/share/gsettings-schemas/${pkgs.gtk4.name}" \
                --prefix XDG_DATA_DIRS : "${pkgs.adwaita-icon-theme}/share"

              runHook postInstall
            '';
          };
      in
      {
        packages.default = solanum { };
        packages.devel = solanum { development = true; };

        apps.default = flake-utils.lib.mkApp { drv = self.packages.${system}.default; };
        apps.devel = flake-utils.lib.mkApp { drv = self.packages.${system}.devel; };

        devShells.default = pkgs.mkShell {
          name = "solanum-rb-devshell";

          packages = [
            gems
            gems.wrappedRuby
            pkgs.bundler
            pkgs.bundix
            pkgs.pkg-config
            pkgs.glib
            pkgs.desktop-file-utils
            pkgs.appstream
            pkgs.adwaita-icon-theme
            pkgs.gsettings-desktop-schemas
          ] ++ gtkStack;

          # Icons, GSettings schemas and the GTK portal all resolve through
          # XDG_DATA_DIRS; without these the window opens with blank icons and
          # Gio::Settings aborts on the app's own schema.
          shellHook = ''
            export GDK_PIXBUF_MODULE_FILE="${pkgs.librsvg}/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache"
            export GST_PLUGIN_SYSTEM_PATH_1_0="${gstPluginPath}"
            export XDG_DATA_DIRS="$PWD/build/share:${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}:${pkgs.gtk4}/share/gsettings-schemas/${pkgs.gtk4.name}:${pkgs.adwaita-icon-theme}/share:$XDG_DATA_DIRS"
            unset BUNDLE_GEMFILE BUNDLE_FROZEN BUNDLE_PATH
            echo "solanum-rb devshell — ruby $(ruby -e 'print RUBY_VERSION')"
            echo "  ./bin/solanum-rb   run the app"
            echo "  rake               test, validate + lint"
            echo "  SOLANUM_RB_PROFILE=development ./bin/solanum-rb   devel build"
          '';
        };
      });
}
