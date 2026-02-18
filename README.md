# Nix flake to build vLLM for ROCm gfx906 targets

This is a flake that points to a [fork of nixpkgs](https://github.com/Wulfsta/nixpkgs/tree/vllm-gfx906) that pins [triton-gfx906](https://github.com/nlzy/triton-gfx906), allowing vllm to build and pass the included smoke test.

## Instructions

Run `nix develop` to build a shell with vLLM, llama.cpp, and relevant dependencies. You may run `python test.py` to smoke test vLLM.
