{
  description = "Quickshell desktop shell - Nix packaging";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    quickshell-src = {
      url = "github:StatIndet/quickshell";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, quickshell-src }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      lib = pkgs.lib;
      qt6 = pkgs.qt6;

      cava-lib = pkgs.stdenv.mkDerivation {
        pname = "cava-lib";
        version = "0.10.7";

        src = pkgs.fetchFromGitHub {
          owner = "karlstav";
          repo = "cava";
          rev = "0.10.7";
          hash = "sha256-eOGUDGGlja5Cq8XTJFRqyP6qyaoxOJm09vZrlk4KS9k=";
        };

        nativeBuildInputs = with pkgs; [ pkg-config ];
        buildInputs = with pkgs; [ fftw ];

        dontConfigure = true;

        buildPhase = ''
          $CC -c -fPIC -O2 -std=c99 cavacore.c -I. \
            $(pkg-config --cflags fftw3) -o cavacore.o

          $CC -shared -o libcava.so cavacore.o \
            $(pkg-config --libs fftw3)
        '';

        installPhase = ''
          install -Dm755 libcava.so $out/lib/libcava.so
          install -Dm644 cavacore.h $out/include/cava/cavacore.h
          mkdir -p $out/lib/pkgconfig
          cat > $out/lib/pkgconfig/cava.pc << EOF
Name: cava
Description: Cava audio visualizer library
Version: 0.10.7
Libs: -L$out/lib -lcava
Cflags: -I$out/include/cava
Requires: fftw3
EOF
        '';

        meta = {
          description = "libcava - audio visualizer library";
          platforms = lib.platforms.linux;
        };
      };

      clavis-core = pkgs.stdenv.mkDerivation {
        pname = "clavis-core";
        version = "0.1.0";
        src = "${quickshell-src}/core";

        nativeBuildInputs = with pkgs; [
          cmake
          ninja
          pkg-config
          patchelf
          qt6.qtshadertools
        ];

        buildInputs = with pkgs; [
          qt6.qtbase
          qt6.qtdeclarative
          kdePackages.qtkeychain
          pipewire
          cava-lib
          fftw
        ];

        dontWrapQtApps = true;

        cmakeFlags = [
          "-DBUILD_TESTING=OFF"
          "-DCMAKE_BUILD_TYPE=Release"
          "-DCMAKE_SKIP_BUILD_RPATH=ON"
        ];

        installPhase = ''
          runHook preInstall
          mkdir -p $out/${qt6.qtbase.qtQmlPrefix}
          for p in build .; do
            [ -f "$p/bin/key" ] && install -Dm755 "$p/bin/key" -t $out/bin
            [ -d "$p/Clavis" ] && cp -r "$p/Clavis" $out/${qt6.qtbase.qtQmlPrefix}/
            [ -d "$p/M3Shapes" ] && cp -r "$p/M3Shapes" $out/${qt6.qtbase.qtQmlPrefix}/
          done
          for p in build .; do
            [ -f "$p/plugin/m3shapes/libM3Shapes.so" ] && cp "$p/plugin/m3shapes/libM3Shapes.so" \
              $out/${qt6.qtbase.qtQmlPrefix}/M3Shapes/
          done
          find $out -name '*.so' -exec patchelf --add-rpath '$ORIGIN' {} \;
          runHook postInstall
        '';

        meta = {
          description = "ClavisCore - C++ backend plugins for Quickshell desktop shell";
          license = lib.licenses.gpl3Only;
          platforms = lib.platforms.linux;
        };
      };

      meteocons-lottie = pkgs.fetchurl {
        url = "https://registry.npmjs.org/@meteocons/lottie/-/lottie-0.1.0.tgz";
        hash = "sha256-Q+onMqvejkKcT8VqJ7ss79hT+MNKkEtX+GpLWivxoT0=";
      };

      meteocons-svg = pkgs.fetchurl {
        url = "https://registry.npmjs.org/@meteocons/svg/-/svg-0.1.0.tgz";
        hash = "sha256-kbSNH4SX2ej07R1bzDLTBqqlBQ3pnDhGfCpY963VpQE=";
      };

      quickshell-desktop = pkgs.stdenv.mkDerivation {
        pname = "quickshell-desktop";
        version = "0.1.0";

        nativeBuildInputs = with pkgs; [ makeWrapper ];

        buildInputs = with pkgs; [ quickshell ];

        dontUnpack = true;
        dontConfigure = true;
        dontBuild = true;

        installPhase = ''
          mkdir -p $out/share/quickshell
          cp -r ${quickshell-src}/* $out/share/quickshell/
          chmod -R +w $out/share/quickshell
          rm -rf $out/share/quickshell/core
          rm -f $out/share/quickshell/.gitignore
          mkdir -p $out/share/quickshell/assets/icons/weather/meteocons/lottie
          tar xzf ${meteocons-lottie} -C $out/share/quickshell/assets/icons/weather/meteocons/lottie \
            --strip-components=1 --wildcards 'package/fill/*' 'package/flat/*' 'package/line/*' 'package/monochrome/*'
          mkdir -p $out/share/quickshell/assets/icons/weather/meteocons/svg
          tar xzf ${meteocons-svg} -C $out/share/quickshell/assets/icons/weather/meteocons/svg \
            --strip-components=1 --wildcards 'package/fill/*' 'package/flat/*' 'package/line/*' 'package/monochrome/*'

          mkdir -p $out/bin
          mkdir -p $out/etc
          cat > $out/etc/fonts.conf << EOF
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <include ignore_missing="yes">/etc/fonts/fonts.conf</include>
  <dir>${pkgs.material-symbols}/share/fonts</dir>
</fontconfig>
EOF
          # Patch MaterialSymbol.qml to enable OpenType ligatures and use QtRendering
          sed -i 's/renderType: Text.NativeRendering/renderType: Text.QtRendering/' \
            $out/share/quickshell/Components/MaterialSymbol.qml
          sed -i '/font {/a\        features: {"rlig": true},' \
            $out/share/quickshell/Components/MaterialSymbol.qml
          makeWrapper ${lib.getExe pkgs.quickshell} $out/bin/quickshell-desktop \
            --prefix PATH : ${clavis-core}/bin \
            --prefix QML2_IMPORT_PATH : ${clavis-core}/${qt6.qtbase.qtQmlPrefix} \
            --prefix QML2_IMPORT_PATH : ${qt6.qt5compat}/${qt6.qtbase.qtQmlPrefix} \
            --prefix QML2_IMPORT_PATH : ${qt6.qtlottie}/${qt6.qtbase.qtQmlPrefix} \
            --set FONTCONFIG_FILE $out/etc/fonts.conf \
            --add-flags "-p" --add-flags "$out/share/quickshell/shell.qml"

          ln -s $out/bin/quickshell-desktop $out/bin/qs
        '';

        meta = {
          description = "Quickshell desktop shell configuration";
          longDescription = ''
            A Quickshell-based desktop shell with Bar, Keystone (Dynamic Island),
            Control Center, Launcher, Lock screen, and Sidebars.
            Built from StatIndet/quickshell.
          '';
          homepage = "https://github.com/StatIndet/quickshell";
          license = lib.licenses.gpl3Only;
          platforms = lib.platforms.linux;
          mainProgram = "quickshell-desktop";
        };
      };
    in {
      packages.${system} = {
        inherit clavis-core cava-lib meteocons-lottie meteocons-svg quickshell-desktop;
        default = quickshell-desktop;
      };

      apps.${system} = {
        default = {
          type = "app";
          program = "${quickshell-desktop}/bin/quickshell-desktop";
        };
      };

      nixosModules.default = { pkgs, ... }: {
        environment.systemPackages = [ self.packages.${pkgs.system}.default ];
        fonts.packages = [ pkgs.material-symbols ];
      };
    };
}
