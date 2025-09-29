# Agrégats du Domaine - BrokerX+

## Bounded Context: Client & Comptes

### Agrégat Client (Racine: Client)
**Entités**:
- `Client` (racine) : ID, nom, email, téléphone, statut
- `Compte` : ID, type, statut (Pending/Active/Rejected), date création
- `Portefeuille` : Solde, devise, historique transactions

**Value Objects**:
- `Email` : valeur validée, unique
- `Adresse` : rue, ville, code postal, pays
- `Solde` : montant, devise, contraintes ≥ 0

**Règles d'invariant**:
- Un Client a exactement un Compte
- Le Solde ne peut jamais être négatif
- Email doit être unique dans le système

**Repository**: `ClientRepository`

### Agrégat Transaction (Racine: Transaction)
**Entités**:
- `Transaction` (racine) : ID, type (Dépôt/Retrait), montant, statut

**Règles d'invariant**:
- Montant de transaction > 0
- Transaction doit référencer un Portefeuille valide

## Bounded Context: Ordres & Trading

### Agrégat Ordre (Racine: Ordre)
**Entités**:
- `Ordre` (racine) : ID, symbol, type (marché/limite), direction (achat/vente), quantité, prix, statut
- `Execution` : ID ordre, quantité exécutée, prix exécution

**Value Objects**:
- `Symbol` : code instrument validé
- `Prix` : valeur, tick size, contraintes de bande
- `Quantité` : nombre d'actions, > 0, multiple de lot

**Règles d'invariant**:
- Ordre marché n'a pas de prix spécifié
- Ordre limite doit avoir prix dans les bandes autorisées
- Quantité restante = quantité initiale - quantité exécutée

**Repository**: `OrderRepository`

### Agrégat CarnetOrdres (Racine: CarnetOrdres)
**Entités**:
- `CarnetOrdres` (racine) : Symbol, liste ordres achat/vente triés price-time

**Règles d'invariant**:
- Ordres achat triés prix décroissant + time croissant
- Ordres vente triés prix croissant + time croissant

## Bounded Context: Marché & Données

### Agrégat Instrument (Racine: Instrument)
**Entités**:
- `Instrument` (racine) : Symbol, nom, statut (actif/inactif), métadonnées

**Value Objects**:
- `Cotation` : prix, volume, horodatage
- `PlageTransaction` : prix min/max, tick size

**Règles d'invariant**:
- Symbol unique dans le système
- Prix courant doit être > 0

**Repository**: `InstrumentRepository`