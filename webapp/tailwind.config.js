/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        // Riza brand — mirrors lib/src/theme/app_theme.dart
        brand: {
          DEFAULT: '#1FB6A6', // primary teal-green
          50: '#EAFBF8',
          100: '#CFF5EF',
          200: '#A2EAE0',
          300: '#6DD9CC',
          400: '#3FC4B5',
          500: '#1FB6A6',
          600: '#149286',
          700: '#13746B',
          800: '#145C56',
          900: '#144C48',
        },
        coral: '#FF7E6B',
        sun: '#FFC857',
        sky: '#4D9DE0',
        canvas: '#F7FAF9',
        ink: '#0F1F1D',
      },
      fontFamily: {
        sans: ['"Plus Jakarta Sans"', 'system-ui', 'sans-serif'],
      },
      borderRadius: {
        xl: '1rem',
        '2xl': '1.5rem',
        pill: '999px',
      },
      boxShadow: {
        soft: '0 8px 30px rgba(20, 92, 86, 0.08)',
        card: '0 2px 16px rgba(15, 31, 29, 0.06)',
      },
    },
  },
  plugins: [],
}
