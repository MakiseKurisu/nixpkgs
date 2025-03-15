{
  stdenvNoCC,
  fetchurl,
  innoextract,
  runtimeShell,
  wineWow64Packages,
  makeDesktopItem,
  copyDesktopItems,
  lib,
}:

let
  version = "2.3.0.0";
in
stdenvNoCC.mkDerivation {
  pname = "pico-remote-play-assistant";
  inherit version;
  src = fetchurl {
    url = "https://source.picovr.com/website/feiping/RemotePlayAssistant_${version}_cn_20220802_signed.exe";
    hash = "sha256-2SRuKs5yq2ePWe6XW4mdXQbcacoZfjZ6ZJa6Kb3z8Uw=";
  };
  nativeBuildInputs = [
    copyDesktopItems
    innoextract
  ];
  unpackPhase = ''
    runHook preUnpack
    innoextract $src
    runHook postUnpack
  '';
  dontBuild = true;
  desktopItems = [
    (makeDesktopItem {
      name = "pico-remote-play-assistant";
      desktopName = "PICO Remote Play Assistant";
      exec = "pico-remote-play-assistant";
      type = "Application";
      categories = [ "Utility" ];
    })
  ];
  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin"
    cp -r ./app/* "$out/bin"

    cat << 'EOF' > "$out/bin/pico-remote-play-assistant"
    #!${runtimeShell}
    export PATH=${wineWow64Packages.stable}/bin:$PATH
    export WINEDLLOVERRIDES="mscoree=" # disable mono
    export WINEPREFIX="''${PICO_REPOTE_PLAY_ASSISTANT_HOME:-"''${XDG_DATA_HOME:-"''${HOME}/.local/share"}/pico-remote-play-assistant"}/wine"

    if [ ! -d "$WINEPREFIX" ] ; then
      mkdir -p "$WINEPREFIX"
    fi

    # For some reason, we must explicitly launch wine server for it to work
    # Can be either wineboot or wine staring another program (ex. winepath)
    ${wineWow64Packages.stable}/bin/wineboot
    ${wineWow64Packages.stable}/bin/wine "$out/bin/Seagull.exe"
    EOF

    substituteInPlace $out/bin/pico-remote-play-assistant \
      --replace-fail "\$out" "$out"

    chmod +x "$out/bin/pico-remote-play-assistant"

    runHook postInstall
  '';

  meta = {
    description = "Screencast from your devices without occupying storage space on your PICO headset";
    homepage = "https://www.picoxr.com/global/software/remote-play-assistant";
    license = lib.licenses.unfree;
    maintainers = [ lib.maintainers.MakiseKurisu ];
    mainProgram = "pico-remote-play-assistant";
    platforms = wineWow64Packages.stable.meta.platforms;
  };
}
