{ lib, stdenvNoCC, fetchurl }:

let
  arch = if stdenvNoCC.hostPlatform.isAarch64 then "arm64" else "x86_64";
  hashes = {
    arm64 = "sha256-JmBwELGCKnp7A1PTcswAvhSfkdE4LoqZ35arQzWvxqA=";
    x86_64 = "sha256-5CXwAARHQam+u+2yZe9m7+q7pI5FrBU3Sx35wJK13z4=";
  };
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "strix";
  version = "1.7.0";

  src = fetchurl {
    url = "https://github.com/usestrix/strix/releases/download/v${finalAttrs.version}/strix-${finalAttrs.version}-macos-${arch}.tar.gz";
    hash = hashes.${arch};
  };

  # The release is a PyInstaller bundle whose launcher is ad-hoc signed.
  # Any fixup that rewrites the Mach-O (stripping in particular) invalidates
  # the signature, after which macOS refuses to exec it on arm64.
  dontFixup = true;
  sourceRoot = ".";

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    cp strix-${finalAttrs.version}-macos-${arch} $out/bin/strix
    chmod 755 $out/bin/strix
    runHook postInstall
  '';

  meta = {
    description = "AI penetration testing agent";
    homepage = "https://strix.ai";
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = lib.platforms.darwin;
    mainProgram = "strix";
  };
})
