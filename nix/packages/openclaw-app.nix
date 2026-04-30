{
  lib,
  stdenvNoCC,
  fetchzip,
}:

stdenvNoCC.mkDerivation {
  pname = "openclaw-app";
  version = "2026.4.27";

  src = fetchzip {
    url = "https://github.com/openclaw/openclaw/releases/download/v2026.4.27/OpenClaw-2026.4.27.zip";
    hash = "sha256-dG2LzYJKojPrVzA9/r0x4WYPFwF2JXK2SLQUm83z1lk=";
    stripRoot = false;
  };

  dontUnpack = true;

  installPhase = "${../scripts/openclaw-app-install.sh}";

  meta = with lib; {
    description = "OpenClaw macOS app bundle";
    homepage = "https://github.com/openclaw/openclaw";
    license = licenses.mit;
    platforms = platforms.darwin;
  };
}
