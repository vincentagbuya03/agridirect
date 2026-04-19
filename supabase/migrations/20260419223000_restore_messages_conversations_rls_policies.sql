-- Restore required RLS policies for conversations/messages.
-- Fixes 42501 on inserting into conversations from authenticated customer flow.
-- Idempotent: safe to run multiple times.

ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'conversations'
      AND policyname = 'conversations_select_own'
  ) THEN
    CREATE POLICY conversations_select_own
    ON public.conversations
    FOR SELECT
    TO authenticated
    USING (
      customer_id IN (
        SELECT c.customer_id
        FROM public.customers c
        WHERE c.user_id = auth.uid()
      )
      OR farmer_id IN (
        SELECT f.farmer_id
        FROM public.farmers f
        WHERE f.user_id = auth.uid()
      )
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'conversations'
      AND policyname = 'conversations_insert_customer_own'
  ) THEN
    CREATE POLICY conversations_insert_customer_own
    ON public.conversations
    FOR INSERT
    TO authenticated
    WITH CHECK (
      customer_id IN (
        SELECT c.customer_id
        FROM public.customers c
        WHERE c.user_id = auth.uid()
      )
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'conversations'
      AND policyname = 'conversations_update_own'
  ) THEN
    CREATE POLICY conversations_update_own
    ON public.conversations
    FOR UPDATE
    TO authenticated
    USING (
      customer_id IN (
        SELECT c.customer_id
        FROM public.customers c
        WHERE c.user_id = auth.uid()
      )
      OR farmer_id IN (
        SELECT f.farmer_id
        FROM public.farmers f
        WHERE f.user_id = auth.uid()
      )
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'messages'
      AND policyname = 'messages_select_own_conversations'
  ) THEN
    CREATE POLICY messages_select_own_conversations
    ON public.messages
    FOR SELECT
    TO authenticated
    USING (
      conversation_id IN (
        SELECT conv.conversation_id
        FROM public.conversations conv
        WHERE conv.customer_id IN (
          SELECT c.customer_id
          FROM public.customers c
          WHERE c.user_id = auth.uid()
        )
        OR conv.farmer_id IN (
          SELECT f.farmer_id
          FROM public.farmers f
          WHERE f.user_id = auth.uid()
        )
      )
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'messages'
      AND policyname = 'messages_insert_own_conversation'
  ) THEN
    CREATE POLICY messages_insert_own_conversation
    ON public.messages
    FOR INSERT
    TO authenticated
    WITH CHECK (
      sender_id = auth.uid()
      AND conversation_id IN (
        SELECT conv.conversation_id
        FROM public.conversations conv
        WHERE conv.customer_id IN (
          SELECT c.customer_id
          FROM public.customers c
          WHERE c.user_id = auth.uid()
        )
        OR conv.farmer_id IN (
          SELECT f.farmer_id
          FROM public.farmers f
          WHERE f.user_id = auth.uid()
        )
      )
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'messages'
      AND policyname = 'messages_update_own_conversation'
  ) THEN
    CREATE POLICY messages_update_own_conversation
    ON public.messages
    FOR UPDATE
    TO authenticated
    USING (
      conversation_id IN (
        SELECT conv.conversation_id
        FROM public.conversations conv
        WHERE conv.customer_id IN (
          SELECT c.customer_id
          FROM public.customers c
          WHERE c.user_id = auth.uid()
        )
        OR conv.farmer_id IN (
          SELECT f.farmer_id
          FROM public.farmers f
          WHERE f.user_id = auth.uid()
        )
      )
    );
  END IF;
END $$;
