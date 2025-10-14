# Quick Start Guide - Automatic Backups

Follow these steps to enable automatic daily backups for Familee Dental.

## Step 1: Install Supabase CLI

```powershell
# Using Scoop (recommended for Windows)
scoop install supabase

# OR using npm
npm install -g supabase
```

## Step 2: Login and Link Project

```powershell
# Login to Supabase
supabase login

# Link your project (get project ref from Supabase dashboard)
supabase link --project-ref YOUR_PROJECT_REF
```

## Step 3: Deploy Everything

```powershell
# Navigate to project root
cd c:\projects

# Apply database migrations
supabase db push

# Deploy the edge function
supabase functions deploy daily-backup
```

## Step 4: Set Up Daily Cron Job

Go to your Supabase project dashboard and run this SQL:

```sql
-- Enable pg_cron extension
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Schedule daily backup at 11:59 PM UTC
SELECT cron.schedule(
  'daily-backup-job',
  '59 23 * * *',
  $$
  SELECT
    net.http_post(
      url := 'YOUR_SUPABASE_URL/functions/v1/daily-backup',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer YOUR_ANON_KEY'
      ),
      body := '{}'::jsonb
    );
  $$
);
```

**Replace:**
- `YOUR_SUPABASE_URL` - Get from Settings > API > Project URL
- `YOUR_ANON_KEY` - Get from Settings > API > Project API keys > anon/public

## Step 5: Test It

```powershell
# Test the edge function manually
supabase functions invoke daily-backup --no-verify-jwt
```

## Step 6: Enable in Your App

1. Run your Flutter app
2. Go to Settings > Backup & Restore
3. Toggle "Automatic Daily Backup" ON
4. Done! Backups will now run daily at 11:59 PM

## Verify It's Working

### Check if preference is saved:
```sql
SELECT * FROM user_backup_preferences;
```

### Check function logs:
```powershell
supabase functions logs daily-backup
```

### View backups:
Go to Storage > backups > familee-backups in your Supabase dashboard

## Important Notes

✅ **The app no longer needs to be open** for backups to run
✅ **The toggle will stay on** across app sessions
✅ **Backups run at 11:59 PM UTC** every day
✅ **Only the latest 10 backups** are kept per user

## Timezone Note

The cron job runs at 11:59 PM UTC. If you want it to run at 11:59 PM in your local timezone:

**For Philippines (UTC+8):**
```sql
-- Run at 3:59 PM UTC (11:59 PM PHT)
'59 15 * * *'
```

**For PST (UTC-8):**
```sql
-- Run at 7:59 AM UTC (11:59 PM PST)
'59 7 * * *'
```

## Troubleshooting

**Toggle keeps turning off?**
- Old issue is now fixed! Preferences are stored in Supabase database.

**Backups not running?**
1. Check if cron job is scheduled: `SELECT * FROM cron.job;`
2. Check function logs: `supabase functions logs daily-backup`
3. Verify user has auto_backup_enabled = true

**Permission errors?**
- Make sure service role key is set in edge function environment
- Check RLS policies are applied correctly

## Need Help?

Check the full `README.md` for detailed documentation and troubleshooting.

