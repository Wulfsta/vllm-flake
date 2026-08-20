# Nix flake to build vLLM for ROCm gfx906 targets

This is a flake that patches triton and vllm, allowing them to build and pass the included smoke test.

## Instructions

Run `nix develop` to build a shell with vLLM, llama.cpp, and relevant dependencies. You may run `python test.py` to smoke test vLLM.

You will need to specify the `TRITON_ATTN` attention backend to serve models, as the `ROCM_ATTN` does not have a path for the `gfx906`:

```
vllm serve <model> --attention-backend TRITON_ATTN
```
