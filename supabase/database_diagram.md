# Zivo Supabase Database Diagram

This is the simple version of the database for the Flutter food-delivery app.
Supabase Auth owns login accounts in `auth.users`; the app stores public user
data in `profiles`.

## Core Diagram

```mermaid
erDiagram
    auth_users ||--|| profiles : owns
    profiles ||--o{ addresses : saves
    profiles ||--o{ payment_methods : saves
    profiles ||--o{ carts : owns
    profiles ||--o{ orders : places
    profiles ||--o{ wallet_transactions : has

    categories ||--o{ restaurants : groups
    restaurants ||--o{ menu_items : sells
    restaurants ||--o{ orders : receives

    carts ||--o{ cart_items : contains
    menu_items ||--o{ cart_items : selected

    orders ||--o{ order_items : contains
    menu_items ||--o{ order_items : purchased
    addresses ||--o{ orders : delivers_to
    payment_methods ||--o{ orders : paid_with
    delivery_partners ||--o{ orders : delivers
    orders ||--o{ order_events : tracks

    auth_users {
      uuid id PK
      text email
    }

    profiles {
      uuid id PK, FK
      text full_name
      text phone
      text avatar_url
      text membership_tier
      timestamptz created_at
    }

    addresses {
      uuid id PK
      uuid profile_id FK
      text label
      text line1
      text city
      text country
      boolean is_default
    }

    payment_methods {
      uuid id PK
      uuid profile_id FK
      text provider
      text brand
      text last_four
      text provider_payment_method_id
      boolean is_default
    }

    categories {
      uuid id PK
      text name
      text icon_name
      boolean is_active
    }

    restaurants {
      uuid id PK
      uuid category_id FK
      text name
      text image_url
      numeric rating
      integer delivery_fee
      integer minimum_order
      boolean is_open
    }

    menu_items {
      uuid id PK
      uuid restaurant_id FK
      text name
      text description
      integer price
      text image_url
      boolean is_available
    }

    carts {
      uuid id PK
      uuid profile_id FK
      uuid restaurant_id FK
      text status
    }

    cart_items {
      uuid id PK
      uuid cart_id FK
      uuid menu_item_id FK
      integer quantity
      integer unit_price
    }

    orders {
      uuid id PK
      uuid profile_id FK
      uuid restaurant_id FK
      uuid address_id FK
      uuid payment_method_id FK
      uuid delivery_partner_id FK
      text status
      integer subtotal
      integer delivery_fee
      integer tax
      integer total
    }

    order_items {
      uuid id PK
      uuid order_id FK
      uuid menu_item_id FK
      text item_name
      integer quantity
      integer unit_price
    }

    delivery_partners {
      uuid id PK
      text full_name
      text phone
      numeric rating
      boolean is_active
    }

    order_events {
      uuid id PK
      uuid order_id FK
      text status
      text message
      timestamptz created_at
    }

    wallet_transactions {
      uuid id PK
      uuid profile_id FK
      uuid order_id FK
      text type
      integer amount
      text description
      timestamptz created_at
    }
```

## Why This Is Kept Simple

- `profiles.id` is the same value as `auth.users.id`, so there is no duplicate
  auth table.
- Prices are stored as integers in the smallest currency unit, for example
  `350000` for NGN 3,500.00. This avoids floating point money bugs.
- `order_items.item_name` stores a snapshot so old orders still show the right
  dish name if a restaurant edits its menu later.
- Cards are not stored directly. `payment_methods` keeps only display metadata
  plus the payment provider's token/id.
- Order tracking is one flexible `order_events` table instead of many delivery
  tracking tables.

## Tables To Build First

1. `profiles`
2. `addresses`
3. `categories`
4. `restaurants`
5. `menu_items`
6. `carts`
7. `cart_items`
8. `orders`
9. `order_items`

Add `payment_methods`, `delivery_partners`, `order_events`, and
`wallet_transactions` after the basic ordering flow works.
