/** @type {import('stylelint').Config} */
export default {
  extends: ["stylelint-config-standard"],
  rules: {
    "at-rule-no-unknown": [true, { ignoreAtRules: ["tailwind", "apply", "layer", "config", "theme", "import"] }],
    "no-descending-specificity": null,
    // Tailwind CSS v4 の `@import "tailwindcss";` は文字列形式が公式記法なので許可する
    "import-notation": "string",
  },
  ignoreFiles: ["dist/**", "node_modules/**"],
};
