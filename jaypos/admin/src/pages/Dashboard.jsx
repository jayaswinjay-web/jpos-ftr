import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { Store, Receipt, DollarSign, MessageCircle } from 'lucide-react';

function Dashboard() {
  const [shops, setShops] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    fetchData();
  }, []);

  const fetchData = async () => {
    try {
      const { data: shopsData, error: shopsError } = await supabase
        .from('shops')
        .select('*, subscriptions!inner(plan_id, status, expiry_date, subscription_plans(name)), shop_stats(*)')
        .order('created_at', { ascending: false });

      if (shopsError) throw shopsError;
      setShops(shopsData || []);
    } catch (err) {
      setError('Failed to load dashboard data');
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600" />
      </div>
    );
  }

  const activeShops = shops.filter((s) => s.subscriptions?.status === 'active').length;
  const totalBills = shops.reduce((sum, s) => sum + (s.shop_stats?.total_bills || 0), 0);
  const totalWhatsApp = shops.reduce((sum, s) => sum + (s.shop_stats?.total_whatsapp_sent || 0), 0);
  const monthlyRevenue = 0; // payments query would go here

  return (
    <div className="space-y-6">
      {error && (
        <div className="bg-red-50 text-red-600 px-4 py-3 rounded-lg text-sm flex items-center justify-between">
          <span>{error}</span>
          <button onClick={fetchData} className="text-red-700 underline text-xs">Retry</button>
        </div>
      )}

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <div className="stat-card">
          <div className="flex items-center gap-3 mb-4">
            <div className="w-10 h-10 bg-blue-100 rounded-lg flex items-center justify-center">
              <Store className="w-5 h-5 text-blue-600" />
            </div>
          </div>
          <p className="text-sm text-gray-500">Active Shops</p>
          <p className="text-2xl font-bold">{activeShops}</p>
        </div>

        <div className="stat-card">
          <div className="flex items-center gap-3 mb-4">
            <div className="w-10 h-10 bg-green-100 rounded-lg flex items-center justify-center">
              <Receipt className="w-5 h-5 text-green-600" />
            </div>
          </div>
          <p className="text-sm text-gray-500">Total Bills</p>
          <p className="text-2xl font-bold">{totalBills.toLocaleString('en-IN')}</p>
        </div>

        <div className="stat-card">
          <div className="flex items-center gap-3 mb-4">
            <div className="w-10 h-10 bg-purple-100 rounded-lg flex items-center justify-center">
              <MessageCircle className="w-5 h-5 text-purple-600" />
            </div>
          </div>
          <p className="text-sm text-gray-500">WhatsApp Messages</p>
          <p className="text-2xl font-bold">{totalWhatsApp.toLocaleString('en-IN')}</p>
        </div>

        <div className="stat-card">
          <div className="flex items-center gap-3 mb-4">
            <div className="w-10 h-10 bg-amber-100 rounded-lg flex items-center justify-center">
              <DollarSign className="w-5 h-5 text-amber-600" />
            </div>
          </div>
          <p className="text-sm text-gray-500">Total Shops</p>
          <p className="text-2xl font-bold">{shops.length}</p>
        </div>
      </div>

      <div className="card">
        <h3 className="font-semibold text-lg mb-4">Recent Shops</h3>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-gray-100">
                <th className="text-left py-3 px-4 font-medium text-gray-500">Shop</th>
                <th className="text-left py-3 px-4 font-medium text-gray-500">Owner</th>
                <th className="text-left py-3 px-4 font-medium text-gray-500">Plan</th>
                <th className="text-left py-3 px-4 font-medium text-gray-500">Status</th>
                <th className="text-left py-3 px-4 font-medium text-gray-500">Bills</th>
                <th className="text-left py-3 px-4 font-medium text-gray-500">WhatsApp</th>
              </tr>
            </thead>
            <tbody>
              {shops.slice(0, 10).map((shop) => (
                <tr key={shop.id} className="border-b border-gray-50 hover:bg-gray-50">
                  <td className="py-3 px-4 font-medium">{shop.shop_name}</td>
                  <td className="py-3 px-4 text-gray-600">{shop.owner_name}</td>
                  <td className="py-3 px-4">
                    <span className="px-2 py-1 rounded-full text-xs font-medium bg-blue-50 text-blue-700">
                      {shop.subscriptions?.subscription_plans?.name || 'No Plan'}
                    </span>
                  </td>
                  <td className="py-3 px-4">
                    <span className={`px-2 py-1 rounded-full text-xs font-medium ${
                      shop.subscriptions?.status === 'active'
                        ? 'bg-green-50 text-green-700'
                        : 'bg-red-50 text-red-700'
                    }`}>
                      {shop.subscriptions?.status || 'inactive'}
                    </span>
                  </td>
                  <td className="py-3 px-4">{shop.shop_stats?.total_bills || 0}</td>
                  <td className="py-3 px-4">{shop.shop_stats?.total_whatsapp_sent || 0}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}

export default Dashboard;
