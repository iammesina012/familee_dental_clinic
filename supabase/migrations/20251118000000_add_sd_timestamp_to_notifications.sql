-- Add sd_timestamp column to notifications table for stock deduction notifications
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS sd_timestamp TEXT;

-- Add index for faster queries on sd_timestamp
CREATE INDEX IF NOT EXISTS idx_notifications_sd_timestamp ON notifications(sd_timestamp);

