import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { DollarSign, Users, TrendingDown } from 'lucide-react';
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts';

function Revenue() {
  const [shops, setShops] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    fetchData();
  }, []);

  const fetchData = async () => {
    setError('');
    try {
      const { data, error: err } = await supabase
        .from('shops')
        .select('*, subscriptions(status), shop_stats(*)');
      if (err) throw err;
      setShops(data || []);
    } catch (err) {
      setError('Failed to load revenue data');
    } finally {
      setLoading(false);
    }
  };

  const activeShops = shops.filter((s) => s.subscriptions?.status === 'active').length;
  const churned = shops.filter((s) => s.subscriptions?.status === 'expired').length;
  const totalRevenue = 0; // payments would provide this via a separate query

  const chartData = [
    { month: 'Jan', revenue: 0 },
    { month: 'Feb', revenue: 0 },
    { month: 'Mar', revenue: 0 },
  ];

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600" />
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {error && (
        <div className="bg-red-50 text-red-600 px-4 py-3 rounded-lg text-sm flex items-center justify-between">
          <span>{error}</span>
          <button onClick={fetchData} className="text-red-700 underline text-xs">Retry</button>
        </div>
      )}

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div className="stat-card">
          <div className="flex items-center gap-3 mb-4">
            <div className="w-10 h-10 bg-green-100 rounded-lg flex items-center justify-center">
              <DollarSign className="w-5 h-5 text-green-600" />
            </div>
          </div>
          <p className="text-sm text-gray-500">Total Revenue</p>
          <p className="text-2xl font-bold">₹{totalRevenue.toLocaleString('en-IN')}</p>
        </div>

        <div className="stat-card">
          <div className="flex items-center gap-3 mb-4">
            <div className="w-10 h-10 bg-blue-100 rounded-lg flex items-center justify-center">
              <Users className="w-5 h-5 text-blue-600" />
            </div>
          </div>
          <p className="text-sm text-gray-500">Active Subscriptions</p>
          <p className="text-2xl font-bold">{activeShops}</p>
        </div>

        <div className="stat-card">
          <div className="flex items-center gap-3 mb-4">
            <div className="w-10 h-10 bg-red-100 rounded-lg flex items-center justify-center">
              <TrendingDown className="w-5 h-5 text-red-600" />
            </div>
          </div>
          <p className="text-sm text-gray-500">Churned</p>
          <p className="text-2xl font-bold">{churned}</p>
        </div>
      </div>

      <div className="card">
        <h3 className="font-semibold text-lg mb-6">Monthly Revenue</h3>
        <div className="h-80">
          <ResponsiveContainer width="100%" height="100%">
            <BarChart data={chartData}>
              <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
              <XAxis dataKey="month" stroke="#9ca3af" fontSize={12} />
              <YAxis stroke="#9ca3af" fontSize={12} tickFormatter={(v) => `₹${(v / 1000).toFixed(0)}k`} />
              <Tooltip
                formatter={(value) => [`₹${value.toLocaleString('en-IN')}`, 'Revenue']}
                contentStyle={{ borderRadius: 8, border: '1px solid #e5e7eb' }}
              />
              <Bar dataKey="revenue" fill="#1a73e8" radius={[4, 4, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>
      </div>
    </div>
  );
}

export default Revenue;
