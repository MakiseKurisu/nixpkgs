{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.programs.mdevctl;

  attrsWith' = placeholder: elemType: lib.types.attrsWith {
    inherit elemType placeholder;
  };

  mdevOption = {
    description = ''
      Define mdev devices.

      The first level is the parent device, which is commonly a PCIe bus
      address. This can be found with `mdevctl types`, which lists all available
      types under the parent device.

      The second level is the mdev device. It must be a **Globally Unique** ID.
      You can generate one with `uuidgen`.
    '';
    example = {
      "0000:00:00.0" = {
        "00000000-0000-0000-0000-000000000000" = {
          mdev_type = "nvidia-260";
          start = "auto";
        };
      };
    };
    default = {};
    type = attrsWith' "parent" (attrsWith' "device" (lib.types.submodule ({ name, config, ... }: {
      options.mdev_type = lib.mkOption {
        type = lib.types.str;
        example = "nvidia-260";
        description = ''
          Specify the device type.

          All supported types for a given parent device can be found with
          `mdevctl types`.
        '';
      };
      options.start = lib.mkOption {
        type = lib.types.enum [ "auto" "manual" ];
        default = "auto";
        example = "manual";
        description = ''
          Whether to start a device automatically on parent availability.

          Manual device can be started with `sudo mdevctl start -u <UUID>`.
        '';
      };
    })));
  };

  # generates a single mdev config
  mdevToConfig = parent: mdev: mdevCfg: {
    "mdevctl.d/${parent}/${mdev}".text = ''
      {
        "mdev_type": "${mdevCfg.mdev_type}",
        "start": "${mdevCfg.start}",
        "attrs": []
      }
    '';
  };
  # flattern the submodule
  mapMdevsToList = parent: mdevs: lib.mapAttrsToList (mdev: mdevCfg: (mdevToConfig parent mdev mdevCfg)) mdevs;
  mapParentsToList = parents: lib.mapAttrsToList (parent: mdevs: (mapMdevsToList parent mdevs)) parents;
  # rebuild attr list into a single attr
  mkMdevConfigs = mdevAttrs: lib.attrsets.zipAttrs (lib.lists.flatten (mapParentsToList mdevAttrs));
in
{
  options.programs.mdevctl = {
    enable = lib.mkEnableOption "Mediated Device Management";
    mdevs = lib.mkOption mdevOption;
  };

  config = lib.mkIf cfg.enable {
    services.udev.packages = [ pkgs.mdevctl ];
    environment.systemPackages = [ pkgs.mdevctl ];

    environment.etc = {
      "mdevctl.d/.keep".text = "";
      "mdevctl/scripts.d/notifiers/.keep".text = "";
      "mdevctl/scripts.d/callouts/.keep".text = "";
    } // mkMdevConfigs cfg.mdevs;
  };
}
