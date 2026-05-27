# fvp Query Fence Patch

## Summary

Replace `Flush()` with `D3D11_QUERY_EVENT` in fvp_plugin.cpp to avoid full GPU pipeline drain per frame.

## Modified Files (in pub cache)

- `~/.pub-cache/hosted/pub.dev/fvp-0.36.2/windows/fvp_plugin.h`
- `~/.pub-cache/hosted/pub.dev/fvp-0.36.2/windows/fvp_plugin.cpp`

## Changes

### fvp_plugin.h

Added `#include <synchapi.h>` for `SwitchToThread()`.

### fvp_plugin.cpp

1. Added `ComPtr<ID3D11Query> query_;` member to TexturePlayer
2. Created query in constructor: `D3D11_QUERY_DESC qd = { D3D11_QUERY_EVENT, 0 }; dev->CreateQuery(&qd, &query_);`
3. Replaced `ctx->Flush()` with:
   ```cpp
   ctx->End(query_.Get());
   while (ctx->GetData(query_.Get(), nullptr, 0, 0) == S_FALSE)
       SwitchToThread();
   ```

## Re-apply After pub get

This patch modifies files in the pub cache. Running `flutter pub get` will overwrite these changes.

To re-apply, run:
```powershell
# Check if patch is applied
$fp = "$env:LOCALAPPDATA\Pub\Cache\hosted\pub.dev\fvp-0.36.2\windows\fvp_plugin.cpp"
if (Select-String -Path $fp -Pattern "Query fence" -Quiet) {
  Write-Host "Patch already applied"
} else {
  Write-Host "Patch NOT applied - reapply manually"
}
```

## Expected Impact

- Eliminates full GPU pipeline drain per frame (Flush → query fence)
- Estimated 1-3ms savings per frame on desktop D3D11
- No behavioral change — same synchronization guarantee
