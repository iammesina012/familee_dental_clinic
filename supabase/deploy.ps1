# PowerShell deployment script for Supabase automatic backups
# Run this script from the project root: .\supabase\deploy.ps1

Write-Host "==================================" -ForegroundColor Cyan
Write-Host "Familee Dental - Backup Deployment" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""

# Check if Supabase CLI is installed
Write-Host "Checking for Supabase CLI..." -ForegroundColor Yellow
$supabaseVersion = supabase --version 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Supabase CLI not found!" -ForegroundColor Red
    Write-Host "Install it with: scoop install supabase" -ForegroundColor Yellow
    exit 1
}
Write-Host "✅ Supabase CLI found: $supabaseVersion" -ForegroundColor Green
Write-Host ""

# Check if project is linked
Write-Host "Checking project link status..." -ForegroundColor Yellow
supabase status 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Project not linked to Supabase!" -ForegroundColor Red
    Write-Host "Run: supabase link --project-ref YOUR_PROJECT_REF" -ForegroundColor Yellow
    exit 1
}
Write-Host "✅ Project is linked" -ForegroundColor Green
Write-Host ""

# Apply database migrations
Write-Host "Applying database migrations..." -ForegroundColor Yellow
supabase db push
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Migration failed!" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Migrations applied successfully" -ForegroundColor Green
Write-Host ""

# Deploy edge function
Write-Host "Deploying daily-backup edge function..." -ForegroundColor Yellow
supabase functions deploy daily-backup --no-verify-jwt
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Function deployment failed!" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Edge function deployed successfully" -ForegroundColor Green
Write-Host ""

# Test the function
Write-Host "Testing the edge function..." -ForegroundColor Yellow
Write-Host "(This will create a test backup if auto-backup is enabled for any user)" -ForegroundColor Gray
supabase functions invoke daily-backup --no-verify-jwt
if ($LASTEXITCODE -ne 0) {
    Write-Host "⚠️  Function test returned an error (this is normal if no users have auto-backup enabled)" -ForegroundColor Yellow
} else {
    Write-Host "✅ Function test completed" -ForegroundColor Green
}
Write-Host ""

# Show next steps
Write-Host "==================================" -ForegroundColor Cyan
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. Set up the cron job in Supabase dashboard (see QUICKSTART.md)" -ForegroundColor White
Write-Host "2. Enable automatic backup in the Flutter app" -ForegroundColor White
Write-Host "3. Check function logs: supabase functions logs daily-backup" -ForegroundColor White
Write-Host ""
Write-Host "For detailed instructions, see: supabase\README.md" -ForegroundColor Cyan

