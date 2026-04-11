{
  description = "Terraform Cloudflare API token bootstrap dev shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    pre-commit-hooks = {
      url = "github:serokell/nix-pre-commit-hooks";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, pre-commit-hooks }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        mkNoopTool = name: pkgs.writeShellScriptBin name "exit 0";

        serokellRun = import (pre-commit-hooks + "/nix/run.nix") {
          tools = {
            hlint = mkNoopTool "hlint";
            ormolu = mkNoopTool "ormolu";
            cabal-fmt = mkNoopTool "cabal-fmt";
            canonix = mkNoopTool "canonix";
            nixpkgs-fmt = mkNoopTool "nixpkgs-fmt";
            shellcheck = pkgs.shellcheck;
            "elm-format" = mkNoopTool "elm-format";
          };
          pre-commit = pkgs.pre-commit;
          git = pkgs.git;
          runCommand = pkgs.runCommand;
          writeText = pkgs.writeText;
          writeScript = pkgs.writeShellScript;
        };

        localPreCommitHooks = pkgs.writeText "pre-commit-hooks" ''
          -   id: terraform-fmt
              name: terraform fmt
              entry: ${pkgs.terraform}/bin/terraform fmt -check -recursive
              language: system
              files: '\\.tf$'

          -   id: checkov
              name: checkov
              entry: ${pkgs.checkov}/bin/checkov -d . --config-file .checkov.yaml
              language: system
              pass_filenames: false
              files: '\\.tf$'

          -   id: detect-secrets
              name: detect secrets
              entry: ${pkgs.detect-secrets}/bin/detect-secrets-hook --exclude-files '(^|/)(\\.terraform\\.lock\\.hcl|terraform\\.tfvars\\.example|terraform\\.tfvars|terraform\\.tfstate(\\..*)?)$'
              language: system
        '';

        preCommitCheck = serokellRun {
          src = ./.;
          hooks = localPreCommitHooks;
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

          secret-scan = pkgs.runCommand "detect-secrets-scan" {
            src = self;
            nativeBuildInputs = [ pkgs.git pkgs.detect-secrets ];
          } ''
            cp -R "$src" repo
            chmod -R u+w repo
            cd repo
            git init -q
            git add .
            detect-secrets-hook \
              --exclude-files '(^|/)(\.terraform\.lock\.hcl|terraform\.tfvars\.example|terraform\.tfvars|terraform\.tfstate(\..*)?)$' \
              $(git ls-files)
            touch "$out"
          '';
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            terraform
            checkov
            pre-commit
            detect-secrets
            just
          ];
          shellHook = preCommitCheck.shellHook;
        };
      });
}
