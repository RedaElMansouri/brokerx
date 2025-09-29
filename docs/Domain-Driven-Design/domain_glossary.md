# Glossaire du Domaine - BrokerX+

## Terminologie Métier Essentielle

| Terme Métier | Définition | Exemple | Règles Métier |
|--------------|------------|---------|---------------|
| **Client** | Investisseur particulier inscrit sur la plateforme | "Jean Dupont" | Doit avoir un email unique |
| **Compte** | Profil client avec état (Pending/Active/Rejected) | "Compte #123-ACTIVE" | Pending → Active après vérification email |
| **Portefeuille** | Ensemble des positions + solde monétaire | "Portefeuille Jean: 10 000€" | Solde ≥ 0 |
| **Solde** | Montant d'argent virtuel disponible | "Solde: 5 000€" | Incrémenté par dépôts, décrémenté par achats |
| **Ordre au Marché** | Ordre exécuté au meilleur prix disponible | "Acheter 10 AAPL au marché" | Pas de prix spécifié, exécution immédiate |
| **Ordre Limite** | Ordre à prix spécifié | "Vendre 5 AAPL à 150€" | Prix doit respecter les bandes autorisées |
| **Carnet d'ordres** | Liste des ordres ouverts par instrument | "Carnet AAPL: 100@150€ (achat), 50@152€ (vente)" | Tri price-time priority |
| **Cotation** | Prix courant d'un instrument | "AAPL: 148,50€" | Doit être > 0 |
| **Exécution** | Transaction entre acheteur et vendeur | "Execution: 10 AAPL @ 148,50€" | Quantité exécutée ≤ quantité ordre |
| **Contrôles Pré-trade** | Vérifications avant acceptation ordre | "Vérification solde: OK" | Bloque si pouvoir d'achat insuffisant |
| **Pouvoir d'achat** | Montant maximum investissable | "Pouvoir achat: 10 000€" | = Solde - engagements ouverts |
| **Symbol** | Code identifiant un instrument | "AAPL", "MSFT" | Unique, format [1-5 lettres majuscules] |
| **Instrument** | Produit financier tradable | "Action Apple Inc." | Doit être actif pour trading |
| **Dépôt virtuel** | Ajout de fonds virtuels | "Dépôt de 1 000€" | Montant entre 100€ et 10 000€ |
| **MFA** | Authentification Multi-Facteurs | "Code SMS à 6 chiffres" | Optionnel mais recommandé |
| **KYC/AML** | Conformité réglementaire | "Vérification identité" | Obligatoire pour compte Active |

## ❗Règles d'utilisation❗
- **Toujours utiliser** les termes métier dans les discussions techniques
- **Éviter** les équivalents techniques ambigus ("User" → "Client", "DB record" → "Ordre")
- **Maintenir** la cohérence entre code, documentation et communication