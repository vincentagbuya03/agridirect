-- Migration: Add publish_app_version RPC to allow release scripts to update version config
CREATE OR REPLACE FUNCTION public.publish_app_version(
    p_platform text,
    p_latest_version text,
    p_latest_build_number int,
    p_apk_url text,
    p_release_notes text[],
    p_is_critical boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_result record;
BEGIN
    UPDATE public.app_versions
    SET latest_version = p_latest_version,
        latest_build_number = p_latest_build_number,
        apk_url = p_apk_url,
        release_notes = p_release_notes,
        is_critical = p_is_critical,
        updated_at = now()
    WHERE platform = p_platform
    RETURNING * INTO v_result;

    IF NOT FOUND THEN
        INSERT INTO public.app_versions (
            platform, latest_version, latest_build_number,
            min_supported_version, min_supported_build_number,
            apk_url, release_notes, is_critical, updated_at
        ) VALUES (
            p_platform, p_latest_version, p_latest_build_number,
            '1.0.0', 1,
            p_apk_url, p_release_notes, p_is_critical, now()
        )
        RETURNING * INTO v_result;
    END IF;

    RETURN to_jsonb(v_result);
END;
$$;

-- Grant execution to anon, authenticated, and service_role callers
GRANT EXECUTE ON FUNCTION public.publish_app_version(text, text, int, text, text[], boolean) TO anon, authenticated, service_role;
