CREATE TABLE IF NOT EXISTS public.system_activity_logs (
  log_id uuid NOT NULL DEFAULT gen_random_uuid(),
  actor_user_id uuid NOT NULL,
  actor_role text NOT NULL DEFAULT 'User',
  action text NOT NULL,
  details text NOT NULL,
  entity_type text NOT NULL,
  entity_id uuid,
  severity text NOT NULL DEFAULT 'info',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT system_activity_logs_pkey PRIMARY KEY (log_id),
  CONSTRAINT system_activity_logs_actor_user_id_fkey
    FOREIGN KEY (actor_user_id) REFERENCES public.users(user_id) ON DELETE CASCADE,
  CONSTRAINT system_activity_logs_actor_role_check
    CHECK (actor_role IN ('Admin', 'Farmer', 'Customer', 'User', 'System')),
  CONSTRAINT system_activity_logs_severity_check
    CHECK (severity IN ('info', 'warning', 'critical'))
);

CREATE INDEX IF NOT EXISTS idx_system_activity_logs_created_at
  ON public.system_activity_logs (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_system_activity_logs_action
  ON public.system_activity_logs (action);

CREATE INDEX IF NOT EXISTS idx_system_activity_logs_actor_user_id
  ON public.system_activity_logs (actor_user_id);

CREATE INDEX IF NOT EXISTS idx_system_activity_logs_entity
  ON public.system_activity_logs (entity_type, entity_id);

ALTER TABLE public.system_activity_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS system_activity_logs_insert_own
  ON public.system_activity_logs;

CREATE POLICY system_activity_logs_insert_own
  ON public.system_activity_logs
  FOR INSERT
  TO authenticated
  WITH CHECK (actor_user_id = auth.uid());

DROP POLICY IF EXISTS system_activity_logs_select_admin
  ON public.system_activity_logs;

CREATE POLICY system_activity_logs_select_admin
  ON public.system_activity_logs
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.admins a
      WHERE a.user_id = auth.uid()
    )
  );
