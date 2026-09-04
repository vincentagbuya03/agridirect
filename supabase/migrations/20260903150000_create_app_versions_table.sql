-- Create app_versions table for in-app remote update control
CREATE TABLE IF NOT EXISTS public.app_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    platform TEXT NOT NULL, -- 'android', 'ios', 'web'
    latest_version TEXT NOT NULL, -- e.g. '1.0.3'
    latest_build_number INT NOT NULL DEFAULT 1, -- e.g. 3
    min_supported_version TEXT NOT NULL DEFAULT '1.0.0', -- e.g. '1.0.0'
    min_supported_build_number INT NOT NULL DEFAULT 1, -- e.g. 1
    apk_url TEXT NOT NULL DEFAULT '',
    release_notes TEXT[] NOT NULL DEFAULT '{}',
    is_critical BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT app_versions_platform_unique UNIQUE (platform)
);

-- Enable RLS
ALTER TABLE public.app_versions ENABLE ROW LEVEL SECURITY;

-- Allow anyone (public/anon and authenticated users) to read app versions
CREATE POLICY "Allow public read access to app_versions"
    ON public.app_versions
    FOR SELECT
    USING (true);

-- Allow admins to insert/update/delete app versions
CREATE POLICY "Allow admin full access to app_versions"
    ON public.app_versions
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.admins
            WHERE admins.user_id = auth.uid()
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.admins
            WHERE admins.user_id = auth.uid()
        )
    );

-- Seed initial records for Android and Web
INSERT INTO public.app_versions (
    platform,
    latest_version,
    latest_build_number,
    min_supported_version,
    min_supported_build_number,
    apk_url,
    release_notes,
    is_critical
) VALUES 
(
    'android',
    '1.0.3',
    3,
    '1.0.0',
    1,
    'https://github.com/vincentagbuya03/agridirect/releases/download/v1.0.3/AgriDirect-Installer.apk',
    ARRAY[
        'Enhanced marketplace & shop discovery',
        'Performance & offline stability improvements',
        'Secure in-app update checks and notification alerts'
    ],
    false
),
(
    'web',
    '1.0.3',
    3,
    '1.0.0',
    1,
    '',
    ARRAY[
        'Web marketplace enhancements',
        'Improved UI responsiveness and navigation'
    ],
    false
)
ON CONFLICT (platform) DO UPDATE SET
    latest_version = EXCLUDED.latest_version,
    latest_build_number = EXCLUDED.latest_build_number,
    min_supported_version = EXCLUDED.min_supported_version,
    min_supported_build_number = EXCLUDED.min_supported_build_number,
    apk_url = EXCLUDED.apk_url,
    release_notes = EXCLUDED.release_notes,
    is_critical = EXCLUDED.is_critical,
    updated_at = now();
