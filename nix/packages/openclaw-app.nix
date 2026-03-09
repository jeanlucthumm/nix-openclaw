{
  lib,
  stdenvNoCC,
  fetchzip,
}:

stdenvNoCC.mkDerivation {
  pname = "openclaw-app";
  version = "2026.3.7";

  src = fetchzip {
    url = "https://github.com/openclaw/openclaw/releases/download/v2026.3.7/OpenClaw-2026.3.7.zip";
    hash = "sha256-4unXmu6LvCz/3gfPto1yoR8xglZobWuU5GPxPbuDqSU=";
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
