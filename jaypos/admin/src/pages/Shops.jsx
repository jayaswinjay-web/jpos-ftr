import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { Search, MoreVertical, CheckCircle, XCircle, Plus, X, Edit3 } from 'lucide-react';

const API_URL = 'http://localhost:3001/admin-create-shop';

function Shops() {
  const [shops, setShops] = useState([]);
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [actionShop, setActionShop] = useState(null);

  const [showAdd, setShowAdd] = useState(false);
  const [adding, setAdding] = useState(false);
  const [addForm, setAddForm] = useState({ email: '', password: '', shopName: '', ownerName: '', phone: '', address: '', gstin: '' });

  const [editTarget, setEditTarget] = useState(null);
  const [saving, setSaving] = useState(false);
  const [editForm, setEditForm] = useState({});

  useEffect(() => { fetchShops(); }, []);

  const fetchShops = async () => {
    setError('');
    try {
      const { data, error: err } = await supabase
        .from('shops')
        .select('*, subscriptions(plan_id, status, expiry_date, subscription_plans(name)), shop_stats(*)')
        .order('created_at', { ascending: false });
      if (err) throw err;
      setShops(data || []);
    } catch (err) {
      setError('Failed to load shops');
    } finally {
      setLoading(false);
    }
  };

  const toggleActive = async (shopId, currentStatus) => {
    try {
      const { error: err } = await supabase
        .from('shops')
        .update({ is_active: !currentStatus })
        .eq('id', shopId);
      if (err) throw err;
      setShops(shops.map((s) => (s.id === shopId ? { ...s, is_active: !currentStatus } : s)));
    } catch (err) {
      setError('Failed to update shop status');
    }
    setActionShop(null);
  };

  const handleAdd = async (e) => {
    e.preventDefault();
    setAdding(true);
    setError('');

    try {
      const session = await supabase.auth.getSession();
      const token = session?.data?.session?.access_token;

      const res = await fetch(API_URL, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
        },
        body: JSON.stringify({
          email: addForm.email,
          password: addForm.password,
          shop_name: addForm.shopName,
          owner_name: addForm.ownerName,
          phone: addForm.phone,
          address: addForm.address,
          gstin: addForm.gstin,
        }),
      });

      const data = await res.json();
      if (!res.ok) throw new Error(data.error || 'Failed to create shop');

      setShowAdd(false);
      setAddForm({ email: '', password: '', shopName: '', ownerName: '', phone: '', address: '', gstin: '' });
      fetchShops();
    } catch (err) {
      setError(err.message);
    } finally {
      setAdding(false);
    }
  };

  const openEdit = (shop) => {
    setEditTarget(shop.id);
    setEditForm({
      shopName: shop.shop_name || '',
      ownerName: shop.owner_name || '',
      phone: shop.phone || '',
      address: shop.address || '',
      gstin: shop.gstin || '',
    });
    setActionShop(null);
  };

  const handleEdit = async (e) => {
    e.preventDefault();
    setSaving(true);
    setError('');
    try {
      const { error: err } = await supabase
        .from('shops')
        .update({
          shop_name: editForm.shopName,
          owner_name: editForm.ownerName,
          phone: editForm.phone,
          address: editForm.address,
          gstin: editForm.gstin,
          updated_at: new Date().toISOString(),
        })
        .eq('id', editTarget);
      if (err) throw err;
      setShops(shops.map((s) => (s.id === editTarget ? {
        ...s, shop_name: editForm.shopName, owner_name: editForm.ownerName,
        phone: editForm.phone, address: editForm.address, gstin: editForm.gstin,
      } : s)));
      setEditTarget(null);
    } catch (err) {
      setError(err.message || 'Failed to update shop');
    } finally {
      setSaving(false);
    }
  };

  const deleteShop = async (shopId) => {
    if (!window.confirm('Permanently delete this shop and all data? This cannot be undone.')) return;
    try {
      const { error: err } = await supabase.from('shops').delete().eq('id', shopId);
      if (err) throw err;
      setShops(shops.filter((s) => s.id !== shopId));
    } catch (err) {
      setError(err.message || 'Failed to delete shop');
    }
    setActionShop(null);
  };

  const filtered = shops.filter(
    (s) => s.shop_name?.toLowerCase().includes(search.toLowerCase()) || s.owner_name?.toLowerCase().includes(search.toLowerCase())
  );

  if (loading) {
    return <div className="flex items-center justify-center h-64"><div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600" /></div>;
  }

  return (
    <div className="space-y-6">
      {error && (
        <div className="bg-red-50 text-red-600 px-4 py-3 rounded-lg text-sm flex items-center justify-between">
          <span>{error}</span>
          <button onClick={fetchShops} className="text-red-700 underline text-xs">Retry</button>
        </div>
      )}

      <div className="flex items-center gap-4">
        <div className="relative flex-1 max-w-md">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
          <input type="text" placeholder="Search shops..." value={search} onChange={(e) => setSearch(e.target.value)} className="input-field pl-10" />
        </div>
        <span className="text-sm text-gray-500">{filtered.length} shops</span>
        <button onClick={() => setShowAdd(true)} className="btn-primary flex items-center gap-2 text-sm">
          <Plus className="w-4 h-4" /> Add Shop
        </button>
      </div>

      {showAdd && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40" onClick={() => setShowAdd(false)}>
          <div className="bg-white rounded-2xl shadow-xl w-full max-w-lg mx-4 p-6 max-h-[90vh] overflow-y-auto" onClick={(e) => e.stopPropagation()}>
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-lg font-semibold">Add Shop</h2>
              <button onClick={() => setShowAdd(false)} className="p-1 hover:bg-gray-100 rounded"><X className="w-5 h-5" /></button>
            </div>
            <form onSubmit={handleAdd} className="space-y-3">
              <input placeholder="Email *" type="email" className="input-field" value={addForm.email} onChange={(e) => setAddForm({ ...addForm, email: e.target.value })} required />
              <input placeholder="Password *" type="password" className="input-field" value={addForm.password} onChange={(e) => setAddForm({ ...addForm, password: e.target.value })} required />
              <input placeholder="Shop Name *" className="input-field" value={addForm.shopName} onChange={(e) => setAddForm({ ...addForm, shopName: e.target.value })} required />
              <input placeholder="Owner Name *" className="input-field" value={addForm.ownerName} onChange={(e) => setAddForm({ ...addForm, ownerName: e.target.value })} required />
              <input placeholder="Phone" className="input-field" value={addForm.phone} onChange={(e) => setAddForm({ ...addForm, phone: e.target.value })} />
              <input placeholder="Address" className="input-field" value={addForm.address} onChange={(e) => setAddForm({ ...addForm, address: e.target.value })} />
              <input placeholder="GSTIN" className="input-field" value={addForm.gstin} onChange={(e) => setAddForm({ ...addForm, gstin: e.target.value })} />
              <div className="flex gap-3 pt-2">
                <button type="button" onClick={() => setShowAdd(false)} className="btn-secondary flex-1">Cancel</button>
                <button type="submit" disabled={adding} className="btn-primary flex-1">{adding ? 'Creating...' : 'Create Shop'}</button>
              </div>
            </form>
          </div>
        </div>
      )}

      {editTarget && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40" onClick={() => setEditTarget(null)}>
          <div className="bg-white rounded-2xl shadow-xl w-full max-w-lg mx-4 p-6" onClick={(e) => e.stopPropagation()}>
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-lg font-semibold">Edit Shop</h2>
              <button onClick={() => setEditTarget(null)} className="p-1 hover:bg-gray-100 rounded"><X className="w-5 h-5" /></button>
            </div>
            <form onSubmit={handleEdit} className="space-y-3">
              <input placeholder="Shop Name" className="input-field" value={editForm.shopName} onChange={(e) => setEditForm({ ...editForm, shopName: e.target.value })} />
              <input placeholder="Owner Name" className="input-field" value={editForm.ownerName} onChange={(e) => setEditForm({ ...editForm, ownerName: e.target.value })} />
              <input placeholder="Phone" className="input-field" value={editForm.phone} onChange={(e) => setEditForm({ ...editForm, phone: e.target.value })} />
              <input placeholder="Address" className="input-field" value={editForm.address} onChange={(e) => setEditForm({ ...editForm, address: e.target.value })} />
              <input placeholder="GSTIN" className="input-field" value={editForm.gstin} onChange={(e) => setEditForm({ ...editForm, gstin: e.target.value })} />
              <div className="flex gap-3 pt-2">
                <button type="button" onClick={() => setEditTarget(null)} className="btn-secondary flex-1">Cancel</button>
                <button type="submit" disabled={saving} className="btn-primary flex-1">{saving ? 'Saving...' : 'Save'}</button>
              </div>
            </form>
          </div>
        </div>
      )}

      <div className="card p-0">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-gray-100">
                <th className="text-left py-4 px-6 font-medium text-gray-500">Shop</th>
                <th className="text-left py-4 px-6 font-medium text-gray-500">Owner</th>
                <th className="text-left py-4 px-6 font-medium text-gray-500">Plan</th>
                <th className="text-left py-4 px-6 font-medium text-gray-500">Status</th>
                <th className="text-left py-4 px-6 font-medium text-gray-500">Expiry</th>
                <th className="text-left py-4 px-6 font-medium text-gray-500">Bills</th>
                <th className="text-left py-4 px-6 font-medium text-gray-500">WhatsApp</th>
                <th className="w-10"></th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((shop) => (
                <tr key={shop.id} className="border-b border-gray-50 hover:bg-gray-50">
                  <td className="py-4 px-6 font-medium">{shop.shop_name}</td>
                  <td className="py-4 px-6 text-gray-600">{shop.owner_name}</td>
                  <td className="py-4 px-6">
                    <span className="px-2 py-1 rounded-full text-xs font-medium bg-blue-50 text-blue-700">
                      {shop.subscriptions?.subscription_plans?.name || 'No Plan'}
                    </span>
                  </td>
                  <td className="py-4 px-6">
                    <span className={`px-2 py-1 rounded-full text-xs font-medium ${
                      shop.subscriptions?.status === 'active'
                        ? 'bg-green-50 text-green-700'
                        : shop.subscriptions?.status === 'expired'
                        ? 'bg-red-50 text-red-700'
                        : 'bg-gray-50 text-gray-700'
                    }`}>
                      {shop.subscriptions?.status || 'inactive'}
                    </span>
                  </td>
                  <td className="py-4 px-6 text-gray-600">
                    {shop.subscriptions?.expiry_date
                      ? new Date(shop.subscriptions.expiry_date).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' })
                      : '-'}
                  </td>
                  <td className="py-4 px-6">{shop.shop_stats?.total_bills || 0}</td>
                  <td className="py-4 px-6">{shop.shop_stats?.total_whatsapp_sent || 0}</td>
                  <td className="py-4 px-6 relative">
                    <button onClick={() => setActionShop(actionShop === shop.id ? null : shop.id)} className="p-1 hover:bg-gray-100 rounded">
                      <MoreVertical className="w-4 h-4 text-gray-400" />
                    </button>
                    {actionShop === shop.id && (
                      <div className="absolute right-0 top-full mt-1 bg-white rounded-lg shadow-lg border border-gray-100 py-1 z-10 min-w-[180px]">
                        <button onClick={() => toggleActive(shop.id, shop.is_active)} className="flex items-center gap-2 px-4 py-2 text-sm text-gray-700 hover:bg-gray-50 w-full text-left">
                          {shop.is_active ? <XCircle className="w-4 h-4 text-red-500" /> : <CheckCircle className="w-4 h-4 text-green-500" />}
                          {shop.is_active ? 'Deactivate' : 'Activate'}
                        </button>
                        <button onClick={() => openEdit(shop)} className="flex items-center gap-2 px-4 py-2 text-sm text-gray-700 hover:bg-gray-50 w-full text-left">
                          <Edit3 className="w-4 h-4 text-blue-500" /> Edit
                        </button>
                        <button onClick={() => deleteShop(shop.id)} className="flex items-center gap-2 px-4 py-2 text-sm text-red-600 hover:bg-red-50 w-full text-left">
                          <XCircle className="w-4 h-4" /> Delete
                        </button>
                      </div>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}

export default Shops;
