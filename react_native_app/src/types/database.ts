// Generated types for the Zivo/Eatzy Supabase project's `public` schema
// (issue #348).
//
// HOW THIS FILE WAS PRODUCED -- read before regenerating
// ---------------------------------------------------------------------
// This file is normally produced by `npm run gen:types`
// (`supabase gen types typescript --project-id <ref> --schema public`),
// which needs either a `supabase login` session with network access to the
// live project, or a local Supabase stack running in Docker
// (`supabase start` + `supabase gen types typescript --local`). Neither was
// reachable from the sandbox that authored this file (no Supabase CLI
// login, no network route to the project, no Docker daemon for a local
// stack), so this file was HAND-AUTHORED instead, in the exact shape the
// CLI would emit, by reading every file in `supabase/migrations/` in
// timestamp order and reconciling it against `supabase/schema.sql`.
//
// SCHEMA DRIFT FOUND WHILE DOING THIS (flagged per AGENTS.md's existing
// warning that `supabase/schema.sql` does not reliably match the live
// project):
//
//   1. `supabase/schema.sql`'s own header says it is a snapshot "regenerated
//      on 2026-09-18" / last touched 2026-09-25, but it is already missing
//      columns added by migrations dated BEFORE that: `profiles.dob`
//      (20260923000000_add_profile_dob_and_signup_metadata.sql) and
//      `grocery_stores.image_url` / `pharmacy_stores.image_url`
//      (20260922020000_add_store_image_urls.sql) appear nowhere in it. This
//      file includes them, taking the migration chain as the more current
//      source of truth, per AGENTS.md's instruction to prefer what the app
//      actually uses when schema.sql and reality disagree.
//   2. Columns added by migrations dated AFTER schema.sql's last snapshot
//      are also included here: `grocery_categories` (new table) and
//      `grocery_products.category_id`
//      (20260926000000_add_grocery_categories.sql), `grocery_stores.store_type`
//      (20260927000000_add_grocery_store_type.sql), and
//      `grocery_products.image_url` / `pharmacy_products.image_url`
//      (20260925000000_add_merchant_media_uploads.sql).
//   3. `public.addresses`, referenced only in code comments inside
//      `20260919000000_add_delete_own_account_rpc.sql` (a migration later
//      superseded by `20260924010000_fix_delete_own_account_anonymize.sql`,
//      which drops that reference), is NOT a real table anywhere in the
//      migration chain -- `public.delivery_addresses` is the actual shared
//      address table (20260917000000_add_shared_delivery_addresses.sql). It
//      is deliberately NOT included below.
//   4. AGENTS.md states every money column is integer cents after issue #8
//      (20260903000000_convert_money_columns_to_cents.sql). That migration's
//      own comment says it deliberately left `deals.deal_price` untouched
//      (the cleaning vertical's money columns were dropped instead of
//      converted, and `deals` was not in its conversion list). So
//      `deals.deal_price` is still `numeric(10,2)` decimal dollars, NOT
//      cents, unlike every other money column in this schema -- typed below
//      as `number` to match the live column, with this note as the flag
//      AGENTS.md asks for rather than silently assuming it was converted.
//   5. Trigger-only functions (`handle_new_user`, `set_updated_at`) and the
//      `private.anonymize_account` helper are not callable via
//      PostgREST/RPC and are intentionally omitted from `Functions`, matching
//      what the real CLI would emit.
//   6. Foreign keys that reference `auth.users` (e.g.
//      `food_orders.profile_id`, `profiles.id`) are NOT given a
//      `Relationships` entry below, matching the real CLI's behavior when
//      only the `public` schema is generated -- `auth` is a different
//      schema the generator does not resolve.
//
// REGENERATING THIS FILE
// ---------------------------------------------------------------------
// Run `npm run gen:types` after every migration lands in
// `supabase/migrations/` (see `react_native_app/README.md`). Once a real
// Supabase CLI session can reach the project (or a local Docker stack is
// available), that script's `supabase gen types typescript ...` output
// should simply overwrite this file -- there is nothing hand-authored here
// that needs preserving once a real generation path exists.

export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[];

