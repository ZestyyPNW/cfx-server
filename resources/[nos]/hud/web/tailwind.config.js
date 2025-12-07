/** @type {import('tailwindcss').Config} */
export default {
  content: ["./src/**/*.{html,js,ts,jsx,tsx}"],
  theme: {
    extend: {
      fontFamily: {
        sans: ['"Supreme Variable", sans-serif'],
      },
      colors: {
        red: "#b6151a",
        blue: "#162e74",
      },
    },
  },
  plugins: [],
};
