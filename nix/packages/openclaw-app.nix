{
  lib,
  stdenvNoCC,
  fetchzip,
}:

stdenvNoCC.mkDerivation {
  pname = "openclaw-app";
  version = "2026.2.26";

  src = fetchzip {
    url = "https://github.com/openclaw/openclaw/releases/download/v2026.2.26/OpenClaw-2026.2.26.zip";
    hash = "sha256-5bIxFEO3Nru6uiHseKe14RdJ1PzgUIGI9Yk1CNKQ/2s=";
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
