# Deployment Guide: The Quadrant

This guide explains how to sync your code and deploy the live version of **The Quadrant**.

## 1. Repositories

| Repository | Purpose | Branch for App |
| :--- | :--- | :--- |
| **Quadrant-Networking-App** | Source Code & Project Site | `gh-pages` |
| **qomsycode.github.io** | Personal Branding Site | `main` |

---

## 2. Deployment Workflow

### Step A: Push Source Code
Updates the "Code" view on your main repository.
```bash
git add .
git commit -m "Your update message"
git push origin main
```

### Step B: Build & Deploy to Project Site
Updates `https://qomsycode.github.io/Quadrant-Networking-App/`.
```bash
# 1. Build for the project subdirectory
flutter build web --release --base-href "/Quadrant-Networking-App/"

# 2. Push artifacts to gh-pages branch
cd build/web
git init
git remote add origin https://github.com/qomsycode/Quadrant-Networking-App.git
git checkout -b gh-pages
git add .
git commit -m "Deploy to gh-pages"
git push -f origin gh-pages
cd ../..
```

### Step C: Build & Deploy to Personal Site
Updates `https://qomsycode.github.io/`.
```bash
# 1. Build for the root domain
flutter build web --release --base-href "/"

# 2. Push artifacts to personal repo
cd build/web
git init
git remote add origin https://github.com/qomsycode/qomsycode.github.io.git
git add .
git commit -m "Deploy to root domain"
git push -f origin main
cd ../..
```

---

## 3. Maintenance Checklist
- [ ] If you updated profile fields, remember to tap **"Save Changes"** in the app to sync old posts.
- [ ] Ensure `.nojekyll` exists in the `build/web` folder if GitHub Pages isn't loading CSS/JS.
