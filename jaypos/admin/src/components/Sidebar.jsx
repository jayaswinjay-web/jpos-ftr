import React from 'react';
import { NavLink } from 'react-router-dom';
import { LayoutDashboard, Store, DollarSign, LogOut, Receipt } from 'lucide-react';

function Sidebar({ onLogout }) {
  const linkClass = ({ isActive }) =>
    `flex items-center gap-3 px-4 py-3 rounded-lg transition-colors ${
      isActive ? 'bg-blue-50 text-blue-700 font-medium' : 'text-gray-600 hover:bg-gray-100'
    }`;

  return (
    <aside className="w-64 bg-white border-r border-gray-200 flex flex-col">
      <div className="p-6 border-b border-gray-100">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 bg-blue-600 rounded-xl flex items-center justify-center">
            <Receipt className="w-5 h-5 text-white" />
          </div>
          <div>
            <h1 className="font-bold text-lg">JayTech</h1>
            <p className="text-xs text-gray-500">Super Admin</p>
          </div>
        </div>
      </div>

      <nav className="flex-1 p-4 space-y-1">
        <NavLink to="/" end className={linkClass}>
          <LayoutDashboard className="w-5 h-5" />
          Dashboard
        </NavLink>
        <NavLink to="/shops" className={linkClass}>
          <Store className="w-5 h-5" />
          Shops
        </NavLink>
        <NavLink to="/revenue" className={linkClass}>
          <DollarSign className="w-5 h-5" />
          Revenue
        </NavLink>
      </nav>

      <div className="p-4 border-t border-gray-100">
        <button
          onClick={onLogout}
          className="flex items-center gap-3 px-4 py-3 rounded-lg text-gray-600 hover:bg-red-50 hover:text-red-600 transition-colors w-full"
        >
          <LogOut className="w-5 h-5" />
          Sign Out
        </button>
      </div>
    </aside>
  );
}

export default Sidebar;
