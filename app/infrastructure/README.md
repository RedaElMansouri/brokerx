# Couche Infrastructure (`Infrastructure::`)

Objectif : détails techniques et adaptateurs vers le monde extérieur.

Sous-dossiers courants :
- `persistence/` → modèles ActiveRecord (`ActiveRecord::Base`), implémentations de repositories
- `external/` → clients HTTP, files, intégrations tierces
- `web/` → (optionnel) contrôleurs/sérialiseurs HTTP si vous placez les adaptateurs web ici

Principes :
- Convertir entre enregistrements ActiveRecord et entités de Domaine via des mappers.
- Préserver ACID/transactions ici ; exposer des méthodes propres à la couche Application.
- Les contrôleurs résolvent les cas d’usage et repositories Applicatifs ; éviter la logique métier dans les contrôleurs.
