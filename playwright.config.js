
import {defineConfig,devices} from '@playwright/test';
const base='http://127.0.0.1:4173'+(process.env.VITE_BASE_PATH||'/');
export default defineConfig({testDir:'tests/browser',fullyParallel:true,retries:process.env.CI?1:0,reporter:[['list'],['html',{open:'never'}]],use:{baseURL:base,trace:'retain-on-failure',screenshot:'only-on-failure'},projects:[{name:'desktop',use:{...devices['Desktop Chrome']}},{name:'mobile',use:{...devices['Pixel 7']}}],webServer:{command:'npm run preview -- --host 127.0.0.1 --port 4173',url:base,reuseExistingServer:!process.env.CI}});
