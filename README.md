## Nix flake to build vllm for ROCm gfx906 targets

This is a flake that points to a [fork of nixpkgs](https://github.com/Wulfsta/nixpkgs/tree/vllm-gfx906) that pins [triton-gfx906](https://github.com/nlzy/triton-gfx906), allowing vllm to build and pass the included smoke test.
