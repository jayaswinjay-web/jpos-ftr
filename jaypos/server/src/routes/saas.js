const express = require('express');
const Joi = require('joi');
const { query } = require('../db');
const { authenticateToken } = require('../middleware/auth');

const router = express.Router();

// GET /api/saas/my-plan
router.get('/my-plan', authenticateToken, async (req, res, next) => {
  try {
    const result = await query(
      `SELECT s.*, sp.name as plan_name, sp.max_devices, sp.max_bills, sp.max_whatsapp, sp.price_paise
       FROM subscriptions s
       JOIN subscription_plans sp ON s.plan_id = sp.id
       WHERE s.shop_id = $1 AND s.status IN ('active', 'expired')
       ORDER BY s.created_at DESC LIMIT 1`,
      [req.user.shopId]
    );

    if (result.rows.length === 0) {
      return res.json({ plan: null, status: 'no_subscription' });
    }

    const sub = result.rows[0];
    const now = new Date();
    const expiry = new Date(sub.expiry_date);
    const graceEnd = sub.grace_period_end ? new Date(sub.grace_period_end) : null;

    let status = 'active';
    if (now > expiry) {
      if (graceEnd && now <= graceEnd) {
        status = 'grace_period';
      } else {
        status = 'expired';
      }
    }

    // Get usage stats
    const statsResult = await query(
      'SELECT total_bills, total_whatsapp_sent FROM shop_stats WHERE shop_id = $1',
      [req.user.shopId]
    );
    const stats = statsResult.rows[0] || { total_bills: 0, total_whatsapp_sent: 0 };

    res.json({
      plan: {
        name: sub.plan_name,
        maxDevices: sub.max_devices,
        maxBills: sub.max_bills,
        maxWhatsApp: sub.max_whatsapp,
        pricePaise: sub.price_paise,
      },
      status,
      expiryDate: sub.expiry_date,
      gracePeriodEnd: sub.grace_period_end,
      usage: {
        bills: stats.total_bills,
        whatsapp: stats.total_whatsapp_sent,
      },
    });
  } catch (err) {
    next(err);
  }
});

// POST /api/saas/subscribe
router.post('/subscribe', authenticateToken, async (req, res, next) => {
  try {
    const schema = Joi.object({
      planId: Joi.string().uuid().required(),
    });

    const { error, value } = schema.validate(req.body);
    if (error) {
      return res.status(400).json({ error: error.details[0].message });
    }

    // Get plan
    const planResult = await query(
      'SELECT * FROM subscription_plans WHERE id = $1 AND is_active = true',
      [value.planId]
    );

    if (planResult.rows.length === 0) {
      return res.status(404).json({ error: 'Plan not found' });
    }

    const plan = planResult.rows[0];

    // Create subscription
    const expiryDate = new Date();
    expiryDate.setMonth(expiryDate.getMonth() + 1);

    const result = await query(
      `INSERT INTO subscriptions (shop_id, plan_id, status, start_date, expiry_date)
       VALUES ($1, $2, 'active', NOW(), $3)
       RETURNING *`,
      [req.user.shopId, plan.id, expiryDate]
    );

    res.status(201).json({
      message: 'Subscription created',
      subscription: result.rows[0],
      paymentRequired: true,
      amountPaise: plan.price_paise,
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
