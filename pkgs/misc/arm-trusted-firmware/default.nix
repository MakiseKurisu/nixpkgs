{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchFromGitLab,
  openssl,
  pkgsCross,
  buildPackages,

  # Dependencies for packaging U-Boot for Marvell Armada 37x0 products
  ubootESPRESSObin,

  # Warning: this blob (hdcp.bin) runs on the main CPU (not the GPU) at
  # privilege level EL3, which is above both the kernel and the
  # hypervisor.
  #
  # This parameter applies only to platforms which are believed to use
  # hdcp.bin. On all other platforms, or if unfreeIncludeHDCPBlob=false,
  # hdcp.bin will be deleted before building.
  unfreeIncludeHDCPBlob ? true,
}:

let
  buildArmTrustedFirmware = lib.makeOverridable (
    {
      filesToInstall,
      installDir ? "$out",
      platform ? null,
      platformCanUseHDCPBlob ? false, # set this to true if the platform is able to use hdcp.bin
      extraMakeFlags ? [ ],
      extraMeta ? { },
      ...
    }@args:

    # delete hdcp.bin if either: the platform is thought to
    # not need it or unfreeIncludeHDCPBlob is false
    let
      deleteHDCPBlobBeforeBuild = !platformCanUseHDCPBlob || !unfreeIncludeHDCPBlob;
    in

    stdenv.mkDerivation (
      rec {

        pname = "arm-trusted-firmware${lib.optionalString (platform != null) "-${platform}"}";
        version = "2.13.0";

        src = fetchFromGitHub {
          owner = "ARM-software";
          repo = "arm-trusted-firmware";
          tag = "v${version}";
          hash = "sha256-rxm5RCjT/MyMCTxiEC8jQeFMrCggrb2DRbs/qDPXb20=";
        };

        patches = lib.optionals deleteHDCPBlobBeforeBuild [
          # this is a rebased version of https://gitlab.com/vicencb/kevinboot/-/blob/master/atf.patch
          ./remove-hdcp-blob.patch
        ];

        postPatch = lib.optionalString deleteHDCPBlobBeforeBuild ''
          rm plat/rockchip/rk3399/drivers/dp/hdcp.bin
        '';

        depsBuildBuild = [ buildPackages.stdenv.cc ];

        nativeBuildInputs = [
          pkgsCross.arm-embedded.stdenv.cc # For Cortex-M0 firmware in RK3399
          openssl # For fiptool
        ];

        # Make the new toolchain guessing (from 2.11+) happy
        # https://github.com/ARM-software/arm-trusted-firmware/blob/4ec2948fe3f65dba2f19e691e702f7de2949179c/make_helpers/toolchains/rk3399-m0.mk#L21-L22
        rk3399-m0-oc = "${pkgsCross.arm-embedded.stdenv.cc.targetPrefix}objcopy";

        buildInputs = [ openssl ];

        makeFlags = [
          "HOSTCC=$(CC_FOR_BUILD)"
          "M0_CROSS_COMPILE=${pkgsCross.arm-embedded.stdenv.cc.targetPrefix}"
          "CROSS_COMPILE=${stdenv.cc.targetPrefix}"
          # Make the new toolchain guessing (from 2.11+) happy
          "CC=${stdenv.cc.targetPrefix}cc"
          "LD=${stdenv.cc.targetPrefix}cc"
          "AS=${stdenv.cc.targetPrefix}cc"
          "OC=${stdenv.cc.targetPrefix}objcopy"
          "OD=${stdenv.cc.targetPrefix}objdump"
          # Passing OpenSSL path according to docs/design/trusted-board-boot-build.rst
          "OPENSSL_DIR=${openssl}"
        ]
        ++ (lib.optional (platform != null) "PLAT=${platform}")
        ++ extraMakeFlags;

        installPhase = ''
          runHook preInstall

          mkdir -p ${installDir}
          cp ${lib.concatStringsSep " " filesToInstall} ${installDir}

          runHook postInstall
        '';

        hardeningDisable = [ "all" ];
        dontStrip = true;

        env.NIX_CFLAGS_COMPILE = lib.concatStringsSep " " [
          # breaks secondary CPU bringup on at least RK3588, maybe others
          "-fomit-frame-pointer"

          # Breaks compilation of armTrustedFirmwareRK3399:
          # /nix/store/hash-arm-none-eabi-binutils-2.44/bin/arm-none-eabi-ld: /build/source/build/rk3399/release/m0/rk3399m0.elf: error: PHDR segment not covered by LOAD segment
          #
          # This was caused by ccc56d1a79ff2a0f528cecf5e36eb76beaacc8c0 adding the flag `--enable-default-pie`.
          # According to https://trustedfirmware-a.readthedocs.io/en/v2.2/getting_started/user-guide.html,
          # Trusted Firmware-A has an option called ENABLE_PIE, which is turned off by default.
          # Someone with more knowledge of the implications can try using that option instead.
          "-no-pie"
        ];

        meta =

          {
            homepage = "https://github.com/ARM-software/arm-trusted-firmware";
            description = "Reference implementation of secure world software for ARMv8-A";
            license = [
              lib.licenses.bsd3
            ]
            ++ lib.optionals (!deleteHDCPBlobBeforeBuild) [ lib.licenses.unfreeRedistributable ];
            maintainers = with lib.maintainers; [ lopsided98 ];
          }
          // extraMeta;
      }
      // removeAttrs args [ "extraMeta" ]
    )
  );

