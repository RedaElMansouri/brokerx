# UC-04 — Données de marché en temps réel (ActionCable)

## Métadonnées
- Identifiant: UC-04
- Version: 1.0
- Statut: Must‑Have (Phase 2)
- Priorité: Élevée

## Objectif
Fournir aux clients un flux temps réel de données de marché (quotes et carnet d’ordres) sur un ou plusieurs symboles, via WebSocket (ActionCable), avec modes normal/throttled, et un mécanisme de dégradation contrôlée (degraded) en environnement de développement.

## Acteurs
- Client Web (UI Ordres)
- Serveur Web Rails (ActionCable)
- Émetteur de marché (simulateur dev: MarketDataBroadcaster)

## Préconditions
- Client authentifié (JWT HS256) — requis pour se connecter à ActionCable
- Symbole valide fourni par l’UI (par défaut: AAPL)
- En dev, un simulateur publie des mises à jour périodiques

## Postconditions (Succès)
- Connexion WebSocket établie
- Abonnement confirmé au canal `MarketChannel`
- Réception des messages `quote` et `orderbook` pour les symboles demandés
- Réception des messages `status` (niveau `ok`/`degraded`)

## Canal et protocole
- WebSocket URL: `/cable?token=<JWT>`
- Canal: `MarketChannel`
- Identifiant d’abonnement (ActionCable identifier):
```json
{"channel":"MarketChannel","symbols":["AAPL"],"mode":"normal"}
```
- Modes supportés: `normal` (par défaut) et `throttled` (rendu UI à ~1Hz)

## Authentification (JWT)
- Algorithme: HS256
- Issuer: `brokerx`
- Audience: `brokerx.web`
- Validation: signature + iss + aud + exp
- Transport: paramètre de requête `?token=...` dans l’URL WebSocket

Exemple de génération (côté serveur): via `secret_key_base`.

## Message schemas

### 1) Quote
```json
{
  "type": "quote",
  "symbol": "AAPL",
  "bid": 123.45,
  "ask": 123.55,
  "mid": 123.50,
  "ts": "2025-10-25T21:15:30.123Z"
}
```

### 2) Carnet d’ordres (orderbook)
```json
{
  "type": "orderbook",
  "symbol": "AAPL",
  "bids": [[123.40, 100], [123.35, 200]],
  "asks": [[123.60, 100], [123.65, 150]],
  "ts": "2025-10-25T21:15:30.123Z"
}
```

### 3) Statut flux
```json
{
  "type": "status",
  "level": "ok"  // ou "degraded"
}
```

Notes:
- Les valeurs numériques sont décimales (bid/ask/mid/prix) et entières pour les quantités du carnet.
- Le simulateur dev peut émettre `level: degraded` à intervalles réguliers.

## Séquences

1. Connexion WS à `/cable?token=<JWT>`
2. Envoi subscribe:
```json
{"command":"subscribe","identifier":"{\"channel\":\"MarketChannel\",\"symbols\":[\"AAPL\"],\"mode\":\"normal\"}"}
```
3. Réception `confirm_subscription`
4. Réception d’un snapshot initial (quote + orderbook)
5. Réception des mises à jour périodiques

## Erreurs & dégradations
- `reject_subscription`: JWT invalide/absent → l’UI affiche "rejeté (JWT manquant/invalide)".
- CDN ActionCable bloqué: l’UI charge un fallback WS brut (sans client npm) et continue.
- Statut `degraded`: l’UI affiche une bannière jaune et réduit la fréquence affichée si `throttled`.

## UI — Intégration (page Ordres)
- Panneau "Données de marché":
  - Statut connexion (initialisation, connecté, rejeté, déconnecté)
  - Bannière de dégradation
  - Toggle "Mode throttled" (rendu à ~1 Hz)
- Reconnexion automatique:
  - Changement du symbole (input + debounce)
  - Changement de mode (normal/throttled)
- Fallback:
  - Si ActionCable client CDN indisponible → raw WebSocket avec commandes JSON ActionCable

## Exemples

### Abonnement (ActionCable UMD)
```html
<script src="https://cdn.jsdelivr.net/npm/@rails/actioncable@7.1.5/dist/actioncable.umd.js"></script>
<script>
  const token = localStorage.getItem('auth_token');
  const cable = window.ActionCable.createConsumer(
    `${location.protocol === 'https:' ? 'wss://' : 'ws://'}${location.host}/cable?token=${encodeURIComponent(token)}`
  );
  const sub = cable.subscriptions.create(
    { channel: 'MarketChannel', symbols: ['AAPL'], mode: 'normal' },
    { received: (msg) => console.log('MSG', msg) }
  );
</script>
```

### Abonnement (fallback WS brut)
```js
const token = localStorage.getItem('auth_token');
const ws = new WebSocket(`${location.protocol === 'https:' ? 'wss://' : 'ws://'}${location.host}/cable?token=${encodeURIComponent(token)}`);
const identifier = JSON.stringify({ channel: 'MarketChannel', symbols: ['AAPL'], mode: 'normal' });
ws.addEventListener('open', () => {
  ws.send(JSON.stringify({ command: 'subscribe', identifier }));
});
ws.addEventListener('message', (ev) => {
  const msg = JSON.parse(ev.data);
  if (msg.message) console.log('MSG', msg.message);
});
```

## Critères d’acceptation
- CA‑04.01: Connexion avec JWT valide → `confirm_subscription` et messages `quote`/`orderbook` reçus.
- CA‑04.02: JWT invalide → `reject_subscription` et statut UI "rejeté".
- CA‑04.03: Changement de symbole (ex. AAPL → AMZN) → déconnexion propre + reconnexion, actualisation des données.
- CA‑04.04: Mode throttled → les mises à jour de rendu ne dépassent pas ~1 Hz.
- CA‑04.05: Statut `degraded` → bannière UI visible.

## Sécurité
- JWT signé (HS256) avec `secret_key_base`
- Paramètre `token` uniquement; aucune donnée sensible dans l’URL hormis le JWT (usage dev). En production, privilégier des cookies signés/headers au besoin.

## Tests
- Tests de canal: abonnement réussi, abonnement sans symboles, non authentifié (rejeté)
- Tests UI manuels: symbol switch, init sans CDN, statut dégradé, reconnexion

## Références
- `app/channels/market_channel.rb`
- `app/infrastructure/web/services/market_data_broadcaster.rb`
- `config/initializers/market_data_simulator.rb`
- `app/views/orders/index.html.erb` (panneau temps réel)
