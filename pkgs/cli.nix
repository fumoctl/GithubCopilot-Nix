{
  lib,
  stdenv,
  fetchurl,
  installShellFiles,
}:
let
  pname = "github-copilot-cli";

  versions = builtins.fromJSON (builtins.readFile ../artifacts/versions.json);
  system = stdenv.hostPlatform.system;

  platformInfo = versions."GitHub Copilot CLI".${system} or (throw "Unsupported system for GitHub Copilot CLI: ${system}");

  # Extract version from URL
  version = let
    match = builtins.match ".*/download/v?([0-9.]+)/.*" platformInfo.url;
  in if match != null then builtins.elemAt match 0 else "unknown";
in
stdenv.mkDerivation {
  inherit pname version;

  src = fetchurl {
    inherit (platformInfo) url;
    sha256 = platformInfo.hash;
  };

  nativeBuildInputs = [ installShellFiles ];

  sourceRoot = ".";

  dontBuild = true;
  dontConfigure = true;
  dontStrip = true;
  dontPatchELF = true;

  installPhase = ''
    runHook preInstall

    # Install the unwrapped binary
    mkdir -p $out/libexec
    cp copilot $out/libexec/copilot
    chmod +x $out/libexec/copilot

    # Generate a wrapper that invokes the interpreter directly
    mkdir -p $out/bin
    cat <<EOF > $out/bin/copilot
#!/bin/sh
exec ${stdenv.cc.bintools.dynamicLinker} --library-path "${lib.makeLibraryPath [ stdenv.cc.libc stdenv.cc.cc.lib ]}" $out/libexec/copilot "\$@"
EOF
    chmod +x $out/bin/copilot

    # Provide aliases
    ln -s copilot $out/bin/github-copilot-cli
    ln -s copilot $out/bin/github-copilot

    # Generate and install shell completions
    export HOME=$(mktemp -d)
    installShellCompletion --cmd copilot \
      --bash <($out/bin/copilot completion bash) \
      --zsh <($out/bin/copilot completion zsh) \
      --fish <($out/bin/copilot completion fish)

    runHook postInstall
  '';

  meta = with lib; {
    description = "GitHub Copilot CLI - Command line interface for GitHub Copilot";
    homepage = "https://github.com/github/copilot-cli";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" "aarch64-linux" ];
    mainProgram = "copilot";
  };
}
