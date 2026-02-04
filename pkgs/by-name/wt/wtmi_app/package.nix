{
  lib,
  buildPackages,
  fetchFromGitLab,
  git,
  pkgsCross,
  stdenv,
}:

stdenv.mkDerivation {
  pname = "wtmi_app";

  version = "2024.04.15-unstable-2024-09-16";

  src = fetchFromGitLab {
    domain = "gitlab.nic.cz";
    owner = "turris";
    repo = "mox-boot-builder";
    rev = "d6d9646abea1f536f4c5cf29f592f94e7dafe05d";
    hash = "sha256-onN9Cg4VTYdV+ae0aAOSXYifo7faCDC4D1lXaOeqskU=";
  };

  nativeBuildInputs = [
    git
    pkgsCross.aarch64-multiplatform.stdenv.cc
    pkgsCross.arm-embedded.stdenv.cc
  ];

  depsBuildBuild = [ buildPackages.stdenv.cc ];

  makeFlags = [
    "CROSS_CM3=${pkgsCross.arm-embedded.stdenv.cc.targetPrefix}"
  ];

  buildFlags = [
    "wtmi_app.bin"
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp wtmi_app.bin $out/

    runHook postInstall
  '';

  meta = {
    description = "CZ.NIC's Armada 3720 Secure Firmware";
    homepage = "https://gitlab.nic.cz/turris/mox-boot-builder";
    license = lib.licenses.bsd3;
    maintainers = [ lib.maintainers.MakiseKurisu ];
  };
}
