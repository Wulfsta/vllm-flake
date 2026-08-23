# Nix flake to build vLLM for ROCm gfx906 targets

This is a flake that patches triton and vllm, allowing them to build and pass the included smoke test.

## Instructions

Run `nix develop` to build a shell with vLLM, llama.cpp, and relevant dependencies. You may run `python test.py` to smoke test vLLM.

You will need to specify the `TRITON_ATTN` attention backend to serve models, as the `ROCM_ATTN` does not have a path for the `gfx906`:

```
vllm serve <model> --attention-backend TRITON_ATTN
```

Sample command to test on a 16GiB card:

```
vllm serve --attention-backend TRITON_ATTN Qwen/Qwen3.5-4B --max-model-len 65536 --gpu-memory-utilization 0.95 --limit-mm-per-prompt '{"image": 0, "video": 0}'
```

Or a GGUF:

```
vllm serve --attention-backend TRITON_ATTN unsloth/Qwen3.8-27B-GGUF:UD-Q3_K_XL --tokenizer Qwen/Qwen3.8-27B --max-model-len 4096 --max-num-seqs 1 --gpu-memory-utilization 0.98 --limit-mm-per-prompt '{"image": 0, "video": 0}' --cpu-offload-gb 2 --cpu-offload-params visual --kv-cache-dtype fp8 --performance-mode interactivity
```

A more reasonable quant of the above model with more context on llama.cpp (running only slightly slower):

```
llama-server --hf-repo unsloth/Qwen3.8-27B-GGUF:UD-IQ4_XS -c 65536 -ngl 99 --fit off -ot 'blk.([0-9]|1[0-9]|2[01]).ffn_(gate|up).*=CPU' -ctk q4_0 -ctv q4_0
```
