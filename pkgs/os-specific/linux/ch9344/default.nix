{ stdenv, lib, fetchzip, kernel }:

stdenv.mkDerivation rec {
  pname = "ch9344";
  version = "2.1";

  src = fetchzip {
    name = "CH9344SER_LINUX.zip";
    url = "https://www.wch.cn/downloads/file/386.html#CH9344SER_LINUX.zip";
    hash = "sha256-ZZ/8s26o7wRwHy6c0m1vZ/DtRW5od+NgiU6aXZBVfc4=";
  };

  patches = [
  ];

  sourceRoot = "${src.name}/driver";
  hardeningDisable = [ "pic" ];
  nativeBuildInputs = kernel.moduleBuildDependencies;

  preBuild = ''
    substituteInPlace Makefile --replace "KERNELDIR :=" "KERNELDIR ?="
  '';

  makeFlags = [
    "KERNELDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
  ];

  installPhase = ''
    runHook preInstall
    install -D ch9344.ko $out/lib/modules/${kernel.modDirVersion}/usb/serial/ch9344.ko
    runHook postInstall
  '';

  meta = with lib; {
    homepage = "https://www.wch-ic.com/";
    downloadPage = "https://www.wch.cn/downloads/CH9344SER_LINUX_ZIP.html";
    description = "WCH CH9344/CH348 UART driver";
    longDescription = ''
      A kernel module for WinChipHead CH9344/CH348 USB To Multi Serial Ports controller.
    '';
    # Archive contains no license.
    license = licenses.unfree;
    platforms = platforms.linux;
    maintainers = with maintainers; [ MakiseKurisu ];
  };
}
