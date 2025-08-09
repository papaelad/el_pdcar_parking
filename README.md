# 🚓 מערכת ניהול רכבי משטרה – גרסה 3.0

מערכת מתקדמת לניהול רכבים ב־QBCore, כולל GPS, תחזוקה, ממשק ניהולי NUI, AI Dispatcher, סטטיסטיקות, קנסות, והרשאות לפי דרגה.

---

## 📦 התקנה

1. שים את התיקייה `pdcar` בתוך `resources`.
2. ודא שהקבצים קיימים:
   - `client.lua`
   - `server.lua`
   - `fxmanifest.lua`
   - `html/index.html`, `style.css`, `script.js`
   - `pdcar_vehicles.json`, `fine_logs.json`
3. הוסף ל־`server.cfg`:
   ```plaintext
   ensure pdcar
