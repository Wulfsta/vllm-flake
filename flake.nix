{
  inputs = {
    nixpkgs.url = "github:Wulfsta/nixpkgs/vllm-gfx906";

    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs =
    inputs@{ flake-parts, ... }:

    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      perSystem =
        {
          config,
          self',
          inputs',
          pkgs,
          system,
          ...
        }:
        let
          pkgs' = import inputs.nixpkgs {
            inherit system;
            config = {
              rocmSupport = true;
              allowUnfree = true;
            };
            overlays = [
              (final: prev: {
                rocmPackages = prev.rocmPackages.overrideScope (
                  rocmFinal: rocmPrev: {
                    clr = rocmPrev.clr.override {
                      localGpuTargets = [
                        "gfx906"
                        "gfx908"
                      ];
                    };
                  }
                );
              })
            ];
          };
        in
        {
          devShells.default = pkgs'.mkShell {

            buildInputs = with pkgs'; [
              rocmPackages.clr
              llama-cpp
              vllm
              python3Packages.pybind11
              (python3.withPackages (
                ps: with ps; [
                  matplotlib
                  numpy
                  opencv4
                  pybind11
                  torch
                  tokenizers
                  transformers
                  tqdm
                  scipy
                  vllm
                ]
              ))
            ];

            # Add to path just to have
            ROCM_PATH = "${pkgs'.rocmPackages.clr}";
            # Don't crash flash-attn because cuda isn't there
            FLASH_ATTENTION_TRITON_AMD_ENABLE = "TRUE";
            # fixed upstream, patch applied - keeping it commented so I recall it later
            #LD_LIBRARY_PATH = "${pkgs'.rocmPackages.clr}/lib";
            # I don't remember why this is here but it was needed at some point
            TORCH_DONT_CHECK_COMPILER_ABI = "TRUE";
            # Make sure pybind gets included in the path - this is llama.cpp related
            CPLUS_INCLUDE_PATH = "${pkgs.python3Packages.pybind11}/include:$CPLUS_INCLUDE_PATH";
          };
        };
    };
}
