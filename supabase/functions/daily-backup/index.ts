// Supabase Edge Function for Automatic Daily Backups
// This function runs daily at 11:59 PM to create backups for users who have enabled auto-backup

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface BackupPreference {
  user_id: string;
  user_email: string;
  auto_backup_enabled: boolean;
}

interface BackupPayload {
  version: number;
  generatedAt: string;
  checksum: string;
  collections: Record<string, any[]>;
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Initialize Supabase client with service role for admin access
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    
    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false
      }
    })

    console.log('Starting daily backup process...')

    // Get all users who have auto-backup enabled
    const { data: users, error: usersError } = await supabase
      .from('user_backup_preferences')
      .select('user_id, user_email, auto_backup_enabled, last_backup_date')
      .eq('auto_backup_enabled', true)

    if (usersError) {
      console.error('Error fetching users:', usersError)
      throw usersError
    }

    if (!users || users.length === 0) {
      console.log('No users have auto-backup enabled')
      return new Response(
        JSON.stringify({ message: 'No users with auto-backup enabled', count: 0 }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
      )
    }

    console.log(`Found ${users.length} users with auto-backup enabled`)

    const results = []
    const errors = []

    // Process each user
    for (const user of users) {
      try {
        // Check if backup was already created today
        if (user.last_backup_date) {
          const lastBackup = new Date(user.last_backup_date)
          const today = new Date()
          
          if (lastBackup.toDateString() === today.toDateString()) {
            console.log(`Backup already created today for user ${user.user_id}`)
            results.push({
              user_id: user.user_id,
              status: 'skipped',
              reason: 'Backup already created today'
            })
            continue
          }
        }

        // Create backup for this user
        const backupResult = await createBackupForUser(supabase, user.user_id, user.user_email)
        
        // Update last backup date
        await supabase
          .from('user_backup_preferences')
          .update({ last_backup_date: new Date().toISOString() })
          .eq('user_id', user.user_id)

        results.push({
          user_id: user.user_id,
          status: 'success',
          backup_path: backupResult.path,
          items_count: backupResult.totalItems
        })

        console.log(`Successfully created backup for user ${user.user_id}`)
      } catch (error) {
        console.error(`Error creating backup for user ${user.user_id}:`, error)
        errors.push({
          user_id: user.user_id,
          error: error.message
        })
      }
    }

    const response = {
      success: true,
      timestamp: new Date().toISOString(),
      processed: users.length,
      successful: results.filter(r => r.status === 'success').length,
      skipped: results.filter(r => r.status === 'skipped').length,
      failed: errors.length,
      results,
      errors
    }

    console.log('Daily backup process completed:', response)

    return new Response(
      JSON.stringify(response),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )

  } catch (error) {
    console.error('Error in daily backup function:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 500 }
    )
  }
})

async function createBackupForUser(supabase: any, userId: string, userEmail: string) {
  const allTables = [
    'supplies',
    'brands',
    'suppliers',
    'categories',
    'purchase_orders',
    'notifications',
    'activity_logs',
    'user_roles',
    'po_suggestions',
    'stock_deduction_presets',
  ]

  const collections: Record<string, any[]> = {}
  let totalItems = 0

  // Fetch data from all tables
  for (const table of allTables) {
    try {
      const { data, error } = await supabase
        .from(table)
        .select('*')
        .order('id')
        .limit(500)

      if (error) {
        console.error(`Error fetching ${table}:`, error)
        collections[table] = []
        continue
      }

      const items = (data || []).map((item: any) => ({
        id: item.id?.toString() || '',
        data: item
      }))

      collections[table] = items
      totalItems += items.length
    } catch (error) {
      console.error(`Error processing table ${table}:`, error)
      collections[table] = []
    }
  }

  // Create payload
  const payload: BackupPayload = {
    version: 1,
    generatedAt: new Date().toISOString(),
    checksum: generateChecksum(JSON.stringify(collections)),
    collections
  }

  const jsonStr = JSON.stringify(payload)

  // Encrypt the backup
  const encryptedData = encryptData(jsonStr, userId, userEmail)

  // Generate filename
  const now = new Date()
  const iso = now.toISOString().replace(/:/g, '-')
  const filename = `inventory_backup_${iso}.json`
  const path = `familee-backups/${filename}`

  // Upload to storage
  const { error: uploadError } = await supabase.storage
    .from('backups')
    .upload(path, encryptedData, {
      contentType: 'application/json',
      upsert: true
    })

  if (uploadError) {
    throw new Error(`Upload failed: ${uploadError.message}`)
  }

  // Clean up old backups (keep only latest 10)
  await cleanupOldBackups(supabase)

  // Log activity
  await logBackupActivity(supabase, userId, filename)

  return {
    path,
    totalItems
  }
}

function generateChecksum(input: string): string {
  // Simple FNV-1a 32-bit hash
  const FNV_PRIME = 0x01000193
  let hash = 0x811c9dc5

  for (let i = 0; i < input.length; i++) {
    hash ^= input.charCodeAt(i)
    hash = Math.imul(hash, FNV_PRIME)
  }

  return (hash >>> 0).toString(16).padStart(8, '0')
}

function encryptData(data: string, userId: string, userEmail: string): string {
  // This is a placeholder - you'll need to implement the same encryption logic
  // as your Flutter app's EncryptionService
  // For now, we'll add the encryption prefix and base64 encode
  
  const appSecret = 'familee_2021'
  const keySource = `${userId}_${userEmail}_${appSecret}`
  
  // Note: You'll need to implement proper AES encryption here
  // This is a simplified version for demonstration
  const encodedData = btoa(data)
  return `ENCRYPTED:${encodedData}`
}

async function cleanupOldBackups(supabase: any) {
  try {
    const { data: files, error } = await supabase.storage
      .from('backups')
      .list('familee-backups', {
        limit: 100,
        sortBy: { column: 'created_at', order: 'desc' }
      })

    if (error || !files) return

    // Keep only the latest 10 backups
    const MAX_BACKUPS = 10
    if (files.length > MAX_BACKUPS) {
      const filesToDelete = files.slice(MAX_BACKUPS).map((f: any) => `familee-backups/${f.name}`)
      
      if (filesToDelete.length > 0) {
        await supabase.storage
          .from('backups')
          .remove(filesToDelete)
        
        console.log(`Cleaned up ${filesToDelete.length} old backups`)
      }
    }
  } catch (error) {
    console.error('Error cleaning up old backups:', error)
  }
}

async function logBackupActivity(supabase: any, userId: string, filename: string) {
  try {
    await supabase.from('activity_logs').insert({
      user_id: userId,
      action: 'backup_created',
      entity_type: 'backup',
      entity_id: filename,
      details: `Automatic daily backup: ${filename}`,
      created_at: new Date().toISOString()
    })
  } catch (error) {
    console.error('Error logging backup activity:', error)
  }
}

