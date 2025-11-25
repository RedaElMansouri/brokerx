# UC-07 – Appariement d'ordres (Event-Driven + Outbox)

> Diagramme UML (séquence / events): `docs/use_cases/puml/UC07_appariement_evenementiel.puml` (à ajouter)

## Métadonnées
- **Identifiant**: UC-07
- **Version**: 1.0 (prototype event-driven)
- **Statut**: Must-Have (Phase 3)
- **Priorité**: Critique (cœur métier)

## Objectif
Transformer la logique d'appariement des ordres en flux événementiel fiable pour permettre l'extension (sagas, services séparés) tout en conservant la cohérence forte côté base de données via le pattern Outbox.

## Contexte
Historiquement le moteur d'appariement était appelé directement depuis le contrôleur (`OrdersController#create`) en mémoire. Nous introduisons une **Outbox** qui persiste les événements métier dans la même transaction que les ordres afin de garantir l'atomicité et d'éviter les pertes. Un **dispatcher** lit périodiquement les événements `order.created` et les injecte dans le moteur d'appariement. Le moteur publie ensuite des événements `execution.report` (working / filled) dans l'outbox pour diffusion et intégration future (reporting, notifications, compensation).

## Acteurs
- **Client** (soumet un ordre)
- **Service Ordres** (API REST)
- **Outbox** (table `outbox_events`)
- **Dispatcher Outbox** (thread Ruby, polling)
- **Moteur d'Appariement** (in‑memory, thread)
- **Service Portefeuilles** (réservation & engagement)
- **Canaux ActionCable** (diffusion temps réel)
- **Observabilité** (Prometheus / logs)

## Événements (Types & Payloads)
| Event Type | Emis par | Timing | Payload (clefs principales) | But |
|------------|----------|--------|------------------------------|-----|
| `order.created` | Controller | Dans la txn de création | `order_id`, `symbol`, `direction`, `order_type`, `quantity`, `price`, `correlation_id` | Déclenche l'appariement |
| `execution.report` | MatchingEngine | Après classification working ou trade | `order_id`, `status` (`working`/`filled`), `quantity`, `price`, `trade_id?`, `correlation_id?` | Feed clients / reporting |

`correlation_id` (UUID) est propagé du POST initial pour tracer l'ensemble du flux.

## Préconditions
- Ordre valide (voir UC‑05) et portefeuille suffisant pour réservations.
- Migration Outbox appliquée (`CreateOutboxEvents`).
- Dispatcher démarré (initializer `outbox_dispatcher.rb`).

## Postconditions (Succès)
- Ordre créé (statut `new`).
- Événement `order.created` inscrit dans Outbox (statut `pending`).
- Dispatcher convertit l'événement en entrée du moteur d'appariement.
- Ordre devient `working` ou `filled`; événements `execution.report` écrits.
- Diffusion temps réel (ActionCable) pour trades.
- Métriques mises à jour (counters + gauges).

## Postconditions (Échec)
- Validation pré‑trade échoue → aucun événement outbox.
- Erreur dans dispatcher → événement marqué `failed` avec `last_error` (rejouable / retry ultérieur).

## Flux Principal
1. **Client** → `POST /api/v1/orders` (payload ordre, optional `X-Correlation-Id`).
2. **Controller** valide + réserve fonds ACHAT.
3. **Txn DB**: persiste ordre + audit + écrit `outbox_events(status=pending,event_type=order.created)`.
4. Réponse HTTP 200 avec `order_id`, `lock_version`, `correlation_id`.
5. **Dispatcher** détecte `pending` → passe `processing` → appelle `MatchingEngine.enqueue_order`.
6. **MatchingEngine** cherche contrepartie.
   - Aucune contrepartie: statut ordre → `working`; écrit `execution.report` (working).
   - Contrepartie trouvée: trade exécuté; ordres → `filled`; écrit 2 × `execution.report` (filled + trade_id).
