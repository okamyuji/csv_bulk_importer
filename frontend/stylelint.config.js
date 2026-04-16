/** @type {import('stylelint').Config} */
export default {
  extends: ["stylelint-config-standard"],
  rules: {
    "at-rule-no-unknown": [true, { ignoreAtRules: ["tailwind", "apply", "layer", "config", "theme", "import"] }],
    "no-descending-specificity": null,
  },
  ignoreFiles: ["dist/**", "node_modules/**"],
};
