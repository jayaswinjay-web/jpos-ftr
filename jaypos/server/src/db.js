const { Pool } = require('pg');
const bcrypt = require('bcrypt');
require('dotenv').config();

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

async function initDb() {
  const client = await pool.connect();
  try {
    await client.query(`
      CREATE TABLE IF NOT EXISTS shops (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        shop_name VARCHAR(255) NOT NULL,
        owner_name VARCHAR(255) NOT NULL,
        owner_username VARCHAR(100) UNIQUE NOT NULL,
        owner_password VARCHAR(255) NOT NULL,
        phone VARCHAR(20),
        address TEXT,
        gstin VARCHAR(50),
        currency VARCHAR(10) DEFAULT '₹',
        is_active BOOLEAN DEFAULT true,
        created_at TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW()
      );

      CREATE TABLE IF NOT EXISTS subscription_plans (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        name VARCHAR(50) NOT NULL UNIQUE,
        max_devices INTEGER NOT NULL,
        max_bills INTEGER,
        max_whatsapp INTEGER,
        price_paise BIGINT NOT NULL,
        is_active BOOLEAN DEFAULT true,
        created_at TIMESTAMP DEFAULT NOW()
      );

      CREATE TABLE IF NOT EXISTS subscriptions (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        shop_id UUID REFERENCES shops(id) ON DELETE CASCADE,
        plan_id UUID REFERENCES subscription_plans(id),
        status VARCHAR(20) DEFAULT 'active',
        start_date TIMESTAMP NOT NULL DEFAULT NOW(),
        expiry_date TIMESTAMP NOT NULL,
        grace_period_end TIMESTAMP,
        auto_renew BOOLEAN DEFAULT true,
        razorpay_subscription_id VARCHAR(255),
        created_at TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW()
      );

      CREATE TABLE IF NOT EXISTS payments (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        shop_id UUID REFERENCES shops(id) ON DELETE CASCADE,
        subscription_id UUID REFERENCES subscriptions(id),
        amount_paise BIGINT NOT NULL,
        currency VARCHAR(10) DEFAULT 'INR',
        razorpay_payment_id VARCHAR(255),
        razorpay_order_id VARCHAR(255),
        status VARCHAR(20) DEFAULT 'completed',
        created_at TIMESTAMP DEFAULT NOW()
      );

      CREATE TABLE IF NOT EXISTS shop_stats (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        shop_id UUID UNIQUE REFERENCES shops(id) ON DELETE CASCADE,
        total_bills INTEGER DEFAULT 0,
        total_customers INTEGER DEFAULT 0,
        total_whatsapp_sent INTEGER DEFAULT 0,
        last_synced TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW()
      );

      -- Add UNIQUE on shop_id if table already exists without it (migration)
      DO $$ BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_constraint WHERE conname = 'shop_stats_shop_id_key'
        ) THEN
          ALTER TABLE shop_stats ADD UNIQUE (shop_id);
        END IF;
      END $$;

      -- Seed subscription plans
      INSERT INTO subscription_plans (name, max_devices, max_bills, max_whatsapp, price_paise)
      VALUES 
        ('Starter', 1, 500, 100, 49900),
        ('Growth', 5, NULL, 500, 99900),
        ('Pro', 10, NULL, NULL, 199900)
      ON CONFLICT (name) DO NOTHING;

      -- Seed super admin
      INSERT INTO shops (shop_name, owner_name, owner_username, owner_password)
      VALUES ('JayTech HQ', 'Super Admin', 'jaytech', 
              '${await bcrypt.hash('jaytech@123', 10)}')
      ON CONFLICT (owner_username) DO NOTHING;
    `);
    console.log('Database initialized successfully');
  } finally {
    client.release();
  }
}

async function query(text, params) {
  const client = await pool.connect();
  try {
    const result = await client.query(text, params);
    return result;
  } finally {
    client.release();
  }
}

module.exports = { pool, initDb, query };
