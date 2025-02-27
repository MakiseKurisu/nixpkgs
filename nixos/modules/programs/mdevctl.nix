{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.programs.mdevctl;
in
{
  options.programs.mdevctl = {
    enable = lib.mkEnableOption "Mediated Device Management";
  };

  config = lib.mkIf cfg.enable {
    services.udev.packages = [ pkgs.mdevctl ];
    environment.systemPackages = [ pkgs.mdevctl ];

    environment.etc."mdevctl.d/.keep".text = "";
    environment.etc."mdevctl/scripts.d/notifiers/.keep".text = "";
    environment.etc."mdevctl/scripts.d/callouts/.keep".text = "";

  };
}