export type Database = {
  public: {
    Tables: {
      deal_items: {
        Row: {
          id: string;
          deal_id: string;
          menu_item_id: string;
          quantity: number;
          created_at: string;
        };
        Insert: {
          id?: string;
          deal_id: string;
          menu_item_id: string;
          quantity?: number;
          created_at?: string;
        };
        Update: {
          id?: string;
          deal_id?: string;
          menu_item_id?: string;
          quantity?: number;
          created_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "deal_items_deal_id_fkey";
            columns: ["deal_id"];
            isOneToOne: false;
            referencedRelation: "deals";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "deal_items_menu_item_id_fkey";
            columns: ["menu_item_id"];
            isOneToOne: false;
            referencedRelation: "menu_items";
            referencedColumns: ["id"];
          },
        ];
      };
      deals: {
        Row: {
          id: string;
          restaurant_id: string;
          name: string;
          description: string | null;
          /** numeric(10,2) decimal dollars -- NOT cents. See file header, drift note #4. */
          deal_price: number;
          image_url: string | null;
          is_active: boolean;
          starts_at: string | null;
          ends_at: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          restaurant_id: string;
          name: string;
          description?: string | null;
          deal_price: number;
          image_url?: string | null;
          is_active?: boolean;
          starts_at?: string | null;
          ends_at?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          restaurant_id?: string;
          name?: string;
          description?: string | null;
          deal_price?: number;
          image_url?: string | null;
          is_active?: boolean;
          starts_at?: string | null;
          ends_at?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "deals_restaurant_id_fkey";
            columns: ["restaurant_id"];
            isOneToOne: false;
            referencedRelation: "restaurants";
            referencedColumns: ["id"];
          },
        ];
      };
      delivery_addresses: {
        Row: {
          id: string;
          profile_id: string;
          label: string | null;
          recipient_name: string;
          phone: string;
          street: string;
          district: string;
          city: string;
          is_default: boolean;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          profile_id: string;
          label?: string | null;
          recipient_name: string;
          phone: string;
          street: string;
          district: string;
          city: string;
          is_default?: boolean;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          profile_id?: string;
          label?: string | null;
          recipient_name?: string;
          phone?: string;
          street?: string;
          district?: string;
          city?: string;
          is_default?: boolean;
          created_at?: string;
          updated_at?: string;
        };
        Relationships: [];
      };
      food_order_items: {
        Row: {
          id: number;
          order_id: string;
          menu_item_id: string | null;
          item_name: string;
          quantity: number;
          unit_price: number;
          created_at: string;
        };
        Insert: {
          id?: number;
          order_id: string;
          menu_item_id?: string | null;
          item_name: string;
          quantity: number;
          unit_price: number;
          created_at?: string;
        };
        Update: {
          id?: number;
          order_id?: string;
          menu_item_id?: string | null;
          item_name?: string;
          quantity?: number;
          unit_price?: number;
          created_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "food_order_items_menu_item_id_fkey";
            columns: ["menu_item_id"];
            isOneToOne: false;
            referencedRelation: "menu_items";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "food_order_items_order_id_fkey";
            columns: ["order_id"];
            isOneToOne: false;
            referencedRelation: "food_orders";
            referencedColumns: ["id"];
          },
        ];
      };
      food_orders: {
        Row: {
          id: string;
          profile_id: string;
          restaurant_id: string;
          restaurant_name: string;
          status: string;
          subtotal: number;
          delivery_fee: number;
          tax: number;
          total: number;
          currency: string;
          country: string;
          is_demo: boolean;
          created_at: string;
          updated_at: string;
          recipient_name: string;
          phone: string;
          street: string;
          district: string;
          city: string;
          payment_method: string;
          payment_status: string;
          idempotency_key: string | null;
          delivery_address_id: string | null;
        };
        Insert: {
          id?: string;
          profile_id: string;
          restaurant_id: string;
          restaurant_name: string;
          status?: string;
          subtotal: number;
          delivery_fee?: number;
          tax?: number;
          total: number;
          currency?: string;
          country?: string;
          is_demo?: boolean;
          created_at?: string;
          updated_at?: string;
          recipient_name?: string;
          phone?: string;
          street?: string;
          district?: string;
          city?: string;
          payment_method?: string;
          payment_status?: string;
          idempotency_key?: string | null;
          delivery_address_id?: string | null;
        };
        Update: {
          id?: string;
          profile_id?: string;
          restaurant_id?: string;
          restaurant_name?: string;
          status?: string;
          subtotal?: number;
          delivery_fee?: number;
          tax?: number;
          total?: number;
          currency?: string;
          country?: string;
          is_demo?: boolean;
          created_at?: string;
          updated_at?: string;
          recipient_name?: string;
          phone?: string;
          street?: string;
          district?: string;
          city?: string;
          payment_method?: string;
          payment_status?: string;
          idempotency_key?: string | null;
          delivery_address_id?: string | null;
        };
        Relationships: [
          {
            foreignKeyName: "food_orders_delivery_address_id_fkey";
            columns: ["delivery_address_id"];
            isOneToOne: false;
            referencedRelation: "delivery_addresses";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "food_orders_restaurant_id_fkey";
            columns: ["restaurant_id"];
            isOneToOne: false;
            referencedRelation: "restaurants";
            referencedColumns: ["id"];
          },
        ];
      };
      grocery_categories: {
        Row: {
          id: string;
          name: string;
          sort_order: number;
          is_active: boolean;
          created_at: string;
        };
        Insert: {
          id: string;
          name: string;
          sort_order?: number;
          is_active?: boolean;
          created_at?: string;
        };
        Update: {
          id?: string;
          name?: string;
          sort_order?: number;
          is_active?: boolean;
          created_at?: string;
        };
        Relationships: [];
      };
      grocery_delivery_slots: {
        Row: {
          id: string;
          store_id: string;
          label: string;
          detail: string;
          day_offset: number;
          start_time: string;
          end_time: string;
          sort_order: number;
          is_active: boolean;
          created_at: string;
        };
        Insert: {
          id: string;
          store_id: string;
          label: string;
          detail: string;
          day_offset: number;
          start_time: string;
          end_time: string;
          sort_order?: number;
          is_active?: boolean;
          created_at?: string;
        };
        Update: {
          id?: string;
          store_id?: string;
          label?: string;
          detail?: string;
          day_offset?: number;
          start_time?: string;
          end_time?: string;
          sort_order?: number;
          is_active?: boolean;
          created_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "grocery_delivery_slots_store_id_fkey";
            columns: ["store_id"];
            isOneToOne: false;
            referencedRelation: "grocery_stores";
            referencedColumns: ["id"];
          },
        ];
      };
      grocery_order_items: {
        Row: {
          id: number;
          order_id: string;
          product_id: string | null;
          product_name: string;
          pricing_unit: string;
          quantity: number;
          unit_price: number;
          created_at: string;
        };
        Insert: {
          id?: number;
          order_id: string;
          product_id?: string | null;
          product_name: string;
          pricing_unit: string;
          quantity: number;
          unit_price: number;
          created_at?: string;
        };
        Update: {
          id?: number;
          order_id?: string;
          product_id?: string | null;
          product_name?: string;
          pricing_unit?: string;
          quantity?: number;
          unit_price?: number;
          created_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "grocery_order_items_order_id_fkey";
            columns: ["order_id"];
            isOneToOne: false;
            referencedRelation: "grocery_orders";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "grocery_order_items_product_id_fkey";
            columns: ["product_id"];
            isOneToOne: false;
            referencedRelation: "grocery_products";
            referencedColumns: ["id"];
          },
        ];
      };
      grocery_orders: {
        Row: {
          id: string;
          profile_id: string;
          store_id: string;
          store_name: string;
          delivery_slot_id: string | null;
          delivery_slot_label: string;
          delivery_window_start: string;
          delivery_window_end: string;
          recipient_name: string;
          phone: string;
          street: string;
          district: string;
          city: string;
          substitution_preference: string;
          status: string;
          subtotal: number;
          delivery_fee: number;
          total: number;
          currency: string;
          country: string;
          is_demo: boolean;
          created_at: string;
          updated_at: string;
          idempotency_key: string | null;
          payment_method: string;
          payment_status: string;
          delivery_address_id: string | null;
        };
        Insert: {
          id?: string;
          profile_id: string;
          store_id: string;
          store_name: string;
          delivery_slot_id?: string | null;
          delivery_slot_label: string;
          delivery_window_start: string;
          delivery_window_end: string;
          recipient_name?: string;
          phone?: string;
          street?: string;
          district?: string;
          city?: string;
          substitution_preference: string;
          status?: string;
          subtotal: number;
          delivery_fee?: number;
          total: number;
          currency?: string;
          country?: string;
          is_demo?: boolean;
          created_at?: string;
          updated_at?: string;
          idempotency_key?: string | null;
          payment_method?: string;
          payment_status?: string;
          delivery_address_id?: string | null;
        };
        Update: {
          id?: string;
          profile_id?: string;
          store_id?: string;
          store_name?: string;
          delivery_slot_id?: string | null;
          delivery_slot_label?: string;
          delivery_window_start?: string;
          delivery_window_end?: string;
          recipient_name?: string;
          phone?: string;
          street?: string;
          district?: string;
          city?: string;
          substitution_preference?: string;
          status?: string;
          subtotal?: number;
          delivery_fee?: number;
          total?: number;
          currency?: string;
          country?: string;
          is_demo?: boolean;
          created_at?: string;
          updated_at?: string;
          idempotency_key?: string | null;
          payment_method?: string;
          payment_status?: string;
          delivery_address_id?: string | null;
        };
        Relationships: [
          {
            foreignKeyName: "grocery_orders_delivery_address_id_fkey";
            columns: ["delivery_address_id"];
            isOneToOne: false;
            referencedRelation: "delivery_addresses";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "grocery_orders_delivery_slot_id_fkey";
            columns: ["delivery_slot_id"];
            isOneToOne: false;
            referencedRelation: "grocery_delivery_slots";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "grocery_orders_store_id_fkey";
            columns: ["store_id"];
            isOneToOne: false;
            referencedRelation: "grocery_stores";
            referencedColumns: ["id"];
          },
        ];
      };
      grocery_products: {
        Row: {
          id: string;
          store_id: string;
          name: string;
          description: string;
          unit_price: number;
          pricing_unit: string;
          quantity_step: number;
          available_quantity: number;
          low_stock_threshold: number;
          icon: string;
          is_active: boolean;
          created_at: string;
          updated_at: string;
          /** Added by 20260926000000_add_grocery_categories.sql. */
          category_id: string | null;
          /** Added by 20260925000000_add_merchant_media_uploads.sql. */
          image_url: string | null;
        };
        Insert: {
          id: string;
          store_id: string;
          name: string;
          description?: string;
          unit_price: number;
          pricing_unit: string;
          quantity_step: number;
          available_quantity: number;
          low_stock_threshold?: number;
          icon?: string;
          is_active?: boolean;
          created_at?: string;
          updated_at?: string;
          category_id?: string | null;
          image_url?: string | null;
        };
        Update: {
          id?: string;
          store_id?: string;
          name?: string;
          description?: string;
          unit_price?: number;
          pricing_unit?: string;
          quantity_step?: number;
          available_quantity?: number;
          low_stock_threshold?: number;
          icon?: string;
          is_active?: boolean;
          created_at?: string;
          updated_at?: string;
          category_id?: string | null;
          image_url?: string | null;
        };
        Relationships: [
          {
            foreignKeyName: "grocery_products_store_id_fkey";
            columns: ["store_id"];
            isOneToOne: false;
            referencedRelation: "grocery_stores";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "grocery_products_category_id_fkey";
            columns: ["category_id"];
            isOneToOne: false;
            referencedRelation: "grocery_categories";
            referencedColumns: ["id"];
          },
        ];
      };
      grocery_stores: {
        Row: {
          id: string;
          name: string;
          area: string;
          is_active: boolean;
          created_at: string;
          updated_at: string;
          owner_id: string | null;
          /** Added by 20260922020000_add_store_image_urls.sql (missing from schema.sql -- see file header). */
          image_url: string | null;
          /** Added by 20260927000000_add_grocery_store_type.sql: 'grocery' | 'fresh_meat' | 'electronics'. */
          store_type: string;
        };
        Insert: {
          id: string;
          name: string;
          area: string;
          is_active?: boolean;
          created_at?: string;
          updated_at?: string;
          owner_id?: string | null;
          image_url?: string | null;
          store_type?: string;
        };
        Update: {
          id?: string;
          name?: string;
          area?: string;
          is_active?: boolean;
          created_at?: string;
          updated_at?: string;
          owner_id?: string | null;
          image_url?: string | null;
          store_type?: string;
        };
        Relationships: [
          {
            foreignKeyName: "grocery_stores_owner_id_fkey";
            columns: ["owner_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
        ];
      };
      item_categories: {
        Row: {
          id: string;
          name: string | null;
          icon_url: string;
          is_active: boolean;
        };
        Insert: {
          id?: string;
          name?: string | null;
          icon_url: string;
          is_active?: boolean;
        };
        Update: {
          id?: string;
          name?: string | null;
          icon_url?: string;
          is_active?: boolean;
        };
        Relationships: [];
      };
      menu_items: {
        Row: {
          id: string;
          name: string;
          description: string;
          price: number;
          image_url: string;
          categorie_id: string | null;
          restaurant_id: string | null;
          is_available: boolean;
        };
        Insert: {
          id?: string;
          name: string;
          description: string;
          price: number;
          image_url: string;
          categorie_id?: string | null;
          restaurant_id?: string | null;
          is_available?: boolean;
        };
        Update: {
          id?: string;
          name?: string;
          description?: string;
          price?: number;
          image_url?: string;
          categorie_id?: string | null;
          restaurant_id?: string | null;
          is_available?: boolean;
        };
        Relationships: [
          {
            foreignKeyName: "menu_items_categorie_id_fkey";
            columns: ["categorie_id"];
            isOneToOne: false;
            referencedRelation: "item_categories";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "menu_items_restaurant_id_fkey";
            columns: ["restaurant_id"];
            isOneToOne: false;
            referencedRelation: "restaurants";
            referencedColumns: ["id"];
          },
        ];
      };
      order_status_events: {
        Row: {
          id: string;
          vertical: string;
          order_id: string;
          previous_status: string;
          new_status: string;
          changed_by: string;
          created_at: string;
        };
        Insert: {
          id?: string;
          vertical: string;
          order_id: string;
          previous_status: string;
          new_status: string;
          changed_by: string;
          created_at?: string;
        };
        Update: {
          id?: string;
          vertical?: string;
          order_id?: string;
          previous_status?: string;
          new_status?: string;
          changed_by?: string;
          created_at?: string;
        };
        Relationships: [];
      };
      payment_methods: {
        Row: {
          id: string;
          profile_id: string;
          provider: string;
          brand: string;
          last_four: string;
          provider_payment_method_id: string;
          is_default: boolean;
          created_at: string;
        };
        Insert: {
          id?: string;
          profile_id: string;
          provider: string;
          brand: string;
          last_four: string;
          provider_payment_method_id: string;
          is_default?: boolean;
          created_at?: string;
        };
        Update: {
          id?: string;
          profile_id?: string;
          provider?: string;
          brand?: string;
          last_four?: string;
          provider_payment_method_id?: string;
          is_default?: boolean;
          created_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "payment_methods_profile_id_fkey";
            columns: ["profile_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
        ];
      };
      pharmacy_categories: {
        Row: {
          id: string;
          name: string;
          is_active: boolean;
          created_at: string;
        };
        Insert: {
          id: string;
          name: string;
          is_active?: boolean;
          created_at?: string;
        };
        Update: {
          id?: string;
          name?: string;
          is_active?: boolean;
          created_at?: string;
        };
        Relationships: [];
      };
      pharmacy_order_items: {
        Row: {
          id: number;
          order_id: string;
          product_id: string | null;
          product_name: string;
          quantity: number;
          unit_price: number;
          created_at: string;
        };
        Insert: {
          id?: number;
          order_id: string;
          product_id?: string | null;
          product_name: string;
          quantity: number;
          unit_price: number;
          created_at?: string;
        };
        Update: {
          id?: number;
          order_id?: string;
          product_id?: string | null;
          product_name?: string;
          quantity?: number;
          unit_price?: number;
          created_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "pharmacy_order_items_order_id_fkey";
            columns: ["order_id"];
            isOneToOne: false;
            referencedRelation: "pharmacy_orders";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "pharmacy_order_items_product_id_fkey";
            columns: ["product_id"];
            isOneToOne: false;
            referencedRelation: "pharmacy_products";
            referencedColumns: ["id"];
          },
        ];
      };
      pharmacy_orders: {
        Row: {
          id: string;
          profile_id: string;
          recipient_name: string;
          phone: string;
          city: string;
          district: string;
          street: string;
          delivery_instructions: string;
          status: string;
          subtotal: number;
          delivery_fee: number;
          total: number;
          currency: string;
          country: string;
          is_demo: boolean;
          created_at: string;
          updated_at: string;
          payment_method: string;
          payment_status: string;
          idempotency_key: string | null;
          delivery_address_id: string | null;
        };
        Insert: {
          id?: string;
          profile_id: string;
          recipient_name?: string;
          phone?: string;
          city?: string;
          district?: string;
          street?: string;
          delivery_instructions?: string;
          status?: string;
          subtotal: number;
          delivery_fee?: number;
          total: number;
          currency?: string;
          country?: string;
          is_demo?: boolean;
          created_at?: string;
          updated_at?: string;
          payment_method?: string;
          payment_status?: string;
          idempotency_key?: string | null;
          delivery_address_id?: string | null;
        };
        Update: {
          id?: string;
          profile_id?: string;
          recipient_name?: string;
          phone?: string;
          city?: string;
          district?: string;
          street?: string;
          delivery_instructions?: string;
          status?: string;
          subtotal?: number;
          delivery_fee?: number;
          total?: number;
          currency?: string;
          country?: string;
          is_demo?: boolean;
          created_at?: string;
          updated_at?: string;
          payment_method?: string;
          payment_status?: string;
          idempotency_key?: string | null;
          delivery_address_id?: string | null;
        };
        Relationships: [
          {
            foreignKeyName: "pharmacy_orders_delivery_address_id_fkey";
            columns: ["delivery_address_id"];
            isOneToOne: false;
            referencedRelation: "delivery_addresses";
            referencedColumns: ["id"];
          },
        ];
      };
      pharmacy_products: {
        Row: {
          id: string;
          category_id: string;
          name: string;
          description: string;
          unit_price: number;
          stock_quantity: number;
          sale_type: string;
          is_active: boolean;
          created_at: string;
          updated_at: string;
          store_id: string;
          /** Added by 20260925000000_add_merchant_media_uploads.sql. */
          image_url: string | null;
        };
        Insert: {
          id: string;
          category_id: string;
          name: string;
          description?: string;
          unit_price: number;
          stock_quantity: number;
          sale_type?: string;
          is_active?: boolean;
          created_at?: string;
          updated_at?: string;
          store_id: string;
          image_url?: string | null;
        };
        Update: {
          id?: string;
          category_id?: string;
          name?: string;
          description?: string;
          unit_price?: number;
          stock_quantity?: number;
          sale_type?: string;
          is_active?: boolean;
          created_at?: string;
          updated_at?: string;
          store_id?: string;
          image_url?: string | null;
        };
        Relationships: [
          {
            foreignKeyName: "pharmacy_products_category_id_fkey";
            columns: ["category_id"];
            isOneToOne: false;
            referencedRelation: "pharmacy_categories";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "pharmacy_products_store_id_fkey";
            columns: ["store_id"];
            isOneToOne: false;
            referencedRelation: "pharmacy_stores";
            referencedColumns: ["id"];
          },
        ];
      };
      pharmacy_stores: {
        Row: {
          id: string;
          owner_id: string | null;
          name: string;
          address: string;
          is_active: boolean;
          created_at: string;
          updated_at: string;
          /** Added by 20260922020000_add_store_image_urls.sql (missing from schema.sql -- see file header). */
          image_url: string | null;
        };
        Insert: {
          id: string;
          owner_id?: string | null;
          name: string;
          address?: string;
          is_active?: boolean;
          created_at?: string;
          updated_at?: string;
          image_url?: string | null;
        };
        Update: {
          id?: string;
          owner_id?: string | null;
          name?: string;
          address?: string;
          is_active?: boolean;
          created_at?: string;
          updated_at?: string;
          image_url?: string | null;
        };
        Relationships: [
          {
            foreignKeyName: "pharmacy_stores_owner_id_fkey";
            columns: ["owner_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
        ];
      };
      profiles: {
        Row: {
          id: string;
          firstname: string;
          lastname: string;
          phone: string;
          avatar_url: string | null;
          role: string;
          deleted_at: string | null;
          /** Added by 20260923000000_add_profile_dob_and_signup_metadata.sql (missing from schema.sql -- see file header). */
          dob: string | null;
        };
        Insert: {
          id: string;
          firstname?: string;
          lastname?: string;
          phone?: string;
          avatar_url?: string | null;
          role?: string;
          deleted_at?: string | null;
          dob?: string | null;
        };
        Update: {
          id?: string;
          firstname?: string;
          lastname?: string;
          phone?: string;
          avatar_url?: string | null;
          role?: string;
          deleted_at?: string | null;
          dob?: string | null;
        };
        Relationships: [];
      };
      restaurant_locations: {
        Row: {
          id: string;
          restaurant_id: string;
          store_name: string;
          phonenumber: string | null;
          latitude: number | null;
          longitude: number | null;
          mapcode: string | null;
          mapcode_territory: string | null;
          is_active: boolean | null;
          created_at: string;
        };
        Insert: {
          id?: string;
          restaurant_id: string;
          store_name: string;
          phonenumber?: string | null;
          latitude?: number | null;
          longitude?: number | null;
          mapcode?: string | null;
          mapcode_territory?: string | null;
          is_active?: boolean | null;
          created_at?: string;
        };
        Update: {
          id?: string;
          restaurant_id?: string;
          store_name?: string;
          phonenumber?: string | null;
          latitude?: number | null;
          longitude?: number | null;
          mapcode?: string | null;
          mapcode_territory?: string | null;
          is_active?: boolean | null;
          created_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "restaurant_locations_restaurant_id_fkey";
            columns: ["restaurant_id"];
            isOneToOne: false;
            referencedRelation: "restaurants";
            referencedColumns: ["id"];
          },
        ];
      };
      restaurants: {
        Row: {
          id: string;
          name: string;
          description: string | null;
          logo_url: string | null;
          created_at: string;
          owner_id: string | null;
          is_open: boolean;
          address: string | null;
        };
        Insert: {
          id?: string;
          name: string;
          description?: string | null;
          logo_url?: string | null;
          created_at?: string;
          owner_id?: string | null;
          is_open?: boolean;
          address?: string | null;
        };
        Update: {
          id?: string;
          name?: string;
          description?: string | null;
          logo_url?: string | null;
          created_at?: string;
          owner_id?: string | null;
          is_open?: boolean;
          address?: string | null;
        };
        Relationships: [
          {
            foreignKeyName: "restaurants_owner_id_fkey";
            columns: ["owner_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
        ];
      };
      service_pricing: {
        Row: {
          service_id: string;
          delivery_fee_cents: number;
          tax_rate: number;
          updated_at: string;
        };
        Insert: {
          service_id: string;
          delivery_fee_cents: number;
          tax_rate?: number;
          updated_at?: string;
        };
        Update: {
          service_id?: string;
          delivery_fee_cents?: number;
          tax_rate?: number;
          updated_at?: string;
        };
        Relationships: [];
      };
      wallet_transactions: {
        Row: {
          id: string;
          profile_id: string;
          order_id: string | null;
          type: Database["public"]["Enums"]["wallet_transaction_type"];
          amount: number;
          description: string;
          created_at: string;
        };
        Insert: {
          id?: string;
          profile_id: string;
          order_id?: string | null;
          type: Database["public"]["Enums"]["wallet_transaction_type"];
          amount: number;
          description: string;
          created_at?: string;
        };
        Update: {
          id?: string;
          profile_id?: string;
          order_id?: string | null;
          type?: Database["public"]["Enums"]["wallet_transaction_type"];
          amount?: number;
          description?: string;
          created_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "wallet_transactions_profile_id_fkey";
            columns: ["profile_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
        ];
      };
    };
    Views: {
      // security_invoker = true: RLS of the querying role applies, same as
      // querying the underlying tables directly.
      customer_activity: {
        Row: {
          id: string;
          profile_id: string;
          service_id: string;
          title: string;
          subtitle: string;
          status: string;
          occurred_at: string;
          amount: number;
          details_route: string;
          payment_method: string;
          payment_status: string;
        };
        Relationships: [];
      };
      grocery_delivery_slots_available: {
        Row: {
          id: string;
          store_id: string;
          label: string;
          detail: string;
          sort_order: number;
        };
        Relationships: [
          {
            foreignKeyName: "grocery_delivery_slots_store_id_fkey";
            columns: ["store_id"];
            isOneToOne: false;
            referencedRelation: "grocery_stores";
            referencedColumns: ["id"];
          },
        ];
      };
    };
    Functions: {
      admin_list_profiles: {
        Args: {
          search_text?: string | null;
          page_limit?: number;
          page_offset?: number;
        };
        Returns: {
          id: string;
          firstname: string;
          lastname: string;
          email: string;
          role: string;
        }[];
      };
      admin_lookup_profile_by_email: {
        Args: { target_email: string };
        Returns: {
          id: string;
          firstname: string;
          lastname: string;
          role: string;
        }[];
      };
      admin_set_profile_role: {
        Args: { target_profile_id: string; new_role: string };
        Returns: void;
      };
      advance_food_order_status: {
        Args: { p_order_id: string; p_new_status: string };
        Returns: string;
      };
      advance_grocery_order_status: {
        Args: { p_order_id: string; p_new_status: string };
        Returns: string;
      };
      advance_pharmacy_order_status: {
        Args: { p_order_id: string; p_new_status: string };
        Returns: string;
      };
      can_read_order_status_event: {
        Args: { p_vertical: string; p_order_id: string };
        Returns: boolean;
      };
      cancel_food_order: {
        Args: { p_order_id: string };
        Returns: string;
      };
      cancel_grocery_order: {
        Args: { p_order_id: string };
        Returns: string;
      };
      cancel_pharmacy_order: {
        Args: { p_order_id: string };
        Returns: string;
      };
      delete_own_account: {
        Args: Record<PropertyKey, never>;
        Returns: void;
      };
      is_legal_order_status_transition: {
        Args: {
          p_vertical: string;
          p_previous_status: string;
          p_new_status: string;
        };
        Returns: boolean;
      };
      merchant_owns_order: {
        Args: { p_vertical: string; p_order_id: string };
        Returns: boolean;
      };
      place_food_order: {
        Args: {
          p_restaurant_id: string;
          p_recipient_name: string;
          p_phone: string;
          p_street: string;
          p_district: string;
          p_city: string;
          p_items: Json;
          p_idempotency_key?: string | null;
          p_delivery_address_id?: string | null;
        };
        Returns: {
          order_id: string;
          subtotal: number;
          delivery_fee: number;
          tax: number;
          total: number;
        }[];
      };
      place_grocery_order: {
        Args: {
          p_store_id: string;
          p_delivery_slot_id: string;
          p_recipient_name: string;
          p_phone: string;
          p_street: string;
          p_district: string;
          p_city: string;
          p_substitution_preference: string;
          p_items: Json;
          p_idempotency_key?: string | null;
          p_delivery_address_id?: string | null;
        };
        Returns: {
          order_id: string;
          subtotal: number;
          delivery_fee: number;
          tax: number;
          total: number;
        }[];
      };
      place_pharmacy_order: {
        Args: {
          p_recipient_name: string;
          p_phone: string;
          p_city: string;
          p_district: string;
          p_street: string;
          p_delivery_instructions: string;
          p_items: Json;
          p_idempotency_key?: string | null;
          p_delivery_address_id?: string | null;
        };
        Returns: {
          order_id: string;
          subtotal: number;
          delivery_fee: number;
          tax: number;
          total: number;
        }[];
      };
      update_own_profile: {
        Args: {
          p_firstname?: string | null;
          p_lastname?: string | null;
          p_phone?: string | null;
          p_dob?: string | null;
        };
        Returns: {
          id: string;
          firstname: string;
          lastname: string;
          phone: string;
          avatar_url: string | null;
          dob: string | null;
        }[];
      };
    };
    Enums: {
      wallet_transaction_type: "top_up" | "order_payment" | "refund" | "adjustment";
    };
    CompositeTypes: Record<string, never>;
  };
};

// ---------------------------------------------------------------------
// Convenience helpers, matching the shape the Supabase CLI itself emits
// alongside `Database` in recent versions.
// ---------------------------------------------------------------------

type DefaultSchema = Database[Extract<keyof Database, "public">];

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof Database },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof Database;
  }
    ? keyof (Database[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        Database[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends { schema: keyof Database }
  ? (Database[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      Database[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R;
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R;
      }
      ? R
      : never
    : never;

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof Database },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof Database;
  }
    ? keyof Database[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends { schema: keyof Database }
  ? Database[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I;
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I;
      }
      ? I
      : never
    : never;

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof Database },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof Database;
  }
    ? keyof Database[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends { schema: keyof Database }
  ? Database[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U;
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U;
      }
      ? U
      : never
    : never;

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof Database },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof Database;
  }
    ? keyof Database[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends { schema: keyof Database }
  ? Database[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never;
