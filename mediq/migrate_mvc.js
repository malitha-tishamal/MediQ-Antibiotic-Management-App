const fs = require('fs');
const path = require('path');

const libDir = path.resolve(__dirname, 'lib');

function ensureDir(dir) {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
}

// 1. Rename folders/files before moving
console.log('Step 1: Renaming directories with bugs/spaces/typos...');

// Rename stoks -> stocks
const oldStoks = path.join(libDir, 'admin', 'stoks');
const newStocks = path.join(libDir, 'admin', 'stocks');
if (fs.existsSync(oldStoks)) {
  fs.renameSync(oldStoks, newStocks);
  console.log('Renamed admin/stoks -> admin/stocks');
}

// Rename overall_usage overview -> overall_usage_overview
const oldUsageOverview = path.join(libDir, 'admin', 'analyst', 'overall_usage overview');
const newUsageOverview = path.join(libDir, 'admin', 'analyst', 'overall_usage_overview');
if (fs.existsSync(oldUsageOverview)) {
  fs.renameSync(oldUsageOverview, newUsageOverview);
  console.log('Renamed overall_usage overview -> overall_usage_overview');
}

// Rename overall_ward_wise_usage overview -> overall_ward_wise_usage_overview
const oldWardOverview = path.join(libDir, 'admin', 'analyst', 'overall_ward_wise_usage overview');
const newWardOverview = path.join(libDir, 'admin', 'analyst', 'overall_ward_wise_usage_overview');
if (fs.existsSync(oldWardOverview)) {
  fs.renameSync(oldWardOverview, newWardOverview);
  console.log('Renamed overall_ward_wise_usage overview -> overall_ward_wise_usage_overview');
}

// Rename accounts-manage-details.dart -> accounts_manage_details.dart
const oldAccountsDetails = path.join(libDir, 'admin', 'accounts-manage-details.dart');
const newAccountsDetails = path.join(libDir, 'admin', 'accounts_manage_details.dart');
if (fs.existsSync(oldAccountsDetails)) {
  fs.renameSync(oldAccountsDetails, newAccountsDetails);
  console.log('Renamed accounts-manage-details.dart -> accounts_manage_details.dart');
}

// 2. Create lib/views and move folders
console.log('Step 2: Moving screens into lib/views/...');
const viewsDir = path.join(libDir, 'views');
ensureDir(viewsDir);

// Move admin -> views/admin
const oldAdmin = path.join(libDir, 'admin');
const newAdmin = path.join(viewsDir, 'admin');
if (fs.existsSync(oldAdmin)) {
  fs.renameSync(oldAdmin, newAdmin);
  console.log('Moved lib/admin -> lib/views/admin');
}

// Move auth -> views/auth
const oldAuth = path.join(libDir, 'auth');
const newAuth = path.join(viewsDir, 'auth');
if (fs.existsSync(oldAuth)) {
  fs.renameSync(oldAuth, newAuth);
  console.log('Moved lib/auth -> lib/views/auth');
}

// Move pharmacist -> views/pharmacist
const oldPharmacist = path.join(libDir, 'pharmacist');
const newPharmacist = path.join(viewsDir, 'pharmacist');
if (fs.existsSync(oldPharmacist)) {
  fs.renameSync(oldPharmacist, newPharmacist);
  console.log('Moved lib/pharmacist -> lib/views/pharmacist');
}

// Move dashboard screens -> views/dashboard
const dashboardDir = path.join(viewsDir, 'dashboard');
ensureDir(dashboardDir);

const oldDashScreen = path.join(libDir, 'core', 'dashboard_screen.dart');
const newDashScreen = path.join(dashboardDir, 'dashboard_screen.dart');
if (fs.existsSync(oldDashScreen)) {
  fs.renameSync(oldDashScreen, newDashScreen);
  console.log('Moved dashboard_screen.dart -> views/dashboard/');
}

const oldDashWrapper = path.join(libDir, 'core', 'dashboard_wrapper.dart');
const newDashWrapper = path.join(dashboardDir, 'dashboard_wrapper.dart');
if (fs.existsSync(oldDashWrapper)) {
  fs.renameSync(oldDashWrapper, newDashWrapper);
  console.log('Moved dashboard_wrapper.dart -> views/dashboard/');
}

// Remove empty lib/common if empty
const commonDir = path.join(libDir, 'common');
if (fs.existsSync(commonDir) && fs.readdirSync(commonDir).length === 0) {
  fs.rmdirSync(commonDir);
}

console.log('Structure moved successfully.');
