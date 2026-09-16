{
  lib,
  stdenv,
  fetchurl,
  appimageTools,
  makeDesktopItem,
}:
let
  pname = "github-copilot-desktop";

  versions = builtins.fromJSON (builtins.readFile ../artifacts/versions.json);
  system = stdenv.hostPlatform.system;

  platformInfo = versions."GitHub Copilot Desktop".${system} or (throw "Unsupported system for GitHub Copilot Desktop: ${system}");

  # Extract version from URL
  version = let
    match = builtins.match ".*/download/v?([0-9.]+)/.*" platformInfo.url;
  in if match != null then builtins.elemAt match 0 else "unknown";

  src = fetchurl {
    inherit (platformInfo) url;
    sha256 = platformInfo.hash;
  };

  appimageContents = appimageTools.extract {
    inherit pname version src;
  };

  desktopItem = makeDesktopItem {
    name = "github-copilot-desktop";
    exec = "github-copilot-desktop %u";
    icon = "github-copilot-desktop";
    desktopName = "GitHub Copilot";
    comment = "GitHub Copilot Desktop Application";
    categories = [ "Development" ];
    startupWMClass = "github";
    mimeTypes = [
      "x-scheme-handler/github-app"
      "x-scheme-handler/ghapp"
      "x-scheme-handler/gh"
    ];
  };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraInstallCommands = ''
    # Install icons extracted by extractType2
    mkdir -p $out/share
    if [ -d ${appimageContents}/usr/share/icons ]; then
      cp -r ${appimageContents}/usr/share/icons $out/share/
      chmod -R u+w $out/share/icons
    fi

    # Fallback pixmap icon & desktop icon
    mkdir -p $out/share/pixmaps
    if [ -f "${appimageContents}/GitHub Copilot.png" ]; then
      cp "${appimageContents}/GitHub Copilot.png" $out/share/pixmaps/github-copilot-desktop.png
      for size in 16x16 32x32 64x64 128x128 256x256; do
        mkdir -p "$out/share/icons/hicolor/$size/apps"
      done
      cp "${appimageContents}/GitHub Copilot.png" "$out/share/icons/hicolor/256x256/apps/github-copilot-desktop.png"
    fi

    # Ensure icon is available under github-copilot-desktop name
    if [ -f "$out/share/icons/hicolor/128x128/apps/github.png" ] && [ ! -f "$out/share/icons/hicolor/128x128/apps/github-copilot-desktop.png" ]; then
      cp "$out/share/icons/hicolor/128x128/apps/github.png" "$out/share/icons/hicolor/128x128/apps/github-copilot-desktop.png"
    fi

    # Install the desktop file
    mkdir -p $out/share/applications
    cp ${desktopItem}/share/applications/*.desktop $out/share/applications/

    # Also provide copilot-desktop convenience symlink
    ln -s github-copilot-desktop $out/bin/copilot-desktop
  '';

  meta = with lib; {
    description = "GitHub Copilot Desktop Application";
    homepage = "https://github.com/github/app";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" "aarch64-linux" ];
    mainProgram = "github-copilot-desktop";
  };
}
