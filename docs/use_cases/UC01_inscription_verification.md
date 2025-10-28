# UC-01 - Inscription & Vérification d'identité

## Métadonnées
- **Identifiant**: UC-01
## Objectif
Permettre à un nouvel utilisateur de créer un compte sur la plateforme en fournissant ses informations personnelles, de vérifier son identité selon les exigences réglementaires (KYC/AML) et d'activer son accès à la plateforme.

## Acteurs
- **Principal**: Client (nouvel utilisateur)
## Déclencheur
L'utilisateur accède à la page d'inscription et souhaite créer un compte.

## Préconditions
- Aucune (accessible sans authentification)
## Postconditions (Succès)
- Compte créé avec statut "Pending"
## Postconditions (Échec)
- Compte non créé ou marqué "Rejected"
## Flux Principal (Succès)

1. **Client** remplit le formulaire d'inscription :
   - Email valide et unique
   - Téléphone (optionnel)
   - Mot de passe (règles de complexité)
   - Données personnelles : nom, prénom, date de naissance, adresse

2. **Système** valide les données :
   - Format email valide
   - Email non déjà utilisé
   - Mot de passe conforme aux politiques
   - Données obligatoires présentes

3. **Système** crée le compte avec statut "Pending" :
   - Génère un ID client unique
   - Hash le mot de passe (bcrypt)
   - Crée un portefeuille avec solde à 0
   - Journalise l'action

4. **Système** envoie un email de vérification :
   - Lien unique avec token JWT (expiration 24h)
   - OU Code OTP par SMS si téléphone fourni

5. **Client** clique sur le lien/entre le code :
   - Token validé par le système
   - Statut du compte passe à "Active"

6. **Système** notifie le client :
   - Email de bienvenue
   - Accès activé à la plateforme

## Flux Alternatifs
> Diagramme UML (séquence): `docs/use_cases/puml/UC01_inscription_verification.puml`

### A1 - Vérification email non complétée
- Compte reste en statut "Pending"
- Système envoie des rappels automatiques (J+1, J+3)
- Client entre un code de parrainage
- Système crédite un bonus après activation

### E1 - Données dupliquées
- **Condition**: Email ou téléphone déjà existant
- **Traitement**: 
  - Message d'erreur clair

### E2 - Validation échouée
- **Condition**: Données invalides (email mal formaté, etc.)
- **Traitement**:
  - Conservation des données saisies

### E3 - Échec envoi email
- **Condition**: Service email indisponible
- **Traitement**:
  - Fallback SMS si téléphone fourni

## Critères d'Acceptation

### CA-01.01 - Inscription réussie
**Scenario**: Nouvel utilisateur avec données valides
- **Données**: nom="Dupont", email="jean.dupont@email.com", mot de passe valide
- **Action**: Soumission du formulaire
  - Redirection vers page "Vérifiez votre email"

### CA-01.02 - Activation compte
**Scenario**: Utilisateur clique lien de vérification
- **Précondition**: Compte en statut "Pending"
- **Action**: Clic sur lien de vérification
  - Redirection vers tableau de bord

### CA-01.03 - Rejet doublon
**Scenario**: Email déjà existant
- **Précondition**: Compte existant avec "jean.dupont@email.com"
- **Action**: Tentative de réinscription avec même email

## Métriques
- Taux de conversion inscription → activation
- Temps moyen d'activation
- Validation côté serveur des données
- Hashage des mots de passe (bcrypt)
- **RB-01**: Email doit être unique dans le système
- **RB-02**: Mot de passe minimum 8 caractères avec majuscule, minuscule, chiffre