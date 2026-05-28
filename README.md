# RestoPOS — Application Flutter

Système de Gestion de Point de Vente pour Restaurant  
**Back-end**: Symfony (JWT) | **Front-end**: Flutter

---

## Structure du projet

```
pos_restaurant/
├── lib/
│   ├── main.dart                          ← Point d'entrée + Splash router
│   ├── core/
│   │   ├── constants.dart                 ← Couleurs, URLs, thème global
│   │   ├── api_service.dart               ← Service HTTP centralisé (JWT)
│   │   ├── widgets.dart                   ← Widgets réutilisables
│   │   └── main_layout.dart               ← Sidebar + Topbar (responsive)
│   └── features/
│       ├── auth/
│       │   ├── login_page.dart            ← Page Connexion
│       │   └── register_page.dart         ← Page Inscription
│       ├── company/
│       │   └── create_company_page.dart   ← Créer votre restaurant
│       ├── dashboard/
│       │   └── dashboard_page.dart        ← Statistiques ventes par période
│       ├── order/
│       │   └── order_page.dart            ← Commandes (cartes produits)
│       ├── sale/
│       │   └── sale_page.dart             ← Ventes validées
│       ├── product/
│       │   └── product_page.dart          ← Produits (tableau CRUD)
│       ├── category/
│       │   └── category_page.dart         ← Catégories (cartes colorées)
│       ├── supplier/
│       │   └── supplier_page.dart         ← Fournisseurs (tableau CRUD)
│       └── users/
│           └── users_page.dart            ← Utilisateurs (tableau CRUD)
└── pubspec.yaml
```

---

## Installation

```bash
# 1. Aller dans le dossier du projet
cd pos_restaurant

# 2. Installer les dépendances
flutter pub get

# 3. Lancer l'application
flutter run
```

---

## Configuration de l'API

Dans `lib/core/constants.dart`, modifier l'URL de base :

```dart
// Développement local
const String kBaseUrl = 'http://localhost:8000/api/v1';

// Android émulateur (remplace localhost par l'IP de la machine)
const String kBaseUrl = 'http://10.0.2.2:8000/api/v1';

// Production
const String kBaseUrl = 'https://votre-domaine.com/api/v1';
```

---

## Remplacer le logo fictif

Le logo actuel est une lettre "R" dans un carré vert.  
Pour le remplacer par votre vrai logo :

1. Ajoutez votre image dans `assets/logo.png`
2. Décommentez dans `pubspec.yaml` :
   ```yaml
   assets:
     - assets/logo.png
   ```
3. Remplacez dans `main_layout.dart`, `login_page.dart`, `main.dart` :
   ```dart
   // AVANT (logo fictif)
   Container(child: Text('R', ...))
   
   // APRÈS (vrai logo)
   Image.asset('assets/logo.png', width: 38, height: 38)
   ```

---

## Flux de navigation

```
Démarrage
    │
    ├── Token JWT présent → Dashboard
    └── Pas de token      → Login
                                │
                                ├── Connexion réussie → Dashboard
                                └── Créer un compte   → Register
                                                           │
                                                           └── Compte créé → Créer Restaurant
                                                                                    │
                                                                                    └── Restaurant créé → Dashboard
```

---

## Modules et endpoints utilisés

| Module       | Endpoints Symfony                                    |
|--------------|------------------------------------------------------|
| Auth         | POST /user/login, POST /user/register                |
| Restaurant   | POST /company/create, GET /company/list              |
| Dashboard    | POST /sale_history/period, GET /sale_history/all     |
| Commandes    | GET /product/list, POST /checkout/order, POST /checkout/cancel |
| Ventes       | GET /sale_history/all, POST /checkout/sale, POST /checkout/cancelsale |
| Produits     | GET /product/list, POST /product/create, PUT /product/modify/{id}, DELETE /product/delete/{id} |
| Catégories   | GET /category/list, POST /category/create, PUT /category/modify/{id}, DELETE /category/delete/{id} |
| Fournisseurs | GET /supplier/list, POST /supplier/create, PUT /supplier/modify/{id}, DELETE /supplier/delete/{id} |
| Utilisateurs | GET /user/list, POST /user/create, PUT /user/modify/{id}, DELETE /user/delete/{id} |

---

## Rôles utilisateur

| Rôle          | Accès                                          |
|---------------|------------------------------------------------|
| ROLE_ADMIN    | Tout + gestion des restaurants                 |
| ROLE_MANAGER  | Tout sauf création de restaurant               |
| ROLE_TELLER   | Ventes, validation commandes                   |
| ROLE_WAITER   | Commandes, consultation produits/catégories    |
