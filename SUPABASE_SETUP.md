# Supabase Setup Guide

## Database Setup

### 1. Create the `profiles` table

Run this SQL in your Supabase SQL Editor:

```sql
-- Create profiles table
CREATE TABLE IF NOT EXISTS profiles (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT,
  phone TEXT,
  payment_method TEXT DEFAULT 'cash',
  avatar_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Enable RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Policy: Users can read their own profile
CREATE POLICY "Users can read their own profile"
  ON profiles
  FOR SELECT
  USING (auth.uid() = user_id);

-- Policy: Users can update their own profile
CREATE POLICY "Users can update their own profile"
  ON profiles
  FOR UPDATE
  USING (auth.uid() = user_id);

-- Policy: Users can insert their own profile
CREATE POLICY "Users can insert their own profile"
  ON profiles
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Create index for faster lookups
CREATE INDEX profiles_user_id_idx ON profiles(user_id);
```

### 2. Create the `avatars` storage bucket

1. Go to **Storage** in your Supabase dashboard
2. Create a new bucket named `avatars`
3. Make it **Public** (or restrict via RLS if needed)

### 3. Set Storage Policies (Optional but Recommended)

For more security, add RLS policies to the `avatars` bucket:

```sql
-- Allow users to upload their own avatars
-- (This is typically done through the Storage dashboard)
```

## Profile Fields

The `profiles` table contains:

| Field | Type | Description |
|-------|------|-------------|
| `id` | UUID | Primary key |
| `user_id` | UUID | Reference to auth user |
| `full_name` | TEXT | User's full name |
| `phone` | TEXT | User's phone number |
| `payment_method` | TEXT | 'cash' or 'card' |
| `avatar_url` | TEXT | URL to profile picture |
| `created_at` | TIMESTAMP | Creation timestamp |
| `updated_at` | TIMESTAMP | Last update timestamp |

## Image Upload Configuration

The app uploads profile pictures to the `avatars` bucket with the naming convention:
```
{user_id}_{timestamp}.jpg
```

Example: `550e8400-e29b-41d4-a716-446655440000_1699872000000.jpg`

## Local Development

If testing locally without full Supabase setup:
- Profile data is cached in `SharedPreferences`
- The app will gracefully degrade if Supabase is unavailable
- Image picker works without database

## Production Considerations

1. **Image Optimization**: Consider resizing images before upload (already done in app: 512x512 max, 80% quality)
2. **Storage Limits**: Monitor your Supabase storage usage
3. **Bucket CDN**: Enable CDN caching for faster avatar loads
4. **Backup**: Regularly backup your Supabase database
5. **Security**: Review and test RLS policies before going live
