/* Two-player transport. Signaling uses the free PeerJS cloud. Gameplay uses WebRTC.
 * PeerJS is bundled locally under the MIT license. No account or API key is used.
 */
(() => {
  "use strict";
  const alphabet = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ";
  const prefix = "moro-kombat-v1-";
  let peer = null;
  let connection = null;
  let generation = 0;
  let events = [];
  let timer = null;
  let messages = 0;
  let rateStart = 0;

  function enqueue(event) {
    if (event.event === "data" && ["frame", "controls"].includes(event.payload.method)) {
      events = events.filter(old => old.event !== "data" || old.payload.method !== event.payload.method);
    }
    if (events.length < 128) events.push(event);
  }

  function close() {
    generation++;
    clearTimeout(timer);
    timer = null;
    const oldConnection = connection;
    const oldPeer = peer;
    connection = null;
    peer = null;
    events = [];
    if (oldConnection) oldConnection.close();
    if (oldPeer) oldPeer.destroy();
  }

  function fail(message) {
    close();
    enqueue({ event: "error", message });
  }

  function normalize(code) {
    const compact = String(code).trim().toUpperCase().replace(/[\s-]/g, "");
    if (!compact.startsWith("MK")) return "";
    const token = compact.slice(2);
    return token.length === 12 && [...token].every(c => alphabet.includes(c)) ? token : "";
  }

  function bind(candidate, currentGeneration) {
    if (connection) {
      candidate.close();
      return;
    }
    connection = candidate;
    messages = 0;
    rateStart = Date.now();
    candidate.on("open", () => {
      if (currentGeneration !== generation || connection !== candidate) return;
      clearTimeout(timer);
      enqueue({ event: "connected" });
    });
    candidate.on("data", raw => {
      if (currentGeneration !== generation || connection !== candidate) return;
      if (Date.now() - rateStart > 1000) {
        rateStart = Date.now();
        messages = 0;
      }
      if (++messages > 180 || typeof raw !== "string" || raw.length > 16384) {
        fail("El otro navegador ha enviado datos inválidos.");
        return;
      }
      try {
        const packet = JSON.parse(raw);
        if (packet.v === 1 && typeof packet.method === "string" && Array.isArray(packet.args)) {
          enqueue({ event: "data", payload: packet });
        }
      } catch (_) { /* Ignore malformed packets. */ }
    });
    candidate.on("close", () => {
      if (currentGeneration === generation && connection === candidate) {
        fail("Tu compañero ha cerrado la conexión. Cread una sala nueva para volver a jugar.");
      }
    });
    candidate.on("error", () => {
      if (currentGeneration === generation) fail("La conexión con tu compañero se ha interrumpido.");
    });
  }

  function start(token, hosting) {
    close();
    const currentGeneration = generation;
    if (!window.RTCPeerConnection || !window.crypto?.getRandomValues) {
      enqueue({ event: "error", message: "Este navegador no admite WebRTC. Abre el juego en una versión reciente de Chrome, Edge, Firefox o Safari." });
      return;
    }
    timer = setTimeout(() => {
      if (generation === currentGeneration) {
        fail("No se pudo conectar. Comprueba el código y que la sala siga abierta. Puede que la red bloquee WebRTC o que el servicio gratuito no esté disponible.");
      }
    }, 35000);
    // Preserve PeerJS's bundled STUN and TURN defaults, including its public
    // relay fallback. Availability of those third-party services may change.
    const options = { debug: 0 };
    try {
      peer = hosting ? new window.Peer(prefix + token.toLowerCase(), options) : new window.Peer(options);
      peer.on("open", () => {
        if (currentGeneration !== generation) return;
        if (hosting) {
          clearTimeout(timer);
          enqueue({ event: "room", code: "MK-" + token.slice(0, 6) + "-" + token.slice(6) });
        } else {
          bind(peer.connect(prefix + token.toLowerCase(), {
            reliable: true, serialization: "raw", label: "moro-kombat-v1"
          }), currentGeneration);
        }
      });
      peer.on("connection", candidate => {
        if (currentGeneration !== generation || !hosting || connection) candidate.close();
        else bind(candidate, currentGeneration);
      });
      peer.on("error", error => {
        if (currentGeneration !== generation) return;
        const messages = {
          "peer-unavailable": "Ese código no tiene una sala abierta. Comprueba el código con tu compañero.",
          "unavailable-id": "El código ya está en uso. Crea otra sala.",
          "network": "El servicio gratuito de salas no está accesible. Vuelve a intentarlo.",
          "browser-incompatible": "Tu navegador no admite la conexión WebRTC necesaria."
        };
        fail(messages[error.type] || "No se pudo abrir la conexión con el servicio gratuito de salas.");
      });
      peer.on("disconnected", () => {
        if (currentGeneration !== generation) return;
        // An established data channel can continue without the signaling service.
        if (!connection?.open) fail("Se perdió el acceso al servicio de salas. Vuelve a crear o unirte a una sala.");
      });
    } catch (_) {
      fail("No se pudo iniciar la conexión en este navegador.");
    }
  }

  window.MoroNet = Object.freeze({
    create() {
      const bytes = new Uint8Array(12);
      window.crypto.getRandomValues(bytes);
      start([...bytes].map(byte => alphabet[byte % alphabet.length]).join(""), true);
    },
    join(code) {
      const token = normalize(code);
      if (!token) return false;
      start(token, false);
      return true;
    },
    send(method, argumentsJSON) {
      if (!connection?.open) return false;
      if (["frame", "controls"].includes(method) && connection.dataChannel?.bufferedAmount > 65536) return false;
      try {
        connection.send(JSON.stringify({ v: 1, method, args: JSON.parse(argumentsJSON) }));
        return true;
      } catch (_) {
        fail("Se ha interrumpido el envío al otro navegador.");
        return false;
      }
    },
    poll() {
      const pending = events;
      events = [];
      return JSON.stringify(pending);
    },
    close
  });
  window.addEventListener("pagehide", close);
})();
