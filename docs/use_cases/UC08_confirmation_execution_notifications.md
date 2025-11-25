# UC-08 – Confirmation d’exécution & Notifications

> Diagramme UML : `docs/use_cases/puml/UC08_confirmation_execution_notifications.puml`

## Métadonnées
- **Identifiant**: UC-08
- **Version**: 1.0 (prototype)
- **Statut**: Must-Have (Phase 3)
- **Priorité**: Haute

## Objectif
Notifier de manière fiable et traçable le client de l’état final (ou intermédiaire) de ses ordres : exécution partielle, exécution totale, statut working, annulation ou autres évènements de vie. Améliore la transparence et la confiance dans la plateforme.

## Acteurs
- **Principal**: Système (source d’évènements d’exécution)
- **Secondaires**: Client (UI temps réel), Back-Office (audit / supervision)

## Déclencheur
Réception (création) d’un évènement `execution.report` dans l’Outbox.

## Préconditions
- Ordre existant (créé via UC‑05 / UC‑07).
- Évènement `execution.report` écrit par le moteur d’appariement (UC‑07) dans la table `outbox_events`.

## Postconditions (Succès)
- État de l’ordre mis à jour (filled / working / cancelled / etc.).
- Notification temps réel envoyée (ActionCable + canal de statut).
- Mail de confirmation programmé (fallback) si WebSocket indisponible.
- Audit inexistant explicitement (report) mais traçabilité via: audit_events + outbox_events.

## Postconditions (Échec)
- Échec de notification (ActionCable ou mail) n’invalide pas l’exécution; l’évènement reste marqué processed.
- Un log d’erreur est produit et métriques d’erreurs peuvent être étendues.

## Types d’Évènements Concernés
| Type | Source | Statuts couverts |
|------|--------|------------------|
| execution.report | MatchingEngine (UC‑07) | working, filled (future: partial, cancelled, rejected) |

## Flux Principal (Succès)
1. Moteur d’appariement écrit un `execution.report` (pending) dans l’Outbox (ex : `status=filled`).
2. Dispatcher outbox poll → passe l’évènement à `processing`.
3. Dispatcher traite: broadcast temps réel (canal `orders_status:<order_id>`).
4. Dispatcher déclenche un e-mail de confirmation (deliver_later) pour robustesse.
5. Dispatcher marque l’évènement `processed`.
6. UI cliente affiche la confirmation (via WebSocket) et met à jour l’état local.

## Flux Alternatifs / Exceptions
| Code | Condition | Traitement |
|------|-----------|------------|
| A1 | Plusieurs partial fills futurs | Agrégation côté UI ou envoi groupé (non implémenté) |
| E1 | Échec broadcast ActionCable | Log + continuer mail fallback |
| E2 | Échec mail (SMTP down) | Log; aucun retry (prototype); ajout futur d’un retry queue |
| E3 | Ordre introuvable | Log; évènement tout de même marqué processed |

## Critères d’Acceptation
### CA-08.01 – Confirmation exécution totale
Précondition: Deux ordres opposés appariés (UC‑07).
Action: Exécution entraîne `execution.report` filled.
Résultat: Client reçoit un message temps réel; mail programmé.

### CA-08.02 – Confirmation working
Précondition: Ordre sans contrepartie.
Action: Moteur met statut à working.
Résultat: Client reçoit un `execution.report` working.

### CA-08.03 – Robustesse notification
Précondition: Simuler échec broadcast.
Action: Exception dans ActionCable.
Résultat: Mail still queued; évènement processed.

## API / Channels
- Canal ActionCable existant trades: `orders:<account_id>`.
- Nouveau canal statut (diffusé via dispatcher): `orders_status:<order_id>`.
- Emails: `ExecutionReportMailer#execution_report` (HTML simple).

## Observabilité
- Métriques existantes: `outbox_events_total{type,status}`.
- Extensions futures: compteur d’échecs de notification (ex: `notification_errors_total`).
- Logs préfixes `[OUTBOX] execution.report broadcast failed` / `mail failed`.

## Sécurité
- Aucune donnée sensible additionnelle (order_id, statut, price, quantity).
- Authentification préalable pour accéder au flux temps réel (connexion ActionCable par client_id).

## Limites / Backlog
- Partial fills non implémentés (nécessiterait tracking quantités restantes + agrégation).
- Retry emails absent (possibilité d’intégrer ActiveJob + queue).
- Global de-dup côté client non nécessaire (idempotence via order_id + statut).
- External broker (Kafka) en backlog pour diffusion inter-services.

## Implémentation (Résumé)
- `matching_engine.rb` : écrit `execution.report` outbox.
- `outbox_dispatcher.rb` : traite `execution.report` → broadcast + mail + status processed.
- `execution_report_mailer.rb` + template HTML.

## Diagramme
Voir PlantUML pour séquence détaillée.

---
_Dernière mise à jour: 2025-11-18_