7. Métriques mises à jour (`orders_enqueued_total`, `orders_matched_total`, `trades_executed_total`, `outbox_events_total{type,status}`, `outbox_inflight`).
8. **ActionCable** broadcast trade vers flux `orders:<account_id>`.

## Flux Alternatifs / Erreurs
| Étape | Condition | Résultat |
|-------|-----------|----------|
| 2 | Validation métier échoue | 422 + message, pas d'événement |
| 5 | Exception lors de traitement | `failed` + incrément `outbox_dispatch_errors_total` |
| 6 | Aucun match | `execution.report(status=working)` pour visibilité |
| 6 | Trade partiel (non implémenté) | À traiter version ultérieure (fill partiel + reste working) |

## Observabilité
- **Metrics Prometheus**:
  - `outbox_inflight` (gauge) = nombre d'événements pending.
  - `outbox_events_total{type, status}` (counter).
  - `outbox_dispatch_errors_total{type}` (counter).
  - Hérité: `orders_enqueued_total`, `orders_matched_total`, `trades_executed_total`, `matching_queue_size`.
- **Logs**: préfixes `[OUTBOX]`, `[MATCHING]` pour corrélation.
- **Tracing**: `correlation_id` renvoyé au client et réutilisé dans payloads (extension future pour logs structurés).

## Sécurité
- Identique à UC‑05 (JWT obligatoire).
- Aucune donnée sensible dans payload événements (limité aux champs ordre publics + trade).

## Décisions d'Architecture (Résumé)
| Décision | Raison | Alternatives | Risques |
|----------|--------|-------------|---------|
| Outbox table locale | Atomicité ordre + événement | Broker direct (Kafka/NATS) | Thread unique ⇢ latence si volume élevé |
| Dispatcher thread polling | Simplicité implémentation | Job scheduler / Sidekiq | Contention multi-instances (améliorable) |
| Événements JSONB | Flexibilité schéma | Colonnes typées | Validation moins stricte |
| Execution report immédiat | Feedback rapide état ordre | Polling par client | Volume événements plus élevé |

## Critères d'Acceptation
### CA-07.01 – Ordre sans contrepartie
Précondition: Aucun ordre opposé même symbole.
Action: POST ordre limite ACHAT.
Résultat: Statut HTTP 200; ordre `new` → `working`; événement `execution.report(status=working)` présent.

### CA-07.02 – Appariement deux ordres opposés
Précondition: ORDRE A (ACHAT) + ORDRE B (VENTE) quantité & symbole identiques, prix compatibles.
Action: POST second ordre.
Résultat: Deux ordres `filled`; deux trades; deux événements `execution.report(status=filled)`.

### CA-07.03 – Échec dispatcher (simulation)
Précondition: Forcer exception dans `handle_order_created`.
Action: POST ordre.
Résultat: Événement `order.created` → `failed`; compteur `outbox_dispatch_errors_total` incrémenté.

## Exemple API (Création)
Request:
```http
POST /api/v1/orders
Authorization: Bearer <jwt>
X-Correlation-Id: 3ed1e2c8-6f5c-4d7f-9f6d-123456789abc
Content-Type: application/json

{
  "order": {
    "symbol": "AAPL",
    "order_type": "limit",
    "direction": "buy",
    "quantity": 10,
    "price": 100.0,
    "time_in_force": "DAY",
    "client_order_id": "ext-123"
  }
}
```
Réponse 200:
```json
{
  "success": true,
  "order_id": 421,
  "lock_version": 0,
  "correlation_id": "3ed1e2c8-6f5c-4d7f-9f6d-123456789abc",
  "message": "Order accepted (event queued)"
}
```

## Implémentation (Fichiers clés)
- `orders_controller.rb` : création ordre + écriture `order.created`.
- `outbox_event_record.rb` : modèle AR outbox.
- `outbox_dispatcher.rb` : polling + routing vers `MatchingEngine`.
- `matching_engine.rb` : appariement + écriture `execution.report`.
- Migration `create_outbox_events` : schéma JSONB + indexes.

