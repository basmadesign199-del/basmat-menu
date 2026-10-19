-- SAFE SETUP for basma-menu-db: creates separate menu_* tables and does not drop/alter existing tables.
PRAGMA foreign_keys = ON;
CREATE TABLE IF NOT EXISTS menu_restaurants(id TEXT PRIMARY KEY,name TEXT NOT NULL,slug TEXT NOT NULL UNIQUE,logo_url TEXT,primary_color TEXT DEFAULT '#b91c1c',whatsapp_phone TEXT,phone TEXT,facebook_url TEXT,tiktok_url TEXT,maps_url TEXT,delivery_fee INTEGER NOT NULL DEFAULT 0,minimum_order INTEGER NOT NULL DEFAULT 0,created_at TEXT DEFAULT CURRENT_TIMESTAMP);
CREATE TABLE IF NOT EXISTS menu_users(id TEXT PRIMARY KEY,restaurant_id TEXT,username TEXT NOT NULL UNIQUE,password_hash TEXT NOT NULL,role TEXT NOT NULL CHECK(role IN ('owner','restaurant_admin')),active INTEGER NOT NULL DEFAULT 1,created_at TEXT DEFAULT CURRENT_TIMESTAMP,FOREIGN KEY(restaurant_id) REFERENCES menu_restaurants(id));
CREATE TABLE IF NOT EXISTS menu_sessions(token_hash TEXT PRIMARY KEY,user_id TEXT NOT NULL,expires_at INTEGER NOT NULL,FOREIGN KEY(user_id) REFERENCES menu_users(id) ON DELETE CASCADE);
CREATE TABLE IF NOT EXISTS menu_categories(id TEXT PRIMARY KEY,restaurant_id TEXT NOT NULL,name TEXT NOT NULL,sort_order INTEGER DEFAULT 0,active INTEGER DEFAULT 1,FOREIGN KEY(restaurant_id) REFERENCES menu_restaurants(id) ON DELETE CASCADE);
CREATE TABLE IF NOT EXISTS menu_products(id TEXT PRIMARY KEY,restaurant_id TEXT NOT NULL,category_id TEXT,name TEXT NOT NULL,description TEXT DEFAULT '',price INTEGER NOT NULL DEFAULT 0,image_url TEXT,active INTEGER NOT NULL DEFAULT 1,options_json TEXT NOT NULL DEFAULT '[]',sort_order INTEGER DEFAULT 0,created_at TEXT DEFAULT CURRENT_TIMESTAMP,FOREIGN KEY(restaurant_id) REFERENCES menu_restaurants(id) ON DELETE CASCADE);
CREATE TABLE IF NOT EXISTS menu_orders(id TEXT PRIMARY KEY,restaurant_id TEXT NOT NULL,customer_name TEXT NOT NULL,customer_phone TEXT NOT NULL,fulfillment TEXT NOT NULL CHECK(fulfillment IN ('delivery','takeaway')),address TEXT DEFAULT '',latitude REAL,longitude REAL,payment_method TEXT NOT NULL CHECK(payment_method IN ('cash','online')),payment_status TEXT NOT NULL DEFAULT 'unpaid',order_status TEXT NOT NULL DEFAULT 'new',items_json TEXT NOT NULL,subtotal INTEGER NOT NULL,delivery_fee INTEGER NOT NULL DEFAULT 0,total INTEGER NOT NULL,customer_notes TEXT DEFAULT '',created_at TEXT DEFAULT CURRENT_TIMESTAMP,FOREIGN KEY(restaurant_id) REFERENCES menu_restaurants(id));
CREATE INDEX IF NOT EXISTS idx_menu_products_restaurant ON menu_products(restaurant_id,active,sort_order);
CREATE INDEX IF NOT EXISTS idx_menu_orders_restaurant ON menu_orders(restaurant_id,created_at);
CREATE INDEX IF NOT EXISTS idx_menu_sessions_expiry ON menu_sessions(expires_at);
-- Import the existing restaurant row (if present) without deleting or modifying the original.
INSERT OR IGNORE INTO menu_restaurants(id,name,slug,logo_url,phone,whatsapp_phone,facebook_url,tiktok_url,maps_url)
SELECT CAST(id AS TEXT),name,'restaurant-'||CAST(id AS TEXT),logo_url,phone,whatsapp,facebook_url,tiktok_url,location_url FROM restaurants;
-- Import existing categories when their parent restaurant was imported.
INSERT OR IGNORE INTO menu_categories(id,restaurant_id,name,sort_order,active)
SELECT CAST(c.id AS TEXT),CAST(c.restaurant_id AS TEXT),c.name,COALESCE(c.sort_order,0),1 FROM categories c
JOIN menu_restaurants r ON r.id=CAST(c.restaurant_id AS TEXT);
-- Import existing products; source prices are treated as EGP and converted to integer cents.
INSERT OR IGNORE INTO menu_products(id,restaurant_id,category_id,name,description,price,image_url,active,sort_order)
SELECT CAST(p.id AS TEXT),CAST(p.restaurant_id AS TEXT),CASE WHEN p.category_id IS NULL THEN NULL ELSE CAST(p.category_id AS TEXT) END,p.name,COALESCE(p.description,''),CAST(ROUND(COALESCE(p.price,0)*100) AS INTEGER),p.image_url,CASE WHEN COALESCE(p.is_available,1)=1 THEN 1 ELSE 0 END,COALESCE(p.sort_order,0)
FROM products p JOIN menu_restaurants r ON r.id=CAST(p.restaurant_id AS TEXT);
