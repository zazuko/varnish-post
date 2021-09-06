// eslint-disable-next-line no-undef
module.exports = {
  root: true,
  parser: "@typescript-eslint/parser",
  plugins: ["@typescript-eslint"],
  extends: [
    "eslint:recommended",
    "plugin:@typescript-eslint/recommended",
    "airbnb-typescript/base",
  ],
  parserOptions: {
    project: "./tsconfig.json",
  },
  rules: {
    "no-console": "off"
  },
  ignorePatterns: ["dist", ".eslintrc.js"],
};
