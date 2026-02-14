{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs =
    inputs@{ flake-parts, ... }:

    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
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
                vllm_rocm_path = prev.symlinkJoin {
                  name = "vllm_rocm_path";
                  paths = with final; [
                    rocmPackages.clr
                    rocmPackages.rocthrust
                    rocmPackages.rocprim
                    rocmPackages.rocrand
                    rocmPackages.hiprand
                    rocmPackages.rocblas
                    rocmPackages.miopen
                    rocmPackages.hipfft
                    rocmPackages.hipcub
                    rocmPackages.hipsolver
                    rocmPackages.rocsolver
                    rocmPackages.hipblaslt
                    rocmPackages.rccl
                    rocmPackages.hipsparse
                    rocmPackages.amdsmi
                  ];
                };

                python3 = prev.python3.override {
                  packageOverrides = pythonFinal: pythonPrev: {
                    #  triton = pythonPrev.triton.overrideAttrs (oldAttrs: {
                    #    src = prev.fetchFromGitHub {
                    #      owner = "nlzy";
                    #      repo = "triton-gfx906";
                    #      rev = "9c06a19c4d17aac7b67caff8bae6cece20993184";
                    #      sha256 = "sha256-tZYyLNSDKMfsigzJ6Ul0EoiUB80DzDKNfCbvY4ln9Cs=";
                    #    };
                    #  });
                    vllm = pythonPrev.vllm.overrideAttrs (oldAttrs: {
                      #src = prev.fetchFromGitHub {
                      #  owner = "nlzy";
                      #  repo = "vllm-gfx906";
                      #  rev = "22fd5fc9caac833bbec6d715909fc63fca3e5b6b";
                      #  sha256 = "sha256-gVLAv2tESiNzIsEz/7AzB1NQ5bGfnnwjzI6JPlP9qBs=";
                      #};

                      propagatedBuildInputs =
                        (oldAttrs.propagatedBuildInputs or [ ])
                        ++ (with pythonPrev; [
                          datasets
                          peft
                          pytest-asyncio
                          timm
                          final.vllm_rocm_path
                          # Not available: tensorizer, runai-model-streamer, conch-triton-kernels
                        ]);

                      preConfigure = (oldAttrs.preConfigure or "") + ''
                        export ROCM_PATH=${final.vllm_rocm_path}
                      '';

                      env = (oldAttrs.env or { }) // {
                        TRITON_KERNELS_SRC_DIR = "${
                          prev.lib.getDev prev.fetchFromGitHub {
                            owner = "triton-lang";
                            repo = "triton";
                            tag = "v3.5.0";
                            hash = "sha256-F6T0n37Lbs+B7UHNYzoIQHjNNv3TcMtoXjNrT8ZUlxY=";
                          }
                        }/python/triton_kernels/triton_kernels";

                        PYTORCH_ROCM_ARCH = prev.lib.strings.concatStringsSep ";" final.rocmPackages.clr.localGpuTargets;
                      };

                      dontCheckRuntimeDeps = true; # Skip the check that fails due to tensorizer, runai-model-streamer, conch-triton-kernels
                    });
                  };
                };
              })
            ];
          };
        in
        {
          devShells.default = pkgs'.mkShell {

            buildInputs = with pkgs'; [
              llama-cpp
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

            shellHook = ''
              export TORCH_DONT_CHECK_COMPILER_ABI=TRUE
              export CPLUS_INCLUDE_PATH=${pkgs.python3Packages.pybind11}/include:$CPLUS_INCLUDE_PATH
            '';
          };
        };
    };
}
