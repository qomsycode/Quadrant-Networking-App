# Deploy to GitHub Pages - Quick Setup

## Step 1: Build Web Release
```bash
cd c:\Users\HP\Desktop\networking_app
flutter build web --release --base-href "/Quadrant-Networking-App/"
```

> **IMPORTANT:** The `--base-href "/Quadrant-Networking-App/"` flag is CRITICAL. It tells the app that it is running in a subdirectory. If you miss this, your app will be **BLANK** when deployed.

This creates optimized files in `build/web/` directory.

## Step 2: GitHub Repository Setup

### If first time deploying:
1. Go to your GitHub repository
2. Settings → Pages
3. Select "Deploy from a branch"
4. Choose branch: `main` (or your branch)
5. Choose folder: `/docs` or `/` (root)

### If already set up:
Just follow Step 3.

## Step 3: Copy Build Files to Repository

### Option A: Direct Copy (Simplest)
```bash
# Copy build files to repository root
xcopy build\web\* . /E /Y

# Or if you use /docs folder:
# Create docs folder if it doesn't exist
mkdir docs
xcopy build\web\* docs /E /Y

# Create .nojekyll file (prevents Jekyll processing)
type nul > .nojekyll
```

### Option B: Use GitHub Actions (Automatic)
Create `.github/workflows/deploy.yml`:
```yaml
name: Deploy Web

on:
  push:
    branches: [ main ]

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: 'latest'
      
      - name: Build web
        run: flutter build web --release
      
      - name: Deploy to GitHub Pages
        uses: peaceiris/actions-gh-pages@v3
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./build/web
```

## Step 4: Commit and Push
```bash
git add .
git commit -m "Deploy web app to GitHub Pages"
git push origin main
```

## Step 5: Wait for Deployment
- Go to repository Settings → Pages
- Wait 1-2 minutes for deployment to complete
- Your app is live at: `https://YOUR_USERNAME.github.io/REPO_NAME`

## Verify Deployment
1. Go to your GitHub Pages URL
2. Measure loading time:
   - Splash screen appears: ~0.5-1 second
   - App ready: ~2-3 seconds
3. Test features:
   - Login/Signup works
   - Posts display correctly
   - Images upload to Firebase

## GitHub Pages URL Format
```
https://YOUR_GITHUB_USERNAME.github.io/Quadrant-Networking-App
```

For example:
```
https://john-doe.github.io/Quadrant-Networking-App
```

## Performance Tips After Deployment

### Check Loading Performance
1. Open DevTools (F12)
2. Go to Network tab
3. Hard refresh (Ctrl+Shift+R)
4. Check total load time

### If still slow (>5 seconds):
1. Check Firebase initialization:
   - Console (F12) for errors
   - Firebase Console for issues
2. Clear browser cache (Ctrl+Shift+Delete)
3. Test from another network (mobile hotspot)
4. Check GitHub Pages status: https://www.githubstatus.com

### Monitor Performance
Add to browser console:
```javascript
// Check app startup time
window.addEventListener('load', function() {
  console.log('Page fully loaded in', performance.timing.loadEventEnd - performance.timing.navigationStart, 'ms');
});
```

## Troubleshooting

### App loads but shows blank screen
- Check browser console (F12) for errors
- Verify Firebase configuration in `lib/firebase_options.dart`
- Check CORS settings in Firebase

### Assets not loading (white screen)
- Verify `build/web/` files are deployed
- Check GitHub Pages deployment log
- Clear browser cache

### Firebase not connecting
- Verify internet connection
- Check Firebase project settings
- Ensure Firebase Hosting rules allow web requests

### 404 errors on routes
- GitHub Pages doesn't support single-page app routing by default
- Create `build/web/404.html` with same content as `index.html`
- Or configure redirects

## File Structure After Deployment

```
your-repo/
├── build/
│   └── web/              (generated, don't commit)
├── docs/                 (if using /docs folder)
│   ├── index.html
│   ├── main.dart.js
│   ├── flutter.js
│   └── assets/
├── lib/
├── .nojekyll             (empty file)
├── .gitignore
├── pubspec.yaml
└── README.md
```

## Update App on GitHub Pages

After making changes:
```bash
# Build new release
flutter build web --release

# Copy to docs/ or root
xcopy build\web\* docs /E /Y

# Commit and push
git add .
git commit -m "Update app"
git push origin main

# Wait 1-2 minutes for GitHub Pages to update
```

## Measure Success

✅ App loads in 2-3 seconds
✅ Splash screen shows immediately
✅ Navigation works smoothly
✅ Firebase features work
✅ Images upload and display
✅ Profile data persists
✅ Connection requests work

---

**Your app is now live on GitHub Pages!** 🚀
