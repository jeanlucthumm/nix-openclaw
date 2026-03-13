{
  lib,
  stdenvNoCC,
  fetchzip,
}:

stdenvNoCC.mkDerivation {
  pname = "openclaw-app";
  version = "2026.3.12";

  src = fetchzip {
    url = "https://github.com/openclaw/openclaw/releases/download/v2026.3.12/OpenClaw-2026.3.12.zip";
    hash = "sha256-0vuwxALe3cv6Povy583VGx4zXfKA0Wh9ePRt2Hp/xgY=";
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
