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
                pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
                  (pyFinal: pyPrev: {
                    vllm = pyPrev.vllm.overrideAttrs (old: {
                      patches = (old.patches or [ ]) ++ [ ./vllm-gfx906-support.patch ];
                    });

                    triton = pyPrev.triton.overrideAttrs (old: {
                      patches = (old.patches or [ ]) ++ [ ./triton-gfx906-support.patch ];
                    });

                    #TODO: clean this code up
                    vllm-gguf-plugin =
                      let
                        # Use vendored CK as header only dep if rocmPackages' CK doesn't properly support targets
                        vendorComposableKernel = !final.rocmPackages.composable_kernel.anyMfmaTarget;

                        rocmtoolkit_joined = final.symlinkJoin {
                          name = "rocm-merged";

                          paths =
                            with final.rocmPackages;
                            [
                              rocm-core
                              clr
                              rccl
                              miopen
                              aotriton
                              rocrand
                              rocblas
                              rocsparse
                              hipsparse
                              rocthrust
                              rocprim
                              hipcub
                              roctracer
                              rocfft
                              rocsolver
                              hipfft
                              hiprand
                              hipsolver
                              hipblas-common
                              hipblas
                              hipblaslt
                              rocminfo
                              rocm-comgr
                              rocm-device-libs
                              rocm-runtime
                              rocm-smi
                              clr.icd
                              hipify
                              rocprofiler-sdk
                              rocprofiler-sdk.dev
                              amdsmi
                            ]
                            ++ final.lib.optionals (!vendorComposableKernel) [
                              composable_kernel
                            ];

                          # Fix `setuptools` not being found
                          postBuild = ''
                            rm -rf $out/nix-support
                          '';
                        };

                        # header path ends up missing rocthrust & its deps
                        rocmExtraIncludeFlags =
                          final.lib.concatMapStringsSep " " (pkg: "-I${final.lib.getInclude pkg}/include")
                            [
                              final.rocmPackages.rocthrust
                              final.rocmPackages.rocprim
                              final.rocmPackages.hipcub
                            ];
                      in
                      pyFinal.buildPythonPackage {
                        pname = "vllm-gguf-plugin";
                        version = "0.0.5";

                        src = final.fetchFromGitHub {
                          owner = "vllm-project";
                          repo = "vllm-gguf-plugin";
                          rev = "d358f564fc8f470cddd7c141a149b4ebafafa01f";
                          hash = "sha256-WHeRs4uB2LQGW0HuShchPPCpm5TkOVxw90sY34KS49Y=";
                        };

                        format = "setuptools";

                        build-system = [
                          pyFinal.setuptools
                          pyFinal.torch
                        ];

                        nativeBuildInputs = with final; [
                          pkg-config
                          rocmPackages.hipcc
                        ];

                        buildInputs =
                          with final.rocmPackages;
                          [
                            rocm-core
                            clr
                            rccl
                            miopen
                            aotriton
                            rocrand
                            rocblas
                            rocsparse
                            hipsparse
                            rocthrust
                            rocprim
                            hipcub
                            roctracer
                            rocfft
                            rocsolver
                            hipfft
                            hiprand
                            hipsolver
                            hipblas-common
                            hipblas
                            hipblaslt
                            rocminfo
                            rocm-comgr
                            rocm-device-libs
                            rocm-runtime
                            rocm-smi
                            clr.icd
                            hipify
                            rocprofiler-sdk
                            rocprofiler-sdk.dev
                            amdsmi
                          ]
                          ++ final.lib.optionals (!vendorComposableKernel) [
                            composable_kernel
                          ];

                        dependencies = with pyFinal; [
                          gguf
                          vllm
                          torch
                          # vLLM needs Torch's compiler to be present in order to use torch.compile
                          torch.stdenv.cc
                          huggingface-hub
                          final.rocmPackages.rocminfo
                        ];

                        env = {
                          HIPFLAGS = rocmExtraIncludeFlags;
                          CFLAGS = rocmExtraIncludeFlags;
                          CXXFLAGS = rocmExtraIncludeFlags;
                          ROCM_PATH = rocmtoolkit_joined;
                          ROCM_SOURCE_DIR = rocmtoolkit_joined;
                          CMAKE_CXX_FLAGS = "-I${rocmtoolkit_joined}/include";
                          PYTORCH_ROCM_ARCH = final.lib.strings.concatStringsSep ";" (
                            final.rocmPackages.clr.localGpuTargets or final.rocmPackages.clr.gpuTargets
                          );
                        };
                      };
                  })
                ];
              })
            ];
          };

          vllmPluginEnv = pkgs'.python313.withPackages (ps: [
            ps.vllm
            ps.vllm-gguf-plugin
          ]);

          vllmWithGguf =
            pkgs'.runCommand "vllm-with-gguf"
              {
                meta = (pkgs'.python313Packages.vllm.meta or { }) // {
                  mainProgram = "vllm";
                };
              }
              ''
                mkdir -p $out/bin
                ln -s ${vllmPluginEnv}/bin/vllm $out/bin/vllm
              '';
        in
        {
          devShells.default = pkgs'.mkShell {

            buildInputs = with pkgs'; [
              rocmPackages.clr
              llama-cpp
              vllmWithGguf
              python313Packages.pybind11
              (python313.withPackages (
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
                  vllm-gguf-plugin
                ]
              ))
            ];

            # Add to path just to have
            ROCM_PATH = "${pkgs'.rocmPackages.clr}";
            # Don't crash flash-attn because cuda isn't there
            #FLASH_ATTENTION_TRITON_AMD_ENABLE = "TRUE";
            # fixed upstream, patch applied - keeping it commented so I recall it later
            #LD_LIBRARY_PATH = "${pkgs'.rocmPackages.clr}/lib";
            # I don't remember why this is here but it was needed at some point
            TORCH_DONT_CHECK_COMPILER_ABI = "TRUE";
            # Make sure pybind gets included in the path - this is llama.cpp related
            CPLUS_INCLUDE_PATH = "${pkgs'.python313Packages.pybind11}/include:$CPLUS_INCLUDE_PATH";
          };
        };
    };
}
