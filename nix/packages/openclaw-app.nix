{
  lib,
  stdenvNoCC,
  fetchzip,
}:

stdenvNoCC.mkDerivation {
  pname = "openclaw-app";
  version = "2026.2.26-beta.1";

  src = fetchzip {
    url = "https://github.com/openclaw/openclaw/releases/download/v2026.2.26-beta.1/OpenClaw-2026.2.26.zip";
    hash = "sha256-rpaYummnDJQbP4c1AVtjh/NFE87ExhCNP1OoySukbfI=";
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
