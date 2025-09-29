# UC-01 - Inscription & Vérification d'identité

## Métadonnées
- **Identifiant**: UC-01
- **Version**: 1.0
- **Statut**: Must-Have
- **Priorité**: Haute

## Objectif
Permettre à un nouvel utilisateur de créer un compte sur la plateforme en fournissant ses informations personnelles, de vérifier son identité selon les exigences réglementaires (KYC/AML) et d'activer son accès à la plateforme.

## Acteurs
- **Principal**: Client (nouvel utilisateur)
- **Secondaire**: Système de vérification d'identité

## Déclencheur
L'utilisateur accède à la page d'inscription et souhaite créer un compte.

## Préconditions
- Aucune (accessible sans authentification)

## Postconditions (Succès)
- Compte créé avec statut "Pending"
- Compte passe à "Active" après validation email
- Journal d'audit créé avec horodatage et empreinte

## Postconditions (Échec)
- Compte non créé ou marqué "Rejected"
- Raison du rejet enregistrée dans le journal

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

### A1 - Vérification email non complétée
- Compte reste en statut "Pending"
- Système envoie des rappels automatiques (J+1, J+3)
- Expiration après 7 jours → compte marqué "Expired"

### A2 - Inscription avec référence
- Client entre un code de parrainage
- Système crédite un bonus après activation
- Journalise la relation de parrainage

## Exceptions

### E1 - Données dupliquées
- **Condition**: Email ou téléphone déjà existant
- **Traitement**: 
  - Rejet immédiat du formulaire
  - Proposition de récupération de compte
  - Message d'erreur clair

### E2 - Validation échouée
- **Condition**: Données invalides (email mal formaté, etc.)
- **Traitement**:
  - Affichage des erreurs de validation
  - Suggestion de correction
  - Conservation des données saisies

### E3 - Échec envoi email
- **Condition**: Service email indisponible
- **Traitement**:
  - Réessais automatiques (3x avec backoff)
  - Option "Renvoyer l'email" dans l'interface
  - Fallback SMS si téléphone fourni

## Critères d'Acceptation

### CA-01.01 - Inscription réussie
**Scenario**: Nouvel utilisateur avec données valides
- **Données**: nom="Dupont", email="jean.dupont@email.com", mot de passe valide
- **Action**: Soumission du formulaire
- **Résultat attendu**: 
  - Compte créé avec statut "Pending"
  - Email de vérification envoyé
  - Redirection vers page "Vérifiez votre email"

### CA-01.02 - Activation compte
**Scenario**: Utilisateur clique lien de vérification
- **Précondition**: Compte en statut "Pending"
- **Action**: Clic sur lien de vérification
- **Résultat attendu**:
  - Statut passe à "Active"
  - Notification de succès
  - Redirection vers tableau de bord

### CA-01.03 - Rejet doublon
**Scenario**: Email déjà existant
- **Précondition**: Compte existant avec "jean.dupont@email.com"
- **Action**: Tentative de réinscription avec même email
- **Résultat attendu**:
  - Message d'erreur "Email déjà utilisé"
  - Proposition de récupération de mot de passe

## Métriques
- Taux de conversion inscription → activation
- Temps moyen d'activation
- Taux d'échec par cause

## Aspects Sécurité
- Validation côté serveur des données
- Hashage des mots de passe (bcrypt)
- Tokens JWT avec expiration courte

## Règles Métier
- **RB-01**: Email doit être unique dans le système
- **RB-02**: Mot de passe minimum 8 caractères avec majuscule, minuscule, chiffre
- **RB-03**: Âge minimum 18 ans pour l'inscription
- **RB-04**: Compte expiré si non activé sous 7 jours