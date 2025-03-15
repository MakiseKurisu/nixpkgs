{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.pico-remote-play-assistant;
in
{
  meta.maintainers = [ lib.maintainers.MakiseKurisu ];

  options = {
    services.pico-remote-play-assistant = {
      enable = lib.mkEnableOption ''
        PICO Remote Play Assistant with xpra remote access
      '';

      package = lib.mkPackageOption pkgs "pico-remote-play-assistant" { };

      openFirewall = lib.mkEnableOption ''
        firewall passthrough for PICO Remote Play Assistant
      '';

      cjkfonts = lib.mkEnableOption ''
        additional CJK fonts support
      '';

      xpra = {
        package = lib.mkPackageOption pkgs "xpra" { };

        openFirewall = lib.mkEnableOption ''
          firewall passthrough for PICO Remote Play Assistant's Xpra interface
        '';

        listenAddress = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
          example = "::";
          description = "The IP address on which xpra will listen.";
        };

        port = lib.mkOption {
          type = lib.types.port;
          default = 14500;
          description = "The port on which xpra will listen.";
        };

        auth = lib.mkOption {
          type = lib.types.str;
          default = "pam";
          example = "password:value=mysecret";
          description = "Authentication to use when connecting to xpra.";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    networking.firewall.allowedUDPPorts = [] ++
      lib.optionals cfg.openFirewall [ 1900 ];  # SSDP service discovery

    networking.firewall.allowedTCPPorts = [] ++
      lib.optionals cfg.openFirewall [ 9000 ] ++  # PICO service port
      lib.optionals cfg.xpra.openFirewall [ cfg.xpra.port ];

    systemd.services.pico-remote-play-assistant = {
      description = "Screencast from your devices without occupying storage space on your PICO headset";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      path = [
        # Necessary to have desktop entry working
        cfg.package
      ];
      environment = {
        XPRA_PAM_CHECK_ACCOUNT = "yes";
        # Must be defined or won't boot
        XPRA_SOCKET_DIRS = "/var/run/pico-remote-play-assistant/xpra";
        # Applications that can be launched in Xpra
        XPRA_MENU_LOAD_APPLICATIONS = pkgs.linkFarm "pico-remote-play-assistant-xpra-applications" [
          {
            name = "pico-remote-play-assistant.desktop";
            path = "${cfg.package}/share/applications/pico-remote-play-assistant.desktop";
          }
          {
            name = "winetricks.desktop";
            path = pkgs.makeDesktopItem {
              name = "winetricks";
              desktopName = "Winetricks";
              exec = pkgs.writeShellScript "winetricks" ''
                export PATH=${pkgs.wineWow64Packages.stable}/bin:${pkgs.gnutar}/bin:$PATH
                export WINEPREFIX=/var/lib/pico-remote-play-assistant/wine
                export HOME=/var/run/pico-remote-play-assistant

                ${lib.getExe pkgs.winetricks}
              '';
              type = "Application";
              categories = [ "Utility" ];
            } + "/share/applications/winetricks.desktop";
          }
        ];
        # Must be defined or won't load applications
        XDG_CONFIG_DIRS = pkgs.linkFarm "pico-remote-play-assistant-xpra-applications-menu" [
          {
            name = "menus/applications.menu";
            path = pkgs.writeText "applications.menu" ''
              <!DOCTYPE Menu PUBLIC "-//freedesktop//DTD Menu 1.0//EN"
              "http://www.freedesktop.org/standards/menu-spec/menu-1.0.dtd">
              <Menu>
              </Menu>
            '';
          }
        ];
        # Persistent service state
        PICO_REPOTE_PLAY_ASSISTANT_HOME = "/var/lib/pico-remote-play-assistant";
      };
      serviceConfig = {
        DynamicUser = true;
        StateDirectory = "pico-remote-play-assistant";
        RuntimeDirectory = "pico-remote-play-assistant";
        Restart = "always";
        # When you close Pico, the application will ask for confirmation,
        # blocking the execution
        TimeoutStopSec = "5";
        TimeoutStopFailureMode = "kill";
        # Default timeout of 90 seconds is too little for CJK set up.
        # Disable it.
        TimeoutStartSec = lib.optionalString cfg.cjkfonts "infinity";
      };
      preStart = ''
        export PATH=${pkgs.wineWow64Packages.stable}/bin:$PATH
        export WINEDLLOVERRIDES="mscoree=" # disable mono
        export WINEPREFIX=/var/lib/pico-remote-play-assistant/wine
        export HOME=/var/run/pico-remote-play-assistant

        if [ ! -d "$WINEPREFIX" ] ; then
          mkdir -p "$WINEPREFIX"
        fi
      '' +
      lib.optionalString cfg.cjkfonts ''
        if [ ! -f "$WINEPREFIX/drive_c/windows/Fonts/unifont.ttf" ] ; then
          echo "Installing CJK fonts..."
          export PATH=${pkgs.iconv}/bin:$PATH
          ${lib.getExe pkgs.winetricks} -q cjkfonts
        fi
      '';
      script = ''
        ${lib.getExe cfg.xpra.package} start :${builtins.toString cfg.xpra.port} \
          --daemon=off \
          --minimal=yes \
          --ssl-upgrade=yes \
          --websocket-upgrade=yes \
          --ssh-upgrade=yes \
          --rfb-upgrade=yes \
          --rdp-upgrade=yes \
          --bind-tcp=${cfg.xpra.listenAddress}:${builtins.toString cfg.xpra.port},auth=${cfg.xpra.auth} \
          --start-new-commands=yes \
          --start=${lib.getExe cfg.package}
      '';
    };
  };
}
