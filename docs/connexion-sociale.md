# Connexion Google et Facebook

Les boutons apparaissent dans la connexion et l’inscription uniquement pour les fournisseurs activés dans Supabase. Recharger la page après activation. En cas de panne des paramètres publics, la connexion e-mail reste utilisable.

## Configuration

Dans Supabase → Authentication → Sign In / Providers :
- Google : activer et renseigner le Client ID et le Client Secret d’un client OAuth Web Google. Origine JavaScript autorisée : https://issouf5.github.io . URI de redirection autorisée : https://wimethopqfbzbwvgiqet.supabase.co/auth/v1/callback .
- Facebook : configurer Facebook Login dans une application Meta, puis renseigner App ID et App Secret dans Supabase. Ajouter la même URI de retour Supabase dans les URI de redirection OAuth valides. L’application demande l’autorisation e-mail.
- Configurer l’audience/publication chez Google et Meta pour les utilisateurs externes. Le mode test limite les comptes autorisés.
- Conserver https://issouf5.github.io/SPIRULINE_Platform/ dans les Redirect URLs de Supabase.
- Email : régler également la longueur minimale à 8 dans Supabase pour une règle cohérente côté serveur. L’inscription et le nouveau mot de passe exigent désormais 8 caractères dans le formulaire ; les mots de passe existants restent utilisables à la connexion.

Les secrets doivent rester dans les consoles Google/Meta et Supabase, jamais dans le dépôt ou le navigateur.
Les tests simulent OAuth et n’activent pas les fournisseurs. Tester une connexion réelle après configuration. Le compte connecté doit utiliser l’adresse destinataire pour accepter une invitation.

Documentation officielle : [Google](https://supabase.com/docs/guides/auth/social-login/auth-google) et [Facebook](https://supabase.com/docs/guides/auth/social-login/auth-facebook).
