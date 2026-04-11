{
  description = "Terraform Cloudflare API token bootstrap dev shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
      in {
        checks = {
          terraform-fmt = pkgs.runCommand "terraform-fmt-check" {
            src = self;
            nativeBuildInputs = [ pkgs.terraform ];
          } ''
            cp -R "$src" repo
            chmod -R u+w repo
            cd repo
            terraform fmt -check -recursive .
            touch "$out"
          '';

          checkov = pkgs.runCommand "checkov-scan" {
            src = self;
            nativeBuildInputs = [ pkgs.checkov ];
          } ''
            cp -R "$src" repo
            chmod -R u+w repo
            cd repo
            export HOME="$TMPDIR"
            checkov -d . --config-file .checkov.yaml
            touch "$out"
          '';
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            terraform
            checkov
            pre-commit
            just
          ];
        };
      });
}
