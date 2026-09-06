const express = require('express');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const Joi = require('joi');
const { query } = require('../db');

const router = express.Router();

const loginSchema = Joi.object({
  username: Joi.string().required(),
  password: Joi.string().required(),
});

const registerSchema = Joi.object({
  shopName: Joi.string().min(2).max(255).required(),
  ownerName: Joi.string().min(2).max(255).required(),
  username: Joi.string().min(3).max(100).required(),
  password: Joi.string().min(6).required(),
  phone: Joi.string().max(20).optional().allow(''),
  address: Joi.string().max(500).optional().allow(''),
  gstin: Joi.string().max(50).optional().allow(''),
});

const refreshSchema = Joi.object({
  refreshToken: Joi.string().required(),
});

// POST /api/auth/register
router.post('/register', async (req, res, next) => {
  try {
    const { error, value } = registerSchema.validate(req.body);
    if (error) {
      return res.status(400).json({ error: error.details[0].message });
    }

    // Check if username already exists
    const existing = await query('SELECT id FROM shops WHERE owner_username = $1', [value.username]);
    if (existing.rows.length > 0) {
      return res.status(409).json({ error: 'Username already taken' });
    }

    const hashedPassword = await bcrypt.hash(value.password, 10);

    const result = await query(
      `INSERT INTO shops (shop_name, owner_name, owner_username, owner_password, phone, address, gstin)
       VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING id, shop_name, owner_name, owner_username, created_at`,
      [value.shopName, value.ownerName, value.username, hashedPassword, value.phone || null, value.address || null, value.gstin || null]
    );

    const shop = result.rows[0];

    // Create a free Starter subscription
    const planResult = await query("SELECT id FROM subscription_plans WHERE name = 'Starter' LIMIT 1");
    const starterPlan = planResult.rows[0];
    if (starterPlan) {
      const expiryDate = new Date();
      expiryDate.setMonth(expiryDate.getMonth() + 1);
      await query(
        `INSERT INTO subscriptions (shop_id, plan_id, status, start_date, expiry_date)
         VALUES ($1, $2, 'active', NOW(), $3)`,
        [shop.id, starterPlan.id, expiryDate]
      );
    }

    // Initialize shop stats
    await query(
      'INSERT INTO shop_stats (shop_id, total_bills, total_customers, total_whatsapp_sent) VALUES ($1, 0, 0, 0) ON CONFLICT (shop_id) DO NOTHING',
      [shop.id]
    );

    const accessToken = jwt.sign(
      { shopId: shop.id, username: shop.owner_username, role: 'owner' },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRY || '24h' }
    );

    const refreshToken = jwt.sign(
      { shopId: shop.id, type: 'refresh' },
      process.env.JWT_REFRESH_SECRET,
      { expiresIn: process.env.JWT_REFRESH_EXPIRY || '7d' }
    );

    res.status(201).json({
      accessToken,
      refreshToken,
      shop: { id: shop.id, name: shop.shop_name, ownerName: shop.owner_name, username: shop.owner_username },
      subscription: { plan: 'Starter', status: 'active', expiryDate: expiryDate },
      message: 'Shop registered successfully',
    });
  } catch (err) {
    next(err);
  }
});

// POST /api/auth/login
router.post('/login', async (req, res, next) => {
  try {
    const { error, value } = loginSchema.validate(req.body);
    if (error) {
      return res.status(400).json({ error: error.details[0].message });
    }

    const result = await query(
      'SELECT id, shop_name, owner_name, owner_username, owner_password, is_active FROM shops WHERE owner_username = $1',
      [value.username]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const shop = result.rows[0];

    if (!shop.is_active) {
      return res.status(403).json({ error: 'Account is deactivated' });
    }

    const validPassword = await bcrypt.compare(value.password, shop.owner_password);
    if (!validPassword) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    // Get active subscription
    const subResult = await query(
      `SELECT s.*, sp.name as plan_name, sp.max_devices, sp.max_bills, sp.max_whatsapp 
       FROM subscriptions s 
       JOIN subscription_plans sp ON s.plan_id = sp.id 
       WHERE s.shop_id = $1 AND s.status = 'active' 
       ORDER BY s.created_at DESC LIMIT 1`,
      [shop.id]
    );

    const subscription = subResult.rows[0] || null;

    const accessToken = jwt.sign(
      {
        shopId: shop.id,
        username: shop.owner_username,
        role: 'owner',
        subscription: subscription ? {
          plan: subscription.plan_name,
          expiry: subscription.expiry_date,
          maxDevices: subscription.max_devices,
          maxBills: subscription.max_bills,
          maxWhatsApp: subscription.max_whatsapp,
        } : null,
      },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRY || '24h' }
    );

    const refreshToken = jwt.sign(
      { shopId: shop.id, type: 'refresh' },
      process.env.JWT_REFRESH_SECRET,
      { expiresIn: process.env.JWT_REFRESH_EXPIRY || '7d' }
    );

    res.json({
      accessToken,
      refreshToken,
      shop: {
        id: shop.id,
        name: shop.shop_name,
        ownerName: shop.owner_name,
        username: shop.owner_username,
      },
      subscription,
    });
  } catch (err) {
    next(err);
  }
});

// POST /api/auth/refresh
router.post('/refresh', async (req, res, next) => {
  try {
    const { error, value } = refreshSchema.validate(req.body);
    if (error) {
      return res.status(400).json({ error: error.details[0].message });
    }

    const decoded = jwt.verify(value.refreshToken, process.env.JWT_REFRESH_SECRET);

    const result = await query('SELECT id, owner_username FROM shops WHERE id = $1', [decoded.shopId]);
    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Shop not found' });
    }

    const shop = result.rows[0];

    const accessToken = jwt.sign(
      { shopId: shop.id, username: shop.owner_username, role: 'owner' },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRY || '24h' }
    );

    res.json({ accessToken });
  } catch (err) {
    if (err.name === 'JsonWebTokenError' || err.name === 'TokenExpiredError') {
      return res.status(401).json({ error: 'Invalid refresh token' });
    }
    next(err);
  }
});

// POST /api/auth/logout
router.post('/logout', (req, res) => {
  res.json({ message: 'Logged out successfully' });
});

module.exports = router;
