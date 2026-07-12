# Golview Cam — fork de Moblin

Fork **delta mínimo** de [Moblin](https://github.com/eerimoq/moblin) (MIT) para
[Golview](https://golview.mx) — captura y transmisión de partidos de futbol juvenil.

## Reglas del fork
1. **Delta mínimo**: solo branding, configuración y módulos Golview aislados.
   El tagging de eventos vive en la web (golview.mx/marcador), NUNCA aquí.
2. `master` rastrea upstream `eerimoq/moblin`; nuestra rama es `golview`.
   Rebase periódico: `git fetch upstream && git rebase upstream/main`.
3. Twitch/Kick/YouTube se CONSERVAN (simulcast = marketing de torneos).

## Build
1. `cp User.template.xcconfig Config/User.xcconfig`
2. En `Config/User.xcconfig`: `DEVELOPMENT_TEAM` = team ID de PHS,
   `BASE_PRODUCT_BUNDLE_IDENTIFIER = mx.golview.cam`, `CAPABILITIES = all`.
3. `open Moblin.xcodeproj` → ⌘R.

## Roadmap del fork
- F1: branding + login Golview + unirse a sesión por QR (la app pide config SRT al API y se autoconfigura)
- F2: grabación local + subida por chunks reanudable (API lista) + overlay marcador desde MatchEvents
- F3: narración por mic bluetooth (Moblin ya lo trae — solo UX) + Apple Watch eventos
