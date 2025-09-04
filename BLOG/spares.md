
### WASM

WASM = WebAssembly - a binary instruction format that can run inside web browsers and outside them. It's safe, secure and cross-platform.

WASM's mostly used in Browsers (mostly for __client-side computing__) - as might've been heard - but it's not limited to that - it's other important _non-exahaustive use-cases_ include __edge computing__, __portable AI on the edge__ and __even replacing traditional docker containers__.*
  - __Client side computing__ :
    Instead of using the server's computing power, use your local machine's
    This means less server costs (and more profits :) as well as the users experiencing `near-native performance` - *that means from pdf tools to IDE's and even high-end games* - all in your browser

  - __Computing on the Edge__ :
    Similar to client-side-computing but the data is processed at intermediary nodes placed near the client, eg. routers, network towers or traffic cameraes

  - __portable AI on the edge__ :
    AI models run WASM servers as small as 12mb, eg. _Llamaedge's llama-api-server_. And those are also written in Rust!

  - __WASM containers__
    One of the biggest tech leaps of our time - When tradional container technology like docker is replaced by _runwasi's wasmedge container runtime_, the image size, its build time and container-boot-up time all get reduced to as low as 90%

_*I didn't know any of that when I applied for this project - but that's a story for another time. I knew some Rust though._