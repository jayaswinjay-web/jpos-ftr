const express = require('express');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const Joi = require('joi');
const { query } = require('../db');
const { authenticateToken, requireRole } = require('../middleware/auth');

const router = express.Router();

const createShopSchema = Joi.object({
  shopName: Joi.string().min(2).max(255).required(),
  ownerName: Joi.string().min(2).max(255).required(),
  username: Joi.string().min(3).max(100).required(),
  password: Joi.string().min(6).required(),
  phone: Joi.string().max(20).optional().allow(''),
  address: Joi.string().max(500).optional().allow(''),
  gstin: Joi.string().max(50).optional().allow(''),
  planName: Joi.string().max(50).optional().default('Starter'),
});

// POST /api/superadmin/shop — create a new shop
router.post('/shop', authenticateToken, requireRole('super_admin'), async (req, res, next) => {
  try {
    const { error, value } = createShopSchema.validate(req.body);
    if (error) return res.status(400).json({ error: error.details[0].message });

    const existing = await query('SELECT id FROM shops WHERE owner_username = $1', [value.username]);
    if (existing.rows.length > 0) return res.status(409).json({ error: 'Username already taken' });

    const hashedPassword = await bcrypt.hash(value.password, 10);

    const shopResult = await query(
      `INSERT INTO shops (shop_name, owner_name, owner_username, owner_password, phone, address, gstin)
       VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING id, shop_name, owner_name, owner_username, phone, address, gstin, is_active, created_at`,
      [value.shopName, value.ownerName, value.username, hashedPassword, value.phone || null, value.address || null, value.gstin || null]
    );
    const shop = shopResult.rows[0];

    // Assign subscription plan
    const planResult = await query('SELECT id, name FROM subscription_plans WHERE name = $1 LIMIT 1', [value.planName]);
    const plan = planResult.rows[0];
    if (plan) {
      const expiryDate = new Date();
      expiryDate.setMonth(expiryDate.getMonth() + 1);
      await query(
        `INSERT INTO subscriptions (shop_id, plan_id, status, start_date, expiry_date)
         VALUES ($1, $2, 'active', NOW(), $3)`,
        [shop.id, plan.id, expiryDate]
      );
    }

    // Initialize shop stats
    await query(
      'INSERT INTO shop_stats (shop_id) VALUES ($1) ON CONFLICT (shop_id) DO NOTHING',
      [shop.id]
    );

    res.status(201).json({ shop, message: 'Shop created successfully' });
  } catch (err) {
    next(err);
  }
});

// Super admin login (separate endpoint)
router.post('/login', async (req, res, next) => {
  try {
    const { username, password } = req.body;

    if (username !== process.env.SUPER_ADMIN_USERNAME) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    if (password !== process.env.SUPER_ADMIN_PASSWORD) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const token = jwt.sign(
      { role: 'super_admin', username },
      process.env.JWT_SECRET,
      { expiresIn: '2h' }
    );

    res.json({ accessToken: token });
  } catch (err) {
    next(err);
  }
});

// GET /api/superadmin/shops
router.get('/shops', authenticateToken, requireRole('super_admin'), async (req, res, next) => {
  try {
    const result = await query(`
      SELECT 
        s.id, s.shop_name, s.owner_name, s.phone, s.is_active, s.created_at,
        sub.status as subscription_status, sub.expiry_date,
        sp.name as plan_name,
        st.total_bills, st.total_customers, st.total_whatsapp_sent
      FROM shops s
      LEFT JOIN LATERAL (
        SELECT * FROM subscriptions 
        WHERE shop_id = s.id 
        ORDER BY created_at DESC LIMIT 1
      ) sub ON true
      LEFT JOIN subscription_plans sp ON sub.plan_id = sp.id
      LEFT JOIN shop_stats st ON st.shop_id = s.id
      WHERE s.owner_username != 'jaytech'
      ORDER BY s.created_at DESC
    `);

    res.json({ shops: result.rows });
  } catch (err) {
    next(err);
  }
});

// GET /api/superadmin/shop/:id/stats
router.get('/shop/:id/stats', authenticateToken, requireRole('super_admin'), async (req, res, next) => {
  try {
    const result = await query(
      'SELECT * FROM shop_stats WHERE shop_id = $1',
      [req.params.id]
    );

    const shopResult = await query(
      'SELECT id, shop_name, owner_name FROM shops WHERE id = $1',
      [req.params.id]
    );

    res.json({
      shop: shopResult.rows[0] || null,
      stats: result.rows[0] || { total_bills: 0, total_customers: 0, total_whatsapp_sent: 0 },
    });
  } catch (err) {
    next(err);
  }
});

