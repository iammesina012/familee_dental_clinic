# Supabase Setup for Familee Dental - Automatic Backups

This directory contains the Supabase Edge Function and database migrations needed for automatic daily backups.

## Overview

The automatic backup system uses Supabase Edge Functions to create backups at 11:59 PM daily, even when the app is closed. This solves the issue where the previous implementation only worked if the app was open.

## Architecture

1. **Database Table**: `user_backup_preferences` - Stores which users have auto-backup enabled
2. **Edge Function**: `daily-backup` - Runs daily at 11:59 PM to create backups
3. **Flutter Service**: Updated to store preferences in Supabase instead of local storage

## Prerequisites

Before deploying, you need:

1. [Supabase CLI](https://supabase.com/docs/guides/cli) installed
2. A Supabase project (create one at [supabase.com](https://supabase.com))
3. Supabase project credentials:
   - Project URL
   - Anon/Public key
   - Service Role key (for admin operations)

## Installation

### 1. Install Supabase CLI

```bash
# On Windows (using Scoop)
scoop install supabase

# Or using npm
npm install -g supabase

# Verify installation
supabase --version
```

### 2. Link Your Supabase Project

```bash
# Navigate to your project directory
cd c:\projects

# Login to Supabase
supabase login

# Link to your project
supabase link --project-ref YOUR_PROJECT_REF
```

To find your project ref:
- Go to your Supabase dashboard
- Select your project
- Go to Settings > General
- Copy the "Reference ID"

### 3. Run Database Migrations

```bash
# Apply the user_backup_preferences table migration
supabase db push
```

This will create the `user_backup_preferences` table with Row Level Security policies.

### 4. Deploy the Edge Function

```bash
# Deploy the daily-backup function
supabase functions deploy daily-backup

# Verify deployment
supabase functions list
```

### 5. Set Up Environment Variables

The edge function needs access to your Supabase credentials. These are automatically available in the edge function environment:

- `SUPABASE_URL` - Your project URL
- `SUPABASE_SERVICE_ROLE_KEY` - Service role key (for admin access)

No additional configuration needed!

### 6. Configure the Cron Schedule

To run the function daily at 11:59 PM, set up a cron job in Supabase:

**Option A: Using Supabase Dashboard**
1. Go to your Supabase project
2. Navigate to Database > Extensions
3. Enable the `pg_cron` extension
4. Go to SQL Editor and run:

```sql
-- Schedule the daily backup to run at 11:59 PM UTC
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

Replace:
- `YOUR_SUPABASE_URL` with your actual Supabase project URL
- `YOUR_ANON_KEY` with your anon/public key

**Option B: Using External Cron Service**

You can also use an external service like:
- GitHub Actions
- Vercel Cron
- Cron-job.org
- EasyCron

To trigger the function via HTTP:
```bash
curl -X POST \
  'YOUR_SUPABASE_URL/functions/v1/daily-backup' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json'
```

### 7. Update Flutter App Configuration

Make sure your Flutter app has the Supabase credentials configured in `lib/main.dart`:

```dart
await Supabase.initialize(
  url: 'YOUR_SUPABASE_URL',
  anonKey: 'YOUR_ANON_KEY',
);
```

## Testing

### Test the Edge Function Manually

```bash
# Invoke the function manually to test
supabase functions invoke daily-backup --no-verify-jwt
```

### Test from Flutter App

1. Run your Flutter app
2. Navigate to Backup & Restore page
3. Enable "Automatic Daily Backup" toggle
4. Check the Supabase database to verify the preference was saved:

```sql
SELECT * FROM user_backup_preferences;
```

### Verify Cron Job

Wait for the scheduled time (11:59 PM) or manually trigger the function to verify backups are created automatically.

## Troubleshooting

### Function not running at scheduled time

1. Check if `pg_cron` extension is enabled:
```sql
SELECT * FROM pg_extension WHERE extname = 'pg_cron';
```

2. Check cron job status:
```sql
SELECT * FROM cron.job;
SELECT * FROM cron.job_run_details ORDER BY end_time DESC LIMIT 10;
```

### Permission errors

Make sure your Supabase service role key is correctly set in the edge function environment.

### Toggle keeps turning off

This was the original issue! Now that preferences are stored in Supabase instead of SharedPreferences, the toggle state will persist correctly across app sessions.

### Backups not being created

1. Check edge function logs:
```bash
supabase functions logs daily-backup
```

2. Verify the user has auto_backup_enabled set to true:
```sql
SELECT * FROM user_backup_preferences WHERE auto_backup_enabled = true;
```

## Security Notes

1. **Row Level Security**: The `user_backup_preferences` table has RLS policies that ensure users can only access their own preferences
2. **Service Role Access**: The edge function uses the service role key to bypass RLS when creating backups
3. **Encryption**: Backups are encrypted using the same encryption service as manual backups

## File Structure

```
supabase/
├── functions/
│   └── daily-backup/
│       ├── index.ts          # Edge function code
│       └── cron.json         # Cron schedule configuration
├── migrations/
│   └── 20250101000000_create_backup_preferences.sql
├── config.toml               # Supabase configuration
└── README.md                 # This file
```

## Monitoring

To monitor your automatic backups:

1. Check the activity logs in your Flutter app
2. View backup files in Supabase Storage:
   - Go to Storage > backups > familee-backups
3. Check edge function logs for any errors

## Cost Considerations

- Edge Functions have a free tier with 500K requests/month
- Cron jobs count as function invocations (1 per day = ~30/month)
- Storage costs depend on backup size and retention
- The system keeps only the latest 10 backups per user to manage costs

## Next Steps

After deployment:

1. ✅ Test the manual toggle in the Flutter app
2. ✅ Verify the preference is saved in Supabase
3. ✅ Test the edge function manually
4. ✅ Wait for the scheduled backup at 11:59 PM
5. ✅ Check that backups are created automatically
6. ✅ Monitor for the next few days to ensure reliability

## Support

If you encounter issues:
1. Check the Supabase dashboard for function logs
2. Verify database migrations were applied correctly
3. Test the function manually before relying on the cron schedule