in
{
  inherit buildArmTrustedFirmware;

  armTrustedFirmwareTools = buildArmTrustedFirmware {
    # Normally, arm-trusted-firmware builds the build tools for buildPlatform
    # using CC_FOR_BUILD (or as it calls it HOSTCC). Since want to build them
    # for the hostPlatform here, we trick it by overriding the HOSTCC setting
    # and, to be safe, remove CC_FOR_BUILD from the environment.
    depsBuildBuild = [ ];
    extraMakeFlags = [
      "HOSTCC=${stdenv.cc.targetPrefix}gcc"
      "fiptool"
      "certtool"
    ];
    filesToInstall = [
      "tools/fiptool/fiptool"
      "tools/cert_create/cert_create"
    ];
    postInstall = ''
      mkdir -p "$out/bin"
      find "$out" -type f -executable -exec mv -t "$out/bin" {} +
    '';
  };

  armTrustedFirmwareAllwinner = buildArmTrustedFirmware rec {
    platform = "sun50i_a64";
    extraMeta.platforms = [ "aarch64-linux" ];
    filesToInstall = [ "build/${platform}/release/bl31.bin" ];
  };

  armTrustedFirmwareAllwinnerH616 = buildArmTrustedFirmware rec {
    platform = "sun50i_h616";
    extraMeta.platforms = [ "aarch64-linux" ];
    filesToInstall = [ "build/${platform}/release/bl31.bin" ];
  };

  armTrustedFirmwareAllwinnerH6 = buildArmTrustedFirmware rec {
    platform = "sun50i_h6";
    extraMeta.platforms = [ "aarch64-linux" ];
    filesToInstall = [ "build/${platform}/release/bl31.bin" ];
  };

  armTrustedFirmwareQemu = buildArmTrustedFirmware rec {
    platform = "qemu";
    extraMeta.platforms = [ "aarch64-linux" ];
    filesToInstall = [
      "build/${platform}/release/bl1.bin"
      "build/${platform}/release/bl2.bin"
      "build/${platform}/release/bl31.bin"
    ];
  };

  armTrustedFirmwareRK3328 = buildArmTrustedFirmware rec {
    extraMakeFlags = [ "bl31" ];
    platform = "rk3328";
    extraMeta.platforms = [ "aarch64-linux" ];
    filesToInstall = [ "build/${platform}/release/bl31/bl31.elf" ];
  };

  armTrustedFirmwareRK3399 = buildArmTrustedFirmware rec {
    extraMakeFlags = [ "bl31" ];
    platform = "rk3399";
    extraMeta.platforms = [ "aarch64-linux" ];
    filesToInstall = [ "build/${platform}/release/bl31/bl31.elf" ];
    platformCanUseHDCPBlob = true;
  };

  armTrustedFirmwareRK3568 = buildArmTrustedFirmware rec {
    extraMakeFlags = [ "bl31" ];
    platform = "rk3568";
    extraMeta.platforms = [ "aarch64-linux" ];
    filesToInstall = [ "build/${platform}/release/bl31/bl31.elf" ];
  };

  armTrustedFirmwareRK3588 = buildArmTrustedFirmware rec {
    extraMakeFlags = [ "bl31" ];
    platform = "rk3588";
    extraMeta.platforms = [ "aarch64-linux" ];
    filesToInstall = [ "build/${platform}/release/bl31/bl31.elf" ];
  };

  armTrustedFirmwareS905 = buildArmTrustedFirmware rec {
    extraMakeFlags = [ "bl31" ];
    platform = "gxbb";
    extraMeta.platforms = [ "aarch64-linux" ];
    filesToInstall = [ "build/${platform}/release/bl31.bin" ];
  };

  # Armanda 37x0 products:
  #   1. needs specific ATF for each of their CPU speed / Memory combination
  #   2. also do final U-Boot packaging in ATF repo
  # This makes the build output not generic per SoC, but tightly coupled with
  # final hardware.
  # As such there is not much point to list them as ATF package, but more like
  # the final output of the U-Boot package.
  ubootESPRESSObin-full = {
    CPU_1000_DDR_800_DDR_TOPOLOGY_2 = buildArmTrustedFirmware rec {
      pname = "${ubootESPRESSObin.pname}-CPU_1000_DDR_800_DDR_TOPOLOGY_2";
      version = ubootESPRESSObin.version;

      mv-ddr-marvell = fetchFromGitHub {
        owner = "MarvellEmbeddedProcessors";
        repo = "mv-ddr-marvell";
        rev = "7bcb9dc7ea7fa233bf96bd0350a4ec7c205e342e";
        hash = "sha256-M0XZ7+L0NDUmu4zu6o01lO41cJMWQRHCf9UF7eY4AjA=";
        leaveDotGit = true; # ATF actually wants git repo
      };
      A3700-utils-marvell = fetchFromGitHub {
        owner = "MakiseKurisu";
        repo = "A3700-utils-marvell";
        rev = "7a1278de0f96630790441550cc8b8aea0806ad03";
        hash = "sha256-ql4CfYdJ/qbibm+smS0aZZKZU96chCSzkr4/7we817g=";
        leaveDotGit = true; # ATF actually wants git repo
      };

      preBuild = ''
        # Workaround "dubious ownership" git error caused by Nix store being owned by root
        cp -r ${A3700-utils-marvell} "$NIX_BUILD_TOP/A3700-utils-marvell"
        cp -r ${mv-ddr-marvell} "$NIX_BUILD_TOP/mv-ddr-marvell"
        chmod -R +w "$NIX_BUILD_TOP/A3700-utils-marvell" "$NIX_BUILD_TOP/mv-ddr-marvell"
        patchShebangs "$NIX_BUILD_TOP/A3700-utils-marvell/script/"*

        makeFlagsArray+=(
          "WTP=$NIX_BUILD_TOP/A3700-utils-marvell"
          "MV_DDR_PATH=$NIX_BUILD_TOP/mv-ddr-marvell"
        )
      '';

      nativeBuildInputs = [
        buildPackages.gitMinimal
        buildPackages.perl
        buildPackages.which
        openssl
        pkgsCross.arm-embedded.stdenv.cc
      ];

      extraMakeFlags = [
        "CROSS_CM3=${pkgsCross.arm-embedded.stdenv.cc.targetPrefix}"
        "USE_COHERENT_MEM=0"
        # You can find valid CLOCKSPRESET and DDR_TOPOLOGY value here:
        # https://trustedfirmware-a.readthedocs.io/en/latest/plat/marvell/armada/build.html
        "CLOCKSPRESET=CPU_1000_DDR_800"
        "DDR_TOPOLOGY=2"
        "CRYPTOPP_LIBDIR=${buildPackages.cryptopp}/lib"
        "CRYPTOPP_INCDIR=${buildPackages.cryptopp.dev}/include/cryptopp"
        "BL33=${ubootESPRESSObin}/u-boot.bin"
        "WTMI_IMG=${buildPackages.wtmi_app}/wtmi_app.bin"
        "FIP_ALIGN=0x100"
      ];

      buildFlags = [
        "mrvl_flash"
        "mrvl_uart"
      ];

      # Regular buildArmTrustedFirmware section

      platform = "a3700";
      extraMeta = {
        platforms = [ "aarch64-linux" ];
        longDescription = ''
          This Trusted Firmware-A package also include packaged U-Boot suitable
          for flashing.

          Please refer to https://wiki.espressobin.net/tiki-index.php?page=Update+the+Bootloader
          for how to flash flash-image.bin to your device.

          The current configuration is for 1GHz CPU and 800MHz DDR3 2CS 1GB.
        '';
      };
      filesToInstall = [
        "build/${platform}/release/bl1.bin"
        "build/${platform}/release/bl2.bin"
        "build/${platform}/release/bl31.bin"
        "build/${platform}/release/fip.bin"
        "build/${platform}/release/boot-image.bin"
        "build/${platform}/release/flash-image.bin"
        "build/${platform}/release/uart-images.tgz.bin"
      ];
    };
  };
}
