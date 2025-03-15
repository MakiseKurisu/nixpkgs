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
        PICO Remote Play Assistant with xpra-based Web UI
      '';

      package = lib.mkPackageOption pkgs "pico-remote-play-assistant" { };

      openFirewallPort = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether the listening port should be opened automatically.

          Please beaware that this only controlls for PICO Remote Play Assistant.
          Xpra needs to be configured with `services.xserver.displayManager.xpra`.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewallPort [ 9000 ];

    services.xserver.displayManager.xpra = {
      enable = true;
      extraOptions = [
        "${lib.getExe cfg.package}"
      ];
    };
  };
}
