import React from 'react';
import { useLocation } from 'react-router-dom';

function Header() {
  const location = useLocation();
  const titles = {
    '/': 'Dashboard',
    '/shops': 'Shops',
    '/revenue': 'Revenue',
  };

  return (
    <header className="bg-white border-b border-gray-200 px-6 py-4">
      <h2 className="text-xl font-semibold text-gray-900">
        {titles[location.pathname] || 'JayTech Admin'}
      </h2>
    </header>
  );
}

export default Header;
