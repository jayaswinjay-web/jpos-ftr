const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

export default async function handler(req) {
  try {
    const { email, password, shop_name, owner_name, phone, address, gstin } = await req.json();

    if (!email || !password || !shop_name || !owner_name) {
      return new Response(JSON.stringify({ error: "Missing required fields" }), { status: 400 });
    }

    const createRes = await fetch(`${SUPABASE_URL}/auth/v1/admin/users`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        apiKey: SERVICE_KEY,
        Authorization: `Bearer ${SERVICE_KEY}`,
      },
      body: JSON.stringify({
        email,
        password,
        email_confirm: true,
        user_metadata: { role: "owner", owner_name, shop_name, phone: phone || "", address: address || "", gstin: gstin || "" },
      }),
    });

    const result = await createRes.json();

    if (!createRes.ok) {
      const msg = result.msg || result.message || "Failed to create user";
      const isDuplicate = msg.toLowerCase().includes("already");
      return new Response(JSON.stringify({ error: isDuplicate ? "A user with this email already exists" : msg }), {
        status: isDuplicate ? 409 : (createRes.status || 500),
      });
    }

    return new Response(JSON.stringify({ message: "Shop created", user: { id: result.id, email: result.email } }), {
      status: 201,
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message || "Failed" }), { status: 500, headers: { "Content-Type": "application/json" } });
  }
}
