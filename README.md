# SPIRULINE Platform

Application web en français pour les producteurs de spiruline : espaces d’entreprise, comptes, rôles, bassins, récoltes, lots, stock, clients, commandes et traçabilité.

## Installation

Node.js 22.12 ou supérieur.

```sh
npm install
npm test
npm run build
npm run dev
```

Les versions directes sont fixées dans package.json. Le workflow conserve le package-lock.json généré en artifact ; le versionner pour figer aussi les dépendances transitives lors des prochaines installations.

La configuration publique Supabase est incluse. Pour un autre projet, copier .env.example vers .env et adapter les variables. Ne jamais utiliser de clé service_role ni de clé secrète dans le navigateur.

## Base Supabase existante

Projet : wimethopqfbzbwvgiqet. Les trois migrations dans supabase/migrations ont déjà été appliquées sur ce projet. Ne pas les rejouer manuellement sur cette base.

Les tables publiques activent RLS. Les utilisateurs authentifiés peuvent uniquement lire les données de leurs espaces. Les écritures utilisent des RPC qui contrôlent les droits côté serveur, vérifient les versions et sérialisent les mutations par entreprise. Les implémentations privilégiées résident dans le schéma privé sp_private.

30 tests PostgreSQL d’intégration ont été exécutés lors de l’installation initiale : séparation des entreprises, accès par rôle, invitations, versions concurrentes, protection des références, réservations, annulations, expéditions et prévention des dépassements de stock. Les données synthétiques ont été annulées par rollback. L’audit de sécurité Supabase était sans alerte après les migrations.

## Fonctions

- Inscription avec confirmation d’adresse, connexion, récupération de mot de passe.
- Création de plusieurs entreprises, devises EUR et XOF.
- Propriétaire, gestionnaire et lecteur ; invitations liées à une adresse, valables 7 jours.
- Bassins et récoltes ; lots avec masse sèche, état qualité et référence de certificat déclarée.
- Stock physique, réservé, expédié et disponible calculé par la base.
- Commandes à plusieurs lignes, prix par kilogramme et quantités en grammes.
- Réservation à la confirmation, libération à l’annulation, expédition définitive.
- Historique accessible au propriétaire et aux gestionnaires.
- Recherche, pagination, exports CSV protégés contre les formules et export JSON.

Les liens d’invitation sont à partager manuellement : aucun e-mail d’invitation d’équipe n’est envoyé.
Une référence de certificat ne vaut pas validation d’une certification bio.
Les prix sont des montants commerciaux sans calcul de TVA ni génération de facture fiscale.
La facturation d’abonnements SaaS, les pièces jointes et l’import d’anciennes données ne sont pas inclus.

## Publication

Le workflow .github/workflows/web.yml compile l’application et exécute les tests Node et navigateur. Sur main, il publie avec GitHub Pages.

Dans GitHub : Settings → Pages → Source : GitHub Actions.
L’adresse attendue après un déploiement réussi est https://issouf5.github.io/SPIRULINE_Platform/ ; elle n’est pas garantie active avant le succès du workflow.

Dans Supabase → Authentication → URL Configuration :
- Site URL : l’adresse réelle de publication.
- Redirect URLs : la même adresse, avec la barre finale ; ajouter http://localhost:5173/ pour le développement si nécessaire.

Configurer un fournisseur SMTP dans Supabase pour l’envoi des confirmations et récupérations de mot de passe aux utilisateurs externes. Les restrictions du service e-mail par défaut peuvent empêcher ces envois. Ce paramétrage n’est pas effectué par le code.

## Vérifications

```sh
npm test
npm run build
npx playwright install chromium
npm run test:browser
```

Les tests navigateur simulent les réponses d’authentification sans créer de comptes réels ni envoyer d’e-mails. Tester ensuite un parcours réel avec une adresse contrôlée après configuration des URL et du SMTP.

L’application actualise les données au chargement, après chaque modification et toutes les minutes lorsque l’onglet est visible. Un bouton permet d’actualiser manuellement. Elle n’autorise pas d’écriture hors ligne.
Les exports sont des copies de consultation, composées de plusieurs lectures ; ils ne sont pas une sauvegarde transactionnelle ni un format de restauration automatique.
