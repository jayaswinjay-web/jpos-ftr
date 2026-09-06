/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        primary: {
          50: '#e8f0fe',
          100: '#d2e3fc',
          200: '#a8c7fa',
          300: '#7aabf5',
          400: '#4a8ef0',
          500: '#1a73e8',
          600: '#1557b0',
          700: '#0f3d7a',
          800: '#0a2647',
          900: '#041e49',
        },
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
        mono: ['JetBrains Mono', 'monospace'],
      },
    },
  },
  plugins: [],
};
