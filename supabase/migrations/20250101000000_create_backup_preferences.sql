-- Create table to track user backup preferences
CREATE TABLE IF NOT EXISTS user_backup_preferences (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  user_email TEXT NOT NULL,
  auto_backup_enabled BOOLEAN NOT NULL DEFAULT false,
  last_backup_date TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create index for efficient queries
CREATE INDEX IF NOT EXISTS idx_backup_preferences_user_id ON user_backup_preferences(user_id);
CREATE INDEX IF NOT EXISTS idx_backup_preferences_auto_enabled ON user_backup_preferences(auto_backup_enabled);

-- Enable Row Level Security
ALTER TABLE user_backup_preferences ENABLE ROW LEVEL SECURITY;

-- Create policy: Users can read their own preferences
CREATE POLICY "Users can view own backup preferences"
  ON user_backup_preferences
  FOR SELECT
  USING (auth.uid() = user_id);

-- Create policy: Users can insert their own preferences
CREATE POLICY "Users can insert own backup preferences"
  ON user_backup_preferences
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Create policy: Users can update their own preferences
CREATE POLICY "Users can update own backup preferences"
  ON user_backup_preferences
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Create policy: Service role can do everything (for edge function)
CREATE POLICY "Service role has full access"
  ON user_backup_preferences
  FOR ALL
  USING (auth.jwt()->>'role' = 'service_role');

-- Create trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_backup_preferences_updated_at
  BEFORE UPDATE ON user_backup_preferences
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Add comment
COMMENT ON TABLE user_backup_preferences IS 'Stores user preferences for automatic daily backups';

