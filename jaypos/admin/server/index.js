import express from 'express';
import { createClient } from '@supabase/supabase-js';
import cors from 'cors';

const app = express();
const PORT = process.env.PORT || 3001;

const supabaseUrl = 'https://iyrmmabzasmfovohbgti.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml5cm1tYWJ6YXNtZm92b2hiZ3RpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI0NTIwNTMsImV4cCI6MjA5ODAyODA1M30.oGJpG8I1VDfjGGZ4vKciN6geee_vyIvdMsiY7pQCjx4';
const supabaseServiceKey = process.env.SUPABASE_SERVICE_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml5cm1tYWJ6YXNtZm92b2hiZ3RpIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MjQ1MjA1MywiZXhwIjoyMDk4MDI4MDUzfQ.hnBXBvCqV-qIISNX5S5pd6-a_nt_jgSA7V7wfyrMuNU';
const supabase = createClient(supabaseUrl, supabaseAnonKey);
const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey);

app.use(cors());
app.use(express.json());

app.post('/admin-create-shop', async (req, res) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'Missing Authorization header' });
    }

    const jwt = authHeader.slice(7);
    const { data: { user }, error: userError } = await supabase.auth.getUser(jwt);
    if (userError || !user) {
      return res.status(401).json({ error: 'Invalid or expired token' });
    }

    if (user.user_metadata?.role !== 'super_admin') {
      return res.status(403).json({ error: 'Forbidden: super_admin only' });
    }

    const { email, password, shop_name, owner_name, phone, address, gstin } = req.body;
    if (!email || !password || !shop_name || !owner_name) {
      return res.status(400).json({ error: 'Missing required fields: email, password, shop_name, owner_name' });
    }

    const { data: newUser, error: createError } = await supabaseAdmin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { role: 'owner', owner_name, shop_name, phone: phone || '', address: address || '', gstin: gstin || '' },
    });

    if (createError) {
      const msg = createError.message?.includes('already') ? 'A user with this email already exists' : createError.message;
      return res.status(409).json({ error: msg });
    }

    return res.status(201).json({ message: 'Shop created successfully', user: { id: newUser.user.id, email: newUser.user.email } });
  } catch (err) {
    return res.status(500).json({ error: err.message || 'Failed to create shop' });
  }
});

app.listen(PORT, () => {
  console.log(`Admin API server running on http://localhost:${PORT}`);
});
