{
  description = "Hush: a quiet Hyprland rice";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      python = pkgs.python3.withPackages (ps: [ ps.pillow ]);
      runtime = with pkgs; [ quickshell matugen awww hyprlock python lua imagemagick git ];
    in {
      packages.x86_64-linux.default = pkgs.stdenvNoCC.mkDerivation {
        pname = "hush";
        version = pkgs.lib.removeSuffix "\n" (builtins.readFile ./VERSION);
        src = self;
        nativeBuildInputs = [ pkgs.makeWrapper ];
        buildInputs = [ python ];
        dontBuild = true;
        installPhase = ''
          mkdir -p $out/share/hush $out/bin $out/share/fonts
          cp -r . $out/share/hush
          rm -rf $out/share/hush/{.githooks,tests,assets/brand/src}
          # Wrap in place: install.sh links share/hush/bin/hush into ~/.local/bin, which must get the PATH too.
          wrapProgram $out/share/hush/bin/hush \
            --set HUSH_ROOT $out/share/hush \
            --prefix PATH : ${pkgs.lib.makeBinPath runtime}
          ln -s $out/share/hush/bin/hush $out/bin/hush
          ln -s ${pkgs.inter}/share/fonts $out/share/fonts/inter
          ln -s ${pkgs.material-symbols}/share/fonts $out/share/fonts/material-symbols
          install -Dm644 LICENSE $out/share/licenses/hush/LICENSE
        '';
        meta = {
          description = "Quiet Hyprland rice: Quickshell shell, matugen themes and wallpapers";
          license = pkgs.lib.licenses.mit;
          platforms = [ "x86_64-linux" ];
          mainProgram = "hush";
        };
      };
    };
}