// POST /api/superadmin/shop/:id/toggle-active
router.post('/shop/:id/toggle-active', authenticateToken, requireRole('super_admin'), async (req, res, next) => {
  try {
    const { isActive } = req.body;
    const result = await query(
      'UPDATE shops SET is_active = $1, updated_at = NOW() WHERE id = $2 RETURNING id, shop_name, is_active',
      [isActive, req.params.id]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Shop not found' });
    }
    res.json({ shop: result.rows[0] });
  } catch (err) {
    next(err);
  }
});

// DELETE /api/superadmin/shop/:id — permanently delete a shop and all related data
router.delete('/shop/:id', authenticateToken, requireRole('super_admin'), async (req, res, next) => {
  try {
    const result = await query(
      'DELETE FROM shops WHERE id = $1 AND owner_username != $2 RETURNING id, shop_name',
      [req.params.id, 'jaytech']
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'Shop not found or cannot delete super admin' });
    res.json({ message: 'Shop deleted successfully', shop: result.rows[0] });
  } catch (err) { next(err); }
});

// PUT /api/superadmin/shop/:id — edit shop details
router.put('/shop/:id', authenticateToken, requireRole('super_admin'), async (req, res, next) => {
  try {
    const { shopName, ownerName, phone, address, gstin } = req.body;
    const result = await query(
      `UPDATE shops SET shop_name = COALESCE($1, shop_name), owner_name = COALESCE($2, owner_name),
       phone = COALESCE($3, phone), address = COALESCE($4, address), gstin = COALESCE($5, gstin),
       updated_at = NOW() WHERE id = $6 AND owner_username != 'jaytech'
       RETURNING id, shop_name, owner_name, phone, address, gstin, is_active, created_at`,
      [shopName || null, ownerName || null, phone ?? null, address ?? null, gstin ?? null, req.params.id]
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'Shop not found' });
    res.json({ shop: result.rows[0] });
  } catch (err) { next(err); }
});

// POST /api/superadmin/shop/:id/reset-password
router.post('/shop/:id/reset-password', authenticateToken, requireRole('super_admin'), async (req, res, next) => {
  try {
    const { password } = req.body;
    if (!password || password.length < 6) return res.status(400).json({ error: 'Password must be at least 6 characters' });
    const hashed = await bcrypt.hash(password, 10);
    const result = await query(
      "UPDATE shops SET owner_password = $1, updated_at = NOW() WHERE id = $2 AND owner_username != 'jaytech' RETURNING id, shop_name",
      [hashed, req.params.id]
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'Shop not found' });
    res.json({ message: 'Password reset successfully', shop: result.rows[0] });
  } catch (err) { next(err); }
});

// GET /api/superadmin/revenue
router.get('/revenue', authenticateToken, requireRole('super_admin'), async (req, res, next) => {
  try {
    const result = await query(`
      SELECT 
        DATE_TRUNC('month', created_at) as month,
        COUNT(*) as transaction_count,
        SUM(amount_paise) as revenue_paise
      FROM payments
      WHERE status = 'completed'
      GROUP BY month
      ORDER BY month DESC
      LIMIT 12
    `);

    const totalResult = await query(
      "SELECT COUNT(DISTINCT shop_id) as active_shops FROM subscriptions WHERE status = 'active'"
    );

    const churnResult = await query(`
      SELECT COUNT(*) as churned
      FROM subscriptions
      WHERE status = 'expired' 
        AND expiry_date >= NOW() - INTERVAL '30 days'
    `);

    res.json({
      monthly: result.rows,
      total: {
        activeShops: parseInt(totalResult.rows[0]?.active_shops || 0),
        churnedLast30Days: parseInt(churnResult.rows[0]?.churned || 0),
      },
    });
  } catch (err) {
    next(err);
  }
});

// GET /api/superadmin/whatsapp-usage
router.get('/whatsapp-usage', authenticateToken, requireRole('super_admin'), async (req, res, next) => {
  try {
    const result = await query(`
      SELECT s.shop_name, COALESCE(st.total_whatsapp_sent, 0) as messages_sent
      FROM shops s
      LEFT JOIN shop_stats st ON st.shop_id = s.id
      WHERE s.owner_username != 'jaytech'
      ORDER BY messages_sent DESC
    `);

    const total = result.rows.reduce((sum, row) => sum + parseInt(row.messages_sent), 0);

    res.json({
      total: total,
      shops: result.rows,
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
