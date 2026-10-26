import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { resolve } from 'node:path';

export default defineConfig({
  plugins: [react()],
  base: './',
  build: {
    outDir: 'dist',
    emptyOutDir: true,
    cssCodeSplit: false,
    modulePreload: { polyfill: false },
    lib: {
      entry: resolve(__dirname, 'src/main.jsx'),
      name: 'ReflectiveCardPreview',
      formats: ['iife'],
      fileName: () => 'index.js',
      cssFileName: 'index'
    },
    rollupOptions: { output: { inlineDynamicImports: true } }
  }
});
