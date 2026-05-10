// @ts-check
import { defineConfig } from "astro/config";

export default defineConfig({
    site: "https://sanctum.haus",
    trailingSlash: "always",
    build: {
        format: "directory",
    },
    devToolbar: {
        enabled: false,
    },
});
