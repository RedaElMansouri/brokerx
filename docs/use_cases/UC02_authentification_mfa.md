# UC-02 - Authentification & MFA

## Métadonnées
- **Identifiant**: UC-02
- **Version**: 1.0
- **Statut**: Must-Have
- **Priorité**: Haute

## Objectif
Garantir un accès sécurisé à la plateforme en permettant aux clients de s'authentifier avec identifiant/mot de passe et, le cas échéant, via un mécanisme de multi-facteurs (OTP, TOTP, WebAuthn).

## Acteurs
- **Principal**: Client (compte Active)
- **Secondaire**: Système MFA, Service de logs de sécurité

## Déclencheur
Le Client accède à la page de connexion et saisit ses identifiants.

## Préconditions
- Compte existe et est en statut "Active"
- Client dispose d'un mot de passe valide

## Postconditions (Succès)
- Session valide établie (token JWT avec rôle Client)
- Journal de connexion mis à jour
- Dernière connexion mise à jour

## ❌ Postconditions (Échec)
- Aucune session créée
- Tentative journalisée (pour détection d'attaques)

## Flux Principal (Succès)

1. **Client** accède à la page de connexion
2. **Client** saisit email et mot de passe
3. **Système** valide les credentials :
   - Vérifie l'existence du compte
   - Compare le hash du mot de passe
   - Vérifie que le compte est actif


> Diagramme UML (séquence): `docs/use_cases/puml/UC02_authentification_mfa.puml`
4. **Système** applique les contrôles de sécurité :
   - Vérification réputation IP (optionnel)
   - Détection de brute force (limite tentatives)

5. **Si MFA activée** :
   - Système génère un code OTP (SMS/TOTP)
   - OU déclenche une notification push
   - Affiche l'interface de saisie MFA

6. **Client** saisit le code MFA valide
7. **Système** valide le code MFA :
   - Vérifie le code OTP (TOTP ou SMS)
   - OU valide la signature WebAuthn

8. **Système** crée la session :
   - Génère un token JWT (expiration 24h)
   - Enregistre la connexion (IP, device, timestamp)
   - Met à jour "dernière connexion"

9. **Client** est redirigé vers le tableau de bord

## Flux Alternatifs

### A1 - Appareil de confiance
- **Condition**: Client se connecte depuis un appareil déjà approuvé
- **Traitement**: 
  - MFA step-up uniquement pour opérations sensibles
  - Cookie "remember device" valide 30 jours

### A2 - MFA optionnelle
- **Condition**: Client n'a pas activé MFA
- **Traitement**:
  - Authentification simple email/mot de passe
  - Recommandation d'activer MFA

## Exceptions

### E1 - Échec MFA (3 tentatives)
- **Condition**: Codes MFA incorrects 3 fois de suite
- **Traitement**:
  - Verrouillage temporaire du compte (15 minutes)
  - Notification email d'activité suspecte
  - Journalisation sécurité

### E2 - Compte suspendu
- **Condition**: Compte en statut "Suspended"
- **Traitement**:
  - Accès refusé immédiatement
  - Message "Contactez le support"
  - Journalisation de la tentative

### E3 - Mot de passe expiré
- **Condition**: Mot de passe > 90 jours
- **Traitement**:
  - Forcer la réinitialisation
  - Redirection vers page "Réinitialiser mot de passe"

### E4 - Nouvel appareil détecté
- **Condition**: Connexion depuis IP/device inconnu
- **Traitement**:
  - MFA obligatoire même si désactivée
  - Notification email de nouvelle connexion

## Critères d'Acceptation

### CA-02.01 - Connexion simple réussie
**Scenario**: Client sans MFA
- **Précondition**: Compte actif, MFA désactivée
- **Action**: Saisie email/mot de passe valides
- **Résultat attendu**:
  - Token JWT généré
  - Redirection vers tableau de bord
  - Dernière connexion mise à jour

### CA-02.02 - Connexion MFA réussie
**Scenario**: Client avec MFA SMS
- **Précondition**: Compte actif, MFA SMS activée
- **Action**: 
  1. Saisie email/mot de passe valides
  2. Saisie code SMS reçu
- **Résultat attendu**:
  - Session créée après validation MFA
  - Journal MFA complété

### CA-02.03 - Échec credentials invalides
**Scenario**: Mot de passe incorrect
- **Précondition**: Compte existant
- **Action**: Saisie mot de passe erroné
- **Résultat attendu**:
  - Message "Identifiants invalides"
  - Compteur tentatives incrémenté
  - CAPTCHA après 3 échecs

### CA-02.04 - Verrouillage après échecs MFA
**Scenario**: 3 codes MFA incorrects
- **Précondition**: Compte avec MFA, étape MFA atteinte
- **Action**: Saisie de 3 codes MFA incorrects
- **Résultat attendu**:
  - Compte verrouillé 15 minutes
  - Email de notification envoyé
  - Message "Trop de tentatives, réessayez plus tard"

## Métriques
- Taux de réussite authentification
- Temps moyen de connexion
- Nombre de tentatives échouées
- Utilisation MFA par les clients

## Aspects Sécurité
- **Brute force protection**: Limite 5 tentatives/15min
- **Password hashing**: bcrypt avec salt
- **Session management**: JWT avec expiration, révocation possible
- **Device fingerprinting**: Détection nouvel appareil

## Règles Métier
- **RB-05**: Session expire après 24h d'inactivité
- **RB-06**: MFA recommandée pour tous les comptes
- **RB-07**: Verrouillage automatique après 5 échecs
- **RB-08**: Mot de passe expire après 90 jours